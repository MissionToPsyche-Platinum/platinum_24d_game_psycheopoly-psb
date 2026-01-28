extends Node2D

# Array of player pieces
var pieces: Array[Node2D] = []

# Reference to the current player's piece
var current_piece: Node2D = null

# Load core classes
const SpaceDataRef = preload("res://scripts/core/space_data.gd")

# Popups
const PropertyDetailsPopupScene = preload("res://scenes/PropertyDetailsPopup.tscn")
var property_details_popup: CanvasLayer = null

# Reference to the piece (backward compatibility if needed, but we use pieces/current_piece)
var piece: Node2D = null

# Tile map references
var tile_map_layer: TileMapLayer = null
var highlight_layer: TileMapLayer = null

# Space info panel reference and scene
const SpaceInfoPanelScene = preload("res://scenes/SpaceInfoPanel.tscn")
var space_info_panel: CanvasLayer = null

# Dice roll UI reference and scene
const DiceRollPanelScene = preload("res://scenes/DiceRollPanel.tscn")
var dice_roll_ui: Control = null

# Money HUD reference and scene
const MoneyHUDScene = preload("res://scenes/MoneyHUD.tscn")
var money_hud: Control = null

# Player name HUD reference and scene
const PlayerNameHUDScene = preload("res://scenes/PlayerNameHUD.tscn")
var player_name_hud: Control = null

# Space action popup reference and scene
const SpaceActionPopupScene = preload("res://scenes/SpaceActionPopup.tscn")
var space_action_popup: CanvasLayer = null

# End turn button reference and scene
const EndTurnButtonScene = preload("res://scenes/EndTurnButton.tscn")
var end_turn_button: Control = null

# Auction popup reference and scene
const AuctionPopupScene = preload("res://scenes/AuctionPopup.tscn")
var auction_popup: CanvasLayer = null

# Mouse interaction state
var hovered_tile: Vector2i = Vector2i(-1, -1)
var selected_tile: Vector2i = Vector2i(-1, -1)
var is_tile_selected: bool = false

# Highlight tile atlas coordinates
const HOVER_TILE := Vector2i(0, 2) # Hover texture
const SELECTED_TILE := Vector2i(5, 1) # Highlighted texture


func _ready() -> void:
	# Get reference to the TileMapLayer first
	tile_map_layer = $TileMap/TileMapLayer
	highlight_layer = $TileMap/HighlightLayer
	
	# Load and spawn pieces for all players
	var piece_scene = preload("res://scenes/Piece.tscn")
	for i in range(GameState.player_count):
		var piece_instance = piece_scene.instantiate()
		piece_instance.tile_map = tile_map_layer
		piece_instance.player_index = i  # Store player index for offset calculation
		piece_instance.player_count = GameState.player_count  # Store total player count for scaling
		add_child(piece_instance)
		pieces.append(piece_instance)
		# Position piece at GO
		piece_instance.move_to(10, 0)
	
	# Set current piece to first player (also set 'piece' for backward compatibility)
	current_piece = pieces[0]
	piece = current_piece
	
	# Instantiate the space info panel
	space_info_panel = SpaceInfoPanelScene.instantiate()
	# CanvasLayers must be added to the SceneTree directly
	get_tree().root.call_deferred("add_child", space_info_panel)

	# Instantiate the dice roll UI
	_setup_dice_roll_ui()

	# Instantiate the money HUD
	_setup_money_hud()
	
	# Instantiate the player name HUD
	_setup_player_name_hud()
	
	# Instantiate space action popup
	_setup_space_action_popup()
	
	# Instantiate end turn button
	_setup_end_turn_button()
	
	# Instantiate auction popup + details popup
	_setup_auction_popup()
	
	# Connect current piece's signals to update the UI
	if current_piece:
		if space_info_panel:
			current_piece.space_changed.connect(_on_piece_space_changed)
		current_piece.movement_finished.connect(_on_piece_movement_finished)
	
	# Connect to GameState turn signals
	GameState.turn_started.connect(_on_turn_started)
	GameState.turn_ended.connect(_on_turn_ended)
	
	# Start the game
	GameState.start_game()
	
	# Update panel after everything is ready
	call_deferred("_initial_panel_update")


