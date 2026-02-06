extends Node2D

# Array of player pieces
var pieces: Array[Node2D] = []

# Reference to the current player's piece
var current_piece: Node2D = null

var active_player_index: int = 0

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
	AudioManager.play_music("game_bg", +1.0, 0.8)

	# Get reference to the TileMapLayer first
	tile_map_layer = $TileMap/TileMapLayer
	highlight_layer = $TileMap/HighlightLayer

	# Listen for setup changes (important if GameState rebuilds players)
	if not GameState.setup_changed.is_connected(_on_setup_changed):
		GameState.setup_changed.connect(_on_setup_changed)

	# Spawn pieces using the configured players/colors
	# If players aren't built yet for some reason, we'll rebuild when setup_changed fires.
	if GameState.players.size() > 0:
		_spawn_pieces_from_gamestate()
	else:
		print("Board: GameState.players empty - waiting for setup_changed to spawn pieces")

	# Instantiate the space info panel
	space_info_panel = SpaceInfoPanelScene.instantiate()
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
		if space_info_panel and not current_piece.space_changed.is_connected(_on_piece_space_changed):
			current_piece.space_changed.connect(_on_piece_space_changed)
		if not current_piece.movement_finished.is_connected(_on_piece_movement_finished):
			current_piece.movement_finished.connect(_on_piece_movement_finished)

	# Connect to GameState turn signals
	if not GameState.turn_started.is_connected(_on_turn_started):
		GameState.turn_started.connect(_on_turn_started)
	if not GameState.turn_ended.is_connected(_on_turn_ended):
		GameState.turn_ended.connect(_on_turn_ended)

	# Start the game (deferred to ensure all UI components are ready)
	call_deferred("_start_game_deferred")

	# Update panel after everything is ready
	call_deferred("_initial_panel_update")


func _start_game_deferred() -> void:
	## Deferred game start to ensure all UI components are initialized
	GameState.start_game()


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
	auction_popup = AuctionPopupScene.instantiate()
	get_tree().root.call_deferred("add_child", auction_popup)

	property_details_popup = PropertyDetailsPopupScene.instantiate()
	get_tree().root.call_deferred("add_child", property_details_popup)

	call_deferred("_finish_setup_auction_popup")


func _finish_setup_auction_popup() -> void:
	if auction_popup and not auction_popup.is_node_ready():
		await auction_popup.ready
	if property_details_popup and not property_details_popup.is_node_ready():
		await property_details_popup.ready

	if auction_popup:
		auction_popup.visible = false
	if property_details_popup:
		property_details_popup.visible = false

	# AuctionPopup -> Board
	if auction_popup:
		if not auction_popup.details_requested.is_connected(_on_auction_details_requested):
			auction_popup.details_requested.connect(_on_auction_details_requested)
		if not auction_popup.pass_requested.is_connected(_on_auction_pass_requested):
			auction_popup.pass_requested.connect(_on_auction_pass_requested)
		if not auction_popup.bid_increment_requested.is_connected(_on_auction_bid_increment_requested):
			auction_popup.bid_increment_requested.connect(_on_auction_bid_increment_requested)

	# PropertyDetailsPopup -> Board
	if property_details_popup and not property_details_popup.close_pressed.is_connected(_on_property_details_closed):
		property_details_popup.close_pressed.connect(_on_property_details_closed)

	# AuctionMgr -> Board / UI feedback
	if not AuctionMgr.turn_changed.is_connected(_on_auction_turn_changed):
		AuctionMgr.turn_changed.connect(_on_auction_turn_changed)
	if not AuctionMgr.bid_updated.is_connected(_on_auction_bid_updated):
		AuctionMgr.bid_updated.connect(_on_auction_bid_updated)
	if not AuctionMgr.message.is_connected(_on_auction_message):
		AuctionMgr.message.connect(_on_auction_message)
	if not AuctionMgr.auction_ended.is_connected(_on_auction_ended):
		AuctionMgr.auction_ended.connect(_on_auction_ended)


func _initial_panel_update() -> void:
	if space_info_panel and current_piece:
		space_info_panel.update_space_display(current_piece.board_space)