func _setup_dice_roll_ui() -> void:
	# Create a CanvasLayer to hold the dice UI (ensures it's always on top)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "DiceRollLayer"
	canvas_layer.layer = 10 # Above other UI elements

	# Instantiate the dice roll panel
	dice_roll_ui = DiceRollPanelScene.instantiate()
	canvas_layer.add_child(dice_roll_ui)

	# Add to scene tree
	get_tree().root.call_deferred("add_child", canvas_layer)

	# Connect the dice_rolled signal to move the piece
	dice_roll_ui.dice_rolled.connect(_on_dice_rolled)


func _setup_money_hud() -> void:
	# Create a CanvasLayer to hold the money HUD (ensures it's always on top)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "MoneyHUDLayer"
	canvas_layer.layer = 9 # Just below dice UI layer

	# Instantiate the money HUD
	money_hud = MoneyHUDScene.instantiate()
	canvas_layer.add_child(money_hud)

	# Add to scene tree
	get_tree().root.call_deferred("add_child", canvas_layer)


func _setup_player_name_hud() -> void:
	# Create a CanvasLayer to hold the player name HUD
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "PlayerNameHUDLayer"
	canvas_layer.layer = 9  # Same level as money HUD
	
	# Instantiate the player name HUD
	player_name_hud = PlayerNameHUDScene.instantiate()
	canvas_layer.add_child(player_name_hud)
	
	# Add to scene tree
	get_tree().root.call_deferred("add_child", canvas_layer)


func _setup_space_action_popup() -> void:
	space_action_popup = SpaceActionPopupScene.instantiate()
	get_tree().root.call_deferred("add_child", space_action_popup)

	# Connect signals
	space_action_popup.purchase_pressed.connect(_on_purchase_pressed)
	space_action_popup.auction_pressed.connect(_on_auction_pressed)
	space_action_popup.pay_pressed.connect(_on_pay_pressed)
	space_action_popup.draw_card_pressed.connect(_on_draw_card_pressed)
	space_action_popup.move_pressed.connect(_on_move_pressed)
	space_action_popup.close_pressed.connect(_on_close_pressed)


func _setup_end_turn_button() -> void:
	# Create a CanvasLayer to hold the end turn button (always on top)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "EndTurnButtonLayer"
	canvas_layer.layer = 11  # Above dice roll layer
	
	# Instantiate the end turn button
	end_turn_button = EndTurnButtonScene.instantiate()
	canvas_layer.add_child(end_turn_button)
	
	# Add to scene tree
	get_tree().root.call_deferred("add_child", canvas_layer)


func _setup_auction_popup() -> void:
	# Auction popup
	auction_popup = AuctionPopupScene.instantiate()
	get_tree().root.call_deferred("add_child", auction_popup)

	# Start hidden safely (does NOT require @onready nodes)
	auction_popup.visible = false

	# Property details popup
	property_details_popup = PropertyDetailsPopupScene.instantiate()
	get_tree().root.call_deferred("add_child", property_details_popup)
	property_details_popup.visible = false

	# When Auction -> Details
	auction_popup.details_requested.connect(_on_auction_details_requested)
	
	# When Auction -> Pass
	auction_popup.pass_requested.connect(_on_auction_pass_requested)

	# When Details -> Close (go back to auction)
	property_details_popup.close_pressed.connect(_on_property_details_closed)


func _initial_panel_update() -> void:
	if space_info_panel and current_piece:
		space_info_panel.update_space_display(current_piece.board_space)


func _on_turn_started(player_index: int) -> void:
	print("Board: Turn started for player ", player_index)
	# Switch to the new player's piece
	if current_piece:
		current_piece.space_changed.disconnect(_on_piece_space_changed)
		current_piece.movement_finished.disconnect(_on_piece_movement_finished)
	
	current_piece = pieces[player_index]
	
	# Connect signals for new piece
	current_piece.space_changed.connect(_on_piece_space_changed)
	current_piece.movement_finished.connect(_on_piece_movement_finished)
	
	# Reset turn state
	GameState.players[player_index].has_rolled = false
	GameState.players[player_index].doubles_count = 0
	
	# Update info panel
	if space_info_panel:
		space_info_panel.update_space_display(current_piece.board_space)


func _on_turn_ended(player_index: int) -> void:
	print("Board: Turn ended for player ", player_index)


func end_turn() -> void:
	## Called when player wants to end their turn
	GameState.next_player()