func _on_turn_started(player_index: int) -> void:
	print("Board: Turn started for player ", player_index)

	# Validate player_index is within bounds
	if player_index < 0 or player_index >= pieces.size():
		push_error("Invalid player_index: %d (pieces size: %d)" % [player_index, pieces.size()])
		return

	if player_index >= GameState.players.size():
		push_error("Invalid player_index for GameState.players: %d" % player_index)
		return

	# Keep Board + GameState aligned to the actual turn owner
	active_player_index = player_index
	GameState.current_player_index = player_index

	# Switch to the new player's piece
	if current_piece:
		# disconnect signals only if they are connected safely
		if current_piece.space_changed.is_connected(_on_piece_space_changed):
			current_piece.space_changed.disconnect(_on_piece_space_changed)
		if current_piece.movement_finished.is_connected(_on_piece_movement_finished):
			current_piece.movement_finished.disconnect(_on_piece_movement_finished)

	current_piece = pieces[player_index]

	# Connect signals for new piece (avoid duplicate connections)
	if not current_piece.space_changed.is_connected(_on_piece_space_changed):
		current_piece.space_changed.connect(_on_piece_space_changed)
	if not current_piece.movement_finished.is_connected(_on_piece_movement_finished):
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


# Update piece layouts (offsets) for all pieces on a specific space
func update_piece_layouts_at(space_index: int) -> void:
	var pieces_at_space = []
	for p in pieces:
		if p.board_space == space_index:
			pieces_at_space.append(p)

	for i in range(pieces_at_space.size()):
		pieces_at_space[i].set_tile_layout(i, pieces_at_space.size())


func _on_piece_movement_finished(space_num: int) -> void:
	print("Piece finished moving at space: ", space_num)
	# Update layout at destination (centering if alone, offset if with others)
	update_piece_layouts_at(space_num)

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

	# Make sure auction popup is fully ready (prevents null @onready fields)
	if auction_popup and not auction_popup.is_node_ready():
		await auction_popup.ready

	# Show the auction popup
	if auction_popup:
		auction_popup.visible = true
		auction_popup.show_popup(space_num)

	# Build participant list (all players for now)
	var bidder_indexes: Array[int] = []
	for i in range(GameState.players.size()):
		bidder_indexes.append(i)

	# Starting price logic:
	# If the space has a "price", we treat that as the starting price players are bidding from.
	# (So +$50 means price + 50.)
	var space_info: Dictionary = SpaceDataRef.get_space_info(space_num)
	var starting_price: int = 0
	if not space_info.is_empty():
		starting_price = int(space_info.get("price", 0))

	# Start auction system:
	# - starting bid = starting_price
	# - starting player = whoever triggered the auction (current turn owner)
	AuctionMgr.start_auction(
		space_num,
		bidder_indexes,
		starting_price,
		10,
		GameState.current_player_index
	)


func _on_auction_bid_increment_requested(amount: int) -> void:
	AuctionMgr.submit_increment(amount)


func _on_auction_turn_changed(player_index: int) -> void:
	if player_index < 0 or player_index >= GameState.players.size():
		return

	var name := GameState.players[player_index].player_name
	print("Auction turn:", name)

	if auction_popup:
		# update the “current bidder” line with the REAL name
		if auction_popup.has_method("set_current_bidder"):
			auction_popup.call("set_current_bidder", name)

		# keep status consistent
		if auction_popup.has_method("set_status"):
			auction_popup.call("set_status", "Waiting for " + name + "…")


func _on_auction_bid_updated(high_bid: int, high_bidder_index: int) -> void:
	var bidder_name := "None"
	if high_bidder_index != -1 and high_bidder_index < GameState.players.size():
		bidder_name = GameState.players[high_bidder_index].player_name

	print("Auction high bid:", high_bid, " by ", bidder_name)

	if auction_popup:
		# update the “high bid” line
		if auction_popup.has_method("set_high_bid"):
			auction_popup.call("set_high_bid", high_bid, bidder_name)

		if auction_popup.has_method("set_status"):
			if high_bidder_index == -1:
				auction_popup.call("set_status", "Starting Price: $" + str(high_bid))
			else:
				auction_popup.call("set_status", "High bid: $" + str(high_bid) + " (" + bidder_name + ")")


func _on_auction_message(text: String) -> void:
	print("Auction:", text)
	if auction_popup and auction_popup.has_method("set_status"):
		auction_popup.call("set_status", text)


func _on_auction_ended(winner_index: int, winning_bid: int, _space_num: int, _property_ref) -> void:
	print("Auction ended. Winner:", winner_index, " bid:", winning_bid)

	if auction_popup:
		if winner_index == -1:
			auction_popup.set_status("Auction ended. No bids.")
		else:
			var winner_name := GameState.players[winner_index].player_name
			auction_popup.set_status(winner_name + " wins for $" + str(winning_bid) + "!")

		# Let players read it
		await get_tree().create_timer(2.5).timeout
		auction_popup.hide_popup()

	# tell the game flow we’re done with this action and move on.
	GameState.action_completed.emit()