func _on_piece_movement_finished(space_num: int) -> void:
	print("Piece finished moving at space: ", space_num)
	if space_action_popup:
		space_action_popup.show_actions(space_num)


func _on_purchase_pressed(space_num: int) -> void:
	print("Player wants to purchase space: ", space_num)
	# TODO: Implement actual purchase logic
	GameState.action_completed.emit()


func _on_auction_pressed(space_num: int) -> void:
	print("Auction started for space: ", space_num)

	# Hide the action popup so it doesn't sit on top
	if space_action_popup:
		space_action_popup.hide()

	# Show the auction popup
	if auction_popup:
		auction_popup.visible = true

		# If AuctionPopup script has a function to load the property info, call it:
		if auction_popup.has_method("show_popup"):
			auction_popup.call("show_popup", space_num)


func _on_move_pressed(space_num: int) -> void:
	# Handling for "Solar Storm" (Go to Jail/Launch Pad)
	if space_num == 30:
		print("Solar Storm! Transporting to Launch Pad...")
		# Teleport to space 10 (Launch Pad)
		if current_piece:
			current_piece.teleport_to_space(10)
	GameState.action_completed.emit()


func _on_draw_card_pressed(space_num: int) -> void:
	print("Player drawing card at space: ", space_num)
	# TODO: Implement card deck system
	var space_info = SpaceDataRef.get_space_info(space_num)
	print("Card type: ", space_info.name)
	GameState.action_completed.emit()


func _on_pay_pressed(space_num: int) -> void:
	print("Player paying for space: ", space_num)
	var space_info = SpaceDataRef.get_space_info(space_num)
	var amount = space_info.get("amount", 0)
	if amount > 0:
		var player_idx = 0 # Assume player 1 for now
		GameState.players[player_idx].balance -= amount
		print("Paid $%d for %s" % [amount, space_info.name])
		# Update HUD
		GameState.player_money_updated.emit(GameState.players[player_idx])
	GameState.action_completed.emit()


func _on_close_pressed() -> void:
	print("Player closed the action popup")
	GameState.action_completed.emit()


func _on_piece_space_changed(space_num: int) -> void:
	# Only update panel if no tile selected
	if not is_tile_selected and space_info_panel:
		space_info_panel.update_space_display(space_num)


func _on_auction_details_requested() -> void:
	if not auction_popup:
		return

	# We rely on AuctionPopup storing this when it opens
	var space_num: int = auction_popup.current_space_num
	print("Auction details requested for space:", space_num)

	#  don't call hide_popup() because it resets current_space_num
	auction_popup.visible = false

	# Show the property details popup
	if property_details_popup and property_details_popup.has_method("show_space_details"):
		property_details_popup.call("show_space_details", space_num)
	else:
		push_warning("PropertyDetailsPopup missing show_space_details(space_num)")

func _on_auction_pass_requested() -> void:
	# single-player / no turn system yet:
	# Just close the auction UI.
	if auction_popup:
		auction_popup.hide_popup()

	print("Auction: current player passed (v1: close UI).")

	# TODO LATER
	# Make sure that when user presses pass, the UI doesn't close, but waits for all bids to finish
	# Maybe have something like an AuctionManager script.



func _on_property_details_closed() -> void:
	# Hide details
	if property_details_popup:
		property_details_popup.visible = false

	# Show auction again (space_num is still stored in auction_popup.current_space_num)
	if auction_popup:
		auction_popup.visible = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event)


func _handle_mouse_motion(_event: InputEventMouseMotion) -> void:
	if not tile_map_layer:
		return

	# Get the tile coordinates under the mouse
	var mouse_pos = get_global_mouse_position()
	var tile_coords = tile_map_layer.local_to_map(mouse_pos)

	# Check if this tile is a valid board space
	if _is_valid_board_tile(tile_coords) and tile_coords != hovered_tile:
		# Clear previous hover highlight (only if it's not the selected tile)
		if hovered_tile != Vector2i(-1, -1) and hovered_tile != selected_tile:
			highlight_layer.erase_cell(hovered_tile)

		# Set new hovered tile
		hovered_tile = tile_coords

		# Show hover highlight (only if it's not the selected tile)
		if hovered_tile != selected_tile:
			highlight_layer.set_cell(hovered_tile, 1, HOVER_TILE)

	elif not _is_valid_board_tile(tile_coords) and hovered_tile != Vector2i(-1, -1):
		# Mouse left the board, clear hover highlight (only if it's not the selected tile)
		if hovered_tile != selected_tile:
			highlight_layer.erase_cell(hovered_tile)
		hovered_tile = Vector2i(-1, -1)


func _handle_mouse_click(event: InputEventMouseButton) -> void:
	if not tile_map_layer or not space_info_panel:
		return

	# Get the tile coordinates under the mouse
	var mouse_pos = get_global_mouse_position()
	var tile_coords = tile_map_layer.local_to_map(mouse_pos)

	# Check if this is a valid board tile
	if not _is_valid_board_tile(tile_coords):
		return

	# Debug quick teleport: Shift + Left Click
	if event.shift_pressed:
		var space_num := _get_space_from_tile_coords(tile_coords)
		if space_num >= 0 and current_piece:
			print("DEBUG: Quick teleporting piece to space ", space_num)
			current_piece.teleport_to_space(space_num)
			return

	# If clicking the same tile, deselect it
	if is_tile_selected and tile_coords == selected_tile:
		# Deselect
		is_tile_selected = false
		highlight_layer.erase_cell(selected_tile)
		selected_tile = Vector2i(-1, -1)

		# Restore hover highlight if mouse is still over a tile
		if hovered_tile != Vector2i(-1, -1):
			highlight_layer.set_cell(hovered_tile, 1, HOVER_TILE)

		# Show player's current position info
		if current_piece:
			space_info_panel.update_space_display(current_piece.board_space)
	else:
		# Clear previous selection
		if is_tile_selected and selected_tile != Vector2i(-1, -1):
			highlight_layer.erase_cell(selected_tile)

		# Select new tile
		selected_tile = tile_coords
		is_tile_selected = true

		# Show selected highlight
		highlight_layer.set_cell(selected_tile, 1, SELECTED_TILE)

		# Update space info panel with selected tile's info
		var space_num := _get_space_from_tile_coords(tile_coords)
		if space_num >= 0:
			space_info_panel.update_space_display(space_num)


func _is_valid_board_tile(coords: Vector2i) -> bool:
	# Check if coordinates are on the board perimeter (Monopoly-style)
	var x = coords.x
	var y = coords.y

	# Bottom edge
	if y == 10 and x >= 0 and x <= 10:
		return true
	# Right edge
	if x == 10 and y >= 0 and y <= 10:
		return true
	# Top edge
	if y == 0 and x >= 0 and x <= 10:
		return true
	# Left edge
	if x == 0 and y >= 0 and y <= 10:
		return true

	return false


func _get_space_from_tile_coords(coords: Vector2i) -> int:
	# Use the same logic as piece.gd's get_space_from_coords
	var x = coords.x
	var y = coords.y

	# Handle corners explicitly
	if x == 10 and y == 0:
		return 0 # Go (top-right corner)
	if x == 10 and y == 10:
		return 10 # Jail (bottom-right corner)
	if x == 0 and y == 10:
		return 20 # Free Parking (bottom-left corner)
	if x == 0 and y == 0:
		return 30 # Go to Jail (top-left corner)

	# Right edge: spaces 1-9 (x=10, y=1 to 9)
	if x == 10 and y > 0 and y < 10:
		return y

	# Bottom edge: spaces 11-19 (y=10, x=9 to 1)
	if y == 10 and x > 0 and x < 10:
		return 10 + (10 - x)

	# Left edge: spaces 21-29 (x=0, y=9 to 1)
	if x == 0 and y > 0 and y < 10:
		return 20 + (10 - y)

	# Top edge: spaces 31-39 (y=0, x=1 to 9)
	if y == 0 and x > 0 and x < 10:
		return 30 + x

	return -1


func _on_dice_rolled(d1: int, d2: int, total: int, is_doubles: bool) -> void:
	# Move the current player's piece forward by the total dice value
	if current_piece:
		current_piece.move_forward(total)
		print("Dice rolled: %d + %d = %d%s" % [d1, d2, total, " (Doubles!)" if is_doubles else ""])
		
		# Mark player as having rolled
		var current_player = GameState.get_current_player()
		if current_player:
			current_player.has_rolled = true
			if is_doubles:
				current_player.doubles_count += 1
			# Notify that player has rolled
			GameState.player_rolled.emit(current_player)