func _on_move_pressed(space_num: int) -> void:
	# Handling for "Solar Storm" (Go to Jail/Launch Pad)
	if space_num == 30:
		print("Solar Storm! Transporting to Launch Pad...")
		# Teleport to space 10 (Launch Pad)
		if current_piece:
			var old_space = current_piece.board_space
			current_piece.teleport_to_space(10)
			# Update both spaces
			update_piece_layouts_at(old_space)
			update_piece_layouts_at(10)
	GameState.action_completed.emit()


func _on_draw_card_pressed(space_num: int) -> void:
	print("Player drawing card at space: ", space_num)
	# TODO: Implement card deck system
	var space_info = SpaceDataRef.get_space_info(space_num)
	print("Card type: ", space_info.name)
	GameState.action_completed.emit()


func _on_pay_pressed(space_num: int) -> void:
	print("Player paying for space:", space_num)

	var space_info = SpaceDataRef.get_space_info(space_num)
	var amount: int = int(space_info.get("amount", 0))

	if amount > 0:
		GameState.charge_player(GameState.current_player_index, amount)
		print("Paid $%d for %s" % [amount, space_info.name])

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

	# don't call hide_popup() because it resets current_space_num
	auction_popup.visible = false

	# Show the property details popup
	if property_details_popup and property_details_popup.has_method("show_space_details"):
		property_details_popup.call("show_space_details", space_num)
	else:
		push_warning("PropertyDetailsPopup missing show_space_details(space_num)")


func _on_auction_pass_requested() -> void:
	AuctionMgr.pass_turn()


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
		var old_space = current_piece.board_space
		current_piece.move_forward(total)
		# Update the space we just left so remaining pieces re-center
		update_piece_layouts_at(old_space)

		print("Dice rolled: %d + %d = %d%s" % [d1, d2, total, " (Doubles!)" if is_doubles else ""])

		# Mark player as having rolled
		var current_player = GameState.get_current_player()
		if current_player:
			current_player.has_rolled = true
			if is_doubles:
				current_player.doubles_count += 1
			# Notify that player has rolled
			GameState.player_rolled.emit(current_player)


func _clear_pieces() -> void:
	for p in pieces:
		if is_instance_valid(p):
			p.queue_free()
	pieces.clear()
	current_piece = null
	piece = null


func _spawn_pieces_from_gamestate() -> void:
	if not tile_map_layer:
		return

	_clear_pieces()

	var piece_scene = preload("res://scenes/Piece.tscn")

	for i in range(GameState.player_count):
		var piece_instance: Node2D = piece_scene.instantiate()
		piece_instance.tile_map = tile_map_layer
		piece_instance.player_index = i
		piece_instance.player_count = GameState.player_count

		add_child(piece_instance)
		pieces.append(piece_instance)

		# Position piece at GO
		piece_instance.move_to(10, 0)

		
		if i < GameState.players.size():
			var c: Color = GameState.players[i].player_color
			call_deferred("_apply_color_to_piece", piece_instance, c)

	# Layout at GO so pieces don't overlap
	update_piece_layouts_at(0)

	if pieces.size() > 0:
		current_piece = pieces[0]
		piece = current_piece


func _apply_color_to_piece(piece_instance: Node2D, c: Color) -> void:
	# 1) Best: Piece exposes an API
	if piece_instance.has_method("set_player_color"):
		piece_instance.call("set_player_color", c)
		return

	# 2) Try to color ANY Sprite2D under the piece (recursive)
	var painted := false
	for n in piece_instance.find_children("*", "Sprite2D", true, false):
		(n as Sprite2D).modulate = c
		painted = true

	# 3) If no Sprite2D found, tint any CanvasItem children (rare fallback)
	if not painted:
		for n in piece_instance.find_children("*", "CanvasItem", true, false):
			(n as CanvasItem).modulate = c
			painted = true

	# 4) Last resort: tint the root if possible
	if not painted and piece_instance is CanvasItem:
		(piece_instance as CanvasItem).modulate = c

	print("Applied color to piece", piece_instance.name, " painted=", painted, " color=", c)


func _on_setup_changed() -> void:
	print("Board: setup_changed -> rebuilding pieces")
	_spawn_pieces_from_gamestate()
