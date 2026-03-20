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

@onready var board_tilemap: Node = $TileMap # reference to tilemap so we can implement the colorblind mode.

# Space info panel reference and scene
const SpaceInfoPanelScene = preload("res://scenes/SpaceInfoPanel.tscn")
var space_info_panel: CanvasLayer = null


# symbols for when colorblind mode is active:
var symbol_textures = {
	"Yellow": preload("res://assets/images/circle.png"),
	"Orange": preload("res://assets/images/star.png"),
	"Dark Orange": preload("res://assets/images/diamond.png"),
	"Pink": preload("res://assets/images/pentagon.png"),
	"Dark Red": preload("res://assets/images/triangle.png"),
	"Purple": preload("res://assets/images/square.png"),
	"Dark Purple": preload("res://assets/images/cross.png"),
	"Light Purple": preload("res://assets/images/hex.png")
}

const COLORBLIND_SYMBOL_SPACES := {
	1: "Light Purple",
	3: "Light Purple",

	6: "Dark Red",
	8: "Dark Red",
	9: "Dark Red",

	11: "Purple",
	13: "Purple",
	14: "Purple",

	16: "Orange",
	18: "Orange",
	19: "Orange",

	21: "Pink",
	23: "Pink",
	24: "Pink",

	26: "Dark Purple",
	28: "Dark Purple",
	29: "Dark Purple",

	31: "Yellow",
	33: "Yellow",
	34: "Yellow",

	37: "Dark Orange",
	39: "Dark Orange"
}

#having a hard time with symbol placements on certain spaces, trying this to see if it helps.
const COLORBLIND_SYMBOL_OFFSET_OVERRIDES := {}

# Dice roll UI reference and scene
const DiceRollPanelScene = preload("res://scenes/DiceRollPanel.tscn")
var dice_roll_ui: Control = null

# Money HUD reference and scene
const MoneyHUDScene = preload("res://scenes/MoneyHUD.tscn")
var money_hud: Control = null

# Player name HUD reference and scene
const PlayerNameHUDScene = preload("res://scenes/PlayerNameHUD.tscn")
var player_name_hud: Control = null

# Player properties preview reference and scene
const PlayerPropertiesPreviewScene = preload("res://scenes/PlayerPropertiesPreview.tscn")
var player_properties_preview: Control = null

# Space action popup reference and scene
const SpaceActionPopupScene = preload("res://scenes/SpaceActionPopup.tscn")
var space_action_popup: CanvasLayer = null

# End turn button reference and scene
const EndTurnButtonScene = preload("res://scenes/EndTurnButton.tscn")
var end_turn_button: Control = null

# Trade popup reference and scene
const TradePopupScene = preload("res://scenes/TradePopup.tscn")
var trade_popup: CanvasLayer = null

# Auction popup reference and scene
const AuctionPopupScene = preload("res://scenes/AuctionPopup.tscn")
var auction_popup: CanvasLayer = null

# Bankruptcy popup reference and scene
const BankruptcyPopupScene = preload("res://scenes/BankruptcyPopup.tscn")
var bankruptcy_popup: BankruptcyPopup = null

const JailPopupScene = preload("res://scenes/JailPopup.tscn")
var jail_popup: Control = null
var jail_popup_layer: CanvasLayer = null

const NotificationPopupScene = preload("res://scenes/NotificationPopup.tscn")
var notification_popup: Control = null
var notification_popup_layer: CanvasLayer = null

const SettingsMenuScene = preload("res://scenes/SettingsMenu.tscn")
var settings_menu: Control = null
var settings_menu_layer: CanvasLayer = null

const PauseMenuScene = preload("res://scenes/PauseMenu.tscn")
var pause_menu: Control = null
var pause_menu_layer: CanvasLayer = null

# Pending debt info while player is resolving bankruptcy
var pending_debtor_index: int = -1
var pending_creditor_index: int = -1
var pending_amount_owed: int = 0
var pending_reason: String = ""

# Mouse interaction state
var hovered_tile: Vector2i = Vector2i(-1, -1)
var selected_tile: Vector2i = Vector2i(-1, -1)
var is_tile_selected: bool = false

# Highlight tile atlas coordinates
const HOVER_TILE := Vector2i(0, 2) # Hover texture
const SELECTED_TILE := Vector2i(5, 1) # Highlighted texture

const PropertiesDetailPopupScene = preload("res://scenes/PropertiesDetailPopup.tscn")
var assets_popup: CanvasLayer = null



func _ready() -> void:
	AudioManager.play_music("game_bg", +1.0, 0.8)

	$Camera2D.make_current()
	# Get reference to the TileMapLayer first
	tile_map_layer = $TileMap/TileMapLayer
	highlight_layer = $TileMap/HighlightLayer
	
	call_deferred("_spawn_colorblind_symbols")

	# Listen for setup changes (important if GameState rebuilds players)
	if not GameController.setup_changed.is_connected(_on_setup_changed):
		GameController.setup_changed.connect(_on_setup_changed)
		
	if not GameController.action_completed.is_connected(_on_action_completed):
		GameController.action_completed.connect(_on_action_completed)

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

	# Instantiate the player properties preview
	_setup_player_properties_preview()

	# Instantiate space action popup
	_setup_space_action_popup()

	# Instantiate end turn button
	_setup_end_turn_button()
	
	#instantiae pause menu
	_setup_pause_menu()
	
	#instantite settings menu
	_setup_settings_menu()
	
	# Instantiate trade popup
	_setup_trade_popup()
	
	# Instantiate auction popup + details popup
	_setup_auction_popup()

	# Instantiate card movement signals
	_setup_card_movement()

	call_deferred("_setup_bankruptcy_popup_async")
	_setup_jail_popup()
	_setup_notification_popup()

	# Connect current piece's signals to update the UI
	if current_piece:
		if space_info_panel and not current_piece.space_changed.is_connected(_on_piece_space_changed):
			current_piece.space_changed.connect(_on_piece_space_changed)
		if not current_piece.movement_finished.is_connected(_on_piece_movement_finished):
			current_piece.movement_finished.connect(_on_piece_movement_finished)

	# Connect to GameController turn signals
	if not GameController.turn_started.is_connected(_on_turn_started):
		GameController.turn_started.connect(_on_turn_started)
	if not GameController.turn_ended.is_connected(_on_turn_ended):
		GameController.turn_ended.connect(_on_turn_ended)
	if not GameController.bankruptcy_needed.is_connected(_on_bankruptcy_needed):
		GameController.bankruptcy_needed.connect(_on_bankruptcy_needed)

	# Start the game (deferred to ensure all UI components are ready)
	call_deferred("_start_game_deferred")

	# Update panel after everything is ready
	call_deferred("_initial_panel_update")
	
	SettingsManager.colorblind_mode_changed.connect(_on_colorblind_mode_changed)
	_on_colorblind_mode_changed(SettingsManager.is_colorblind_enabled())


func _start_game_deferred() -> void:
	## Deferred game start to ensure all UI components are initialized
	GameController.start_game()


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

	dice_roll_ui.doubles_rolled.connect(_on_doubles_rolled)

func _setup_jail_popup() -> void:
	jail_popup_layer = CanvasLayer.new()
	jail_popup_layer.name = "JailPopupLayer"
	jail_popup_layer.layer = 50 # High priority

	jail_popup = JailPopupScene.instantiate()
	jail_popup_layer.add_child(jail_popup)
	get_tree().root.call_deferred("add_child", jail_popup_layer)

func _setup_notification_popup() -> void:
	notification_popup_layer = CanvasLayer.new()
	notification_popup_layer.name = "NotificationPopupLayer"
	notification_popup_layer.layer = 110 # Above all other popups

	notification_popup = NotificationPopupScene.instantiate()
	notification_popup_layer.add_child(notification_popup)
	get_tree().root.call_deferred("add_child", notification_popup_layer)

func _setup_money_hud() -> void:	# Create a CanvasLayer to hold the money HUD (ensures it's always on top)
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


func _setup_player_properties_preview() -> void:
	# Create a CanvasLayer to hold the player properties preview
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "PlayerPropertiesPreviewLayer"
	canvas_layer.layer = 9

	# Instantiate the player properties preview
	player_properties_preview = PlayerPropertiesPreviewScene.instantiate()
	canvas_layer.add_child(player_properties_preview)

	if player_properties_preview.has_signal("trade_pressed"):
		player_properties_preview.trade_pressed.connect(_on_trade_pressed)

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


func _setup_trade_popup() -> void:
	trade_popup = TradePopupScene.instantiate()
	get_tree().root.call_deferred("add_child", trade_popup)


func _setup_auction_popup() -> void:
	auction_popup = AuctionPopupScene.instantiate()
	get_tree().root.call_deferred("add_child", auction_popup)

	property_details_popup = PropertyDetailsPopupScene.instantiate()
	get_tree().root.call_deferred("add_child", property_details_popup)

	call_deferred("_finish_setup_auction_popup")


func _setup_card_movement() -> void:
	# ChanceCardManager -> Board / UI feedback
	if not ChanceCardMgr.request_move_forward.is_connected(_card_forward_movement):
		ChanceCardMgr.request_move_forward.connect(_card_forward_movement)
	if not ChanceCardMgr.request_teleport_movement.is_connected(_card_teleport_movement):
		ChanceCardMgr.request_teleport_movement.connect(_card_teleport_movement)


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


func _setup_bankruptcy_popup() -> void:
	var existing := get_tree().root.find_child("BankruptcyPopup", true, false) as BankruptcyPopup

	if existing:
		bankruptcy_popup = existing
	else:
		bankruptcy_popup = BankruptcyPopupScene.instantiate()
		bankruptcy_popup.name = "BankruptcyPopup"
		get_tree().root.add_child(bankruptcy_popup)

	if not bankruptcy_popup.open_assets_requested.is_connected(_on_bankruptcy_open_assets_requested):
		bankruptcy_popup.open_assets_requested.connect(_on_bankruptcy_open_assets_requested)

	if not bankruptcy_popup.attempt_pay_requested.is_connected(_on_bankruptcy_attempt_pay_requested):
		bankruptcy_popup.attempt_pay_requested.connect(_on_bankruptcy_attempt_pay_requested)

	if not bankruptcy_popup.bankruptcy_declared.is_connected(_on_bankruptcy_declared):
		bankruptcy_popup.bankruptcy_declared.connect(_on_bankruptcy_declared)

	# Now wait for node readiness before UI calls
	if bankruptcy_popup and not bankruptcy_popup.is_node_ready():
		await bankruptcy_popup.ready

	push_warning("BOARD: connected to BankruptcyPopup id=" + str(bankruptcy_popup.get_instance_id()) +
		" path=" + str(bankruptcy_popup.get_path()))

	bankruptcy_popup.hide_popup()


func _initial_panel_update() -> void:
	if space_info_panel and current_piece:
		space_info_panel.update_space_display(current_piece.board_space)


func _on_turn_started(player_index: int) -> void:
	print("Board: Turn started for player ", player_index)

	if not GameState.player_active.is_empty():
		if player_index >= 0 and player_index < GameState.player_active.size():
			if GameState.player_active[player_index] == false:
				print("Board: player ", player_index, " is inactive. Skipping turn.")
				call_deferred("_skip_inactive_turn")
				return

	if player_index < 0 or player_index >= pieces.size():
		push_warning("Invalid player_index: %d (pieces size: %d)" % [player_index, pieces.size()])
		call_deferred("_skip_inactive_turn")
		return

	if player_index >= GameState.players.size():
		push_warning("Invalid player_index for GameState.players: %d" % player_index)
		call_deferred("_skip_inactive_turn")
		return

	var next_piece := pieces[player_index]
	if next_piece == null or not is_instance_valid(next_piece):
		push_warning("Board: No valid piece for player %d. Skipping turn." % player_index)
		call_deferred("_skip_inactive_turn")
		return

	active_player_index = player_index
	GameState.current_player_index = player_index

	if current_piece != null and is_instance_valid(current_piece):
		if current_piece.space_changed.is_connected(_on_piece_space_changed):
			current_piece.space_changed.disconnect(_on_piece_space_changed)
		if current_piece.movement_finished.is_connected(_on_piece_movement_finished):
			current_piece.movement_finished.disconnect(_on_piece_movement_finished)

	current_piece = next_piece

	if not current_piece.space_changed.is_connected(_on_piece_space_changed):
		current_piece.space_changed.connect(_on_piece_space_changed)
	if not current_piece.movement_finished.is_connected(_on_piece_movement_finished):
		current_piece.movement_finished.connect(_on_piece_movement_finished)

	GameState.players[player_index].has_rolled = false
	GameState.players[player_index].doubles_count = 0

	if space_info_panel:
		space_info_panel.update_space_display(current_piece.board_space)
		
	var current_player := GameController.get_current_player()
	if current_player and current_player.is_in_jail:
		current_player.has_rolled = true # Disable regular rolling temporarily
		if jail_popup and jail_popup.has_method("show_for_player"):
			jail_popup.show_for_player(player_index)


func _on_turn_ended(player_index: int) -> void:
	print("Board: Turn ended for player ", player_index)


func end_turn() -> void:
	## Called when player wants to end their turn
	GameController.end_turn()


# Update piece layouts (offsets) for all pieces on a specific space
func update_piece_layouts_at(space_index: int) -> void:
	var pieces_at_space: Array[Node2D] = []

	# Collect valid pieces on this space
	for p in pieces:
		if p == null:
			continue
		if not is_instance_valid(p):
			continue
		if p.board_space == space_index:
			pieces_at_space.append(p)

	# Apply layout offsets to valid pieces
	for i in range(pieces_at_space.size()):
		var piece_node := pieces_at_space[i]
		if piece_node == null or not is_instance_valid(piece_node):
			continue
		piece_node.set_tile_layout(i, pieces_at_space.size())


func _on_piece_movement_finished(space_num: int) -> void:
	print("Piece finished moving at space: ", space_num)
	update_piece_layouts_at(space_num)

	if space_action_popup:
		if not space_action_popup.is_node_ready():
			await space_action_popup.ready

		space_action_popup.show_actions(space_num)

		await get_tree().process_frame
		if not space_action_popup.visible:
			GameController.action_completed.emit()


func _on_purchase_pressed(space_num: int) -> void:
	print("Player wants to purchase space: ", space_num)
	# TODO: Implement actual purchase logic
	GameController.action_completed.emit()


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

	# Start auction system:
	# - starting bid = $0
	# - starting player = whoever triggered the auction (current turn owner)
	AuctionMgr.start_auction(
		space_num,
		bidder_indexes,
		0,
		1,
		GameState.current_player_index
	)


func _on_auction_bid_increment_requested(amount: int) -> void:
	AuctionMgr.submit_increment(amount)


func _on_auction_turn_changed(player_index: int) -> void:
	if player_index < 0 or player_index >= GameState.players.size():
		return

	var player_name := GameState.get_player_display_name(player_index)
	print("Auction turn:", player_name)

	if auction_popup:
		# update the “current bidder” line with the REAL name
		if auction_popup.has_method("set_current_bidder"):
			auction_popup.call("set_current_bidder", player_name)

		# keep status consistent
		if auction_popup.has_method("set_status"):
			auction_popup.call("set_status", "Waiting for " + player_name + "…")


func _on_auction_bid_updated(high_bid: int, high_bidder_index: int) -> void:
	var bidder_name := "None"
	if high_bidder_index != -1 and high_bidder_index < GameState.players.size():
		bidder_name = GameState.get_player_display_name(high_bidder_index)

	print("Auction high bid:", high_bid, " by ", bidder_name)

	if auction_popup:
		# update the “high bid” line
		if auction_popup.has_method("set_high_bid"):
			auction_popup.call("set_high_bid", high_bid, bidder_name)

		if auction_popup.has_method("set_status"):
			if high_bidder_index == -1:
				auction_popup.call("set_status", "Starting Bid: $" + str(high_bid))
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
	GameController.action_completed.emit()


func _on_move_pressed(space_num: int) -> void:
	# Handling for "Solar Storm" (Go to Jail/Launch Pad)
	if space_num == 30:
		print("Solar Storm! Transporting to Launch Pad...")
		# Teleport to space 10 (Launch Pad)
		if current_piece:
			var old_space: int = int(current_piece.board_space)
			current_piece.teleport_to_space(10)
			# Update both spaces
			update_piece_layouts_at(old_space)
			update_piece_layouts_at(10)
		GameController.send_player_to_jail(GameState.current_player_index)
		if notification_popup:
			notification_popup.show_notification("Solar Storm!", "You have been sent to the Launch Pad.")
			await notification_popup.dismissed
	GameController.action_completed.emit()


func _on_draw_card_pressed(space_num: int) -> void:
	print("Player drawing card at space: ", space_num)
	# TODO: Implement card deck system
	var space_info = SpaceDataRef.get_space_info(space_num)
	print("Card type: ", space_info.name)
	GameController.action_completed.emit()


func _on_pay_pressed(space_num: int) -> void:
	print("Player pressed PAY on space:", space_num)

	var current_player := GameState.current_player_index
	if current_player < 0 or current_player >= GameState.players.size():
		push_warning("PAY: invalid current player index")
		GameController.action_completed.emit()
		return

	var space := GameState.board[space_num]

	if space is Ownable:
		var property := space as Ownable
		print("PAY DEBUG: script=", property.get_script(), " global_name=", property.get_script().get_global_name())
		GameController.pay_rent.emit(property, current_player)
		GameController.action_completed.emit()
		return

	var space_info = SpaceDataRef.get_space_info(space_num)
	var t := str(space_info.get("type", ""))

	# handling both expense and cost variation of sapces.
	if t == "cost" or t == "expense":
		var amount := int(space_info.get("amount", 0))
		if amount > 0:
			GameController.debit(current_player, amount, "space cost")
		else:
			push_warning("PAY: cost/expense space but amount missing/0 at space " + str(space_num))

	GameController.action_completed.emit()


func _on_close_pressed() -> void:
	print("Player closed the action popup")
	GameController.action_completed.emit()


func _on_trade_pressed() -> void:
	if trade_popup == null:
		return
	if GameState.current_player_index < 0 or GameState.current_player_index >= GameState.players.size():
		return
	trade_popup.show_for_current_player(GameState.current_player_index)


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
	if get_tree().paused:
		return

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
	# Ignore dice input if current turn player is inactive (bankrupt)
	if not GameState.player_active.is_empty():
		if GameState.current_player_index >= 0 and GameState.current_player_index < GameState.player_active.size():
			if GameState.player_active[GameState.current_player_index] == false:
				print("Dice roll ignored: inactive player turn.")
				return

	# Safety: current piece must exist
	if current_piece == null or not is_instance_valid(current_piece):
		push_warning("Dice roll ignored: current_piece is null or invalid.")
		return

	# Store last roll (useful for rent/cost math)
	GameState.last_roll = total

	print("Dice rolled: %d + %d = %d%s" % [
		d1,
		d2,
		total,
		" (Doubles!)" if is_doubles else ""
	])

	var current_player := GameController.get_current_player()
	
	if current_player:
		if current_player.is_in_jail:
			_handle_jail_roll(current_player, total, is_doubles)
			return
			
		current_player.has_rolled = true
		current_player.last_roll_was_doubles = is_doubles
		
		if is_doubles:
			current_player.doubles_count += 1
			if current_player.doubles_count == 3:
				print("Rolled 3 doubles! Go to jail.")
				GameController.send_player_to_jail(GameState.current_player_index)
				_card_teleport_movement(10) # Jail space
				GameController.emit_signal("player_rolled", current_player)
				if notification_popup:
					notification_popup.show_notification("3 Doubles!", "You rolled doubles 3 times!\nYou have been sent to the Launch Pad.")
					await notification_popup.dismissed
				GameController.action_completed.emit()
				# Do NOT move the piece normally, return early
				return
		else:
			current_player.doubles_count = 0

	# Move the piece
	var old_space: int = int(current_piece.board_space)
	current_piece.move_forward(total)

	# Re-layout pieces on the space we left so stacks look correct
	update_piece_layouts_at(old_space)

	if current_player:
		GameController.emit_signal("player_rolled", current_player)

func _handle_jail_roll(player: PlayerState, total: int, is_doubles: bool) -> void:
	player.turns_in_jail += 1
	player.has_rolled = true
	# Doubles out of jail do not grant an extra turn, so we reset flags
	player.last_roll_was_doubles = false
	player.doubles_count = 0
	
	if is_doubles:
		print("Rolled doubles! Escaped jail.")
		GameController.release_player_from_jail(GameState.current_player_index)
		# Move the rolled amount
		var old_space: int = int(current_piece.board_space)
		current_piece.move_forward(total)
		update_piece_layouts_at(old_space)
	else:
		if player.turns_in_jail == 3:
			print("3rd turn in jail without doubles. Forced to pay $50 bail.")
			# Try to pay 50. If they can't, they go bankrupt, but we'll try our best.
			# Using debit which handles emitting signals but doesn't auto-bankrupt yet in standard flow unless handled by action.
			# But actually if they can't pay, they should go bankrupt.
			if GameController.get_player_balance(GameState.current_player_index) < 50:
				GameController.emit_signal("bankruptcy_needed", GameState.current_player_index, -1, 50, "Launch Permit")
				# They still get released and move assuming they resolve bankruptcy, but let's release them anyway
			else:
				GameController.debit(GameState.current_player_index, 50, "Launch Permit")
			
			GameController.release_player_from_jail(GameState.current_player_index)
			var old_space: int = int(current_piece.board_space)
			current_piece.move_forward(total)
			update_piece_layouts_at(old_space)
		else:
			print("Did not roll doubles. Stay in jail.")
			# Don't move, turn effectively over. Need to simulate action completed so End Turn button enables.
			GameController.action_completed.emit()

	GameController.emit_signal("player_rolled", player)


func _card_forward_movement(move_spaces: int) -> void:
	# Move the current player's piece forward to the correct space
	if current_piece:
		var old_space: int = int(current_piece.board_space)
		current_piece.move_forward(move_spaces)
		# Update the space we just left so remaining pieces re-center
		update_piece_layouts_at(old_space)


func _card_teleport_movement(space_location: int) -> void:
	if current_piece:
		var old_space: int = int(current_piece.board_space)
		current_piece.teleport_to_space(space_location)
		# Update both spaces
		update_piece_layouts_at(old_space)
		update_piece_layouts_at(space_location)


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

	if not painted:
		for n in piece_instance.find_children("*", "CanvasItem", true, false):
			(n as CanvasItem).modulate = c
			painted = true

	if not painted and piece_instance is CanvasItem:
		(piece_instance as CanvasItem).modulate = c

	print("Applied color to piece", piece_instance.name, " painted=", painted, " color=", c)


func _on_setup_changed() -> void:
	print("Board: setup_changed -> rebuilding pieces")
	_spawn_pieces_from_gamestate()
	# If setup happens after board load, start the game once players exist
	if not GameState.game_active and GameState.players.size() > 0:
		call_deferred("_start_game_deferred")


## Bankruptcy Functions

func _on_bankruptcy_needed(debtor: int, creditor: int, amount: int, reason: String) -> void:
	print("Board: Bankruptcy needed for player", debtor, "amount", amount)
	enter_bankruptcy(debtor, creditor, amount, reason)


func _on_bankruptcy_open_assets_requested(debtor_id: int) -> void:
	print("Bankruptcy: Open assets for debtor:", debtor_id)

	if debtor_id < 0 or debtor_id >= GameState.players.size():
		push_warning("Bankruptcy: invalid debtor id " + str(debtor_id))
		return

	_show_assets_popup_for_player(GameState.players[debtor_id])


func _on_bankruptcy_attempt_pay_requested() -> void:
	print("Board: Attempting to pay debt")

	if pending_debtor_index == -1 or pending_amount_owed <= 0:
		push_warning("Board: attempt pay pressed but no pending bankruptcy debt")
		return

	var debtor := pending_debtor_index
	var creditor := pending_creditor_index
	var amount := pending_amount_owed

	var current_cash := GameController.get_player_balance(debtor)

	if current_cash >= amount:
		print("Board: Player can afford payment now. Paying $%d" % amount)

		if creditor >= 0 and creditor < GameState.players.size():
			GameController.transfer(debtor, creditor, amount, "bankruptcy payment")
		else:
			GameController.debit(debtor, amount, "bankruptcy payment to bank")

		# Close UI and clear state
		if bankruptcy_popup:
			bankruptcy_popup.hide_popup()

		_clear_pending_bankruptcy()
		GameController.action_completed.emit()
	else:
		print("Board: Still not enough. cash=%d owed=%d" % [current_cash, amount])
		if bankruptcy_popup:
			bankruptcy_popup.update_cash(current_cash)


func _on_bankruptcy_declared() -> void:
	print("BOARD: bankruptcy declared for player ", pending_debtor_index)

	var eliminated_player := pending_debtor_index

	# Mark player as inactive in GameState
	if eliminated_player >= 0 and eliminated_player < GameState.player_active.size():
		GameState.player_active[eliminated_player] = false

	# Visually remove their piece from board
	if eliminated_player >= 0 and eliminated_player < pieces.size():
		if is_instance_valid(pieces[eliminated_player]):
			pieces[eliminated_player].queue_free()
		pieces[eliminated_player] = null

	# Hide bankruptcy UI
	if bankruptcy_popup:
		bankruptcy_popup.hide_popup()

	_clear_pending_bankruptcy()

	# -------------------------
	# Check win condition
	# -------------------------
	var active_count := 0
	var last_active := -1
	for i in range(GameState.player_active.size()):
		if GameState.player_active[i]:
			active_count += 1
			last_active = i

	if active_count == 1:
		_show_win_screen(last_active)
		return

	# -------------------------
	# advance turn immediately so we never land on a bankrupt player
	# -------------------------
	call_deferred("_advance_after_bankruptcy")


func enter_bankruptcy(debtor_idx: int, creditor_idx: int, amount: int, reason: String) -> void:
	pending_debtor_index = debtor_idx
	pending_creditor_index = creditor_idx
	pending_amount_owed = amount
	pending_reason = reason

	var creditor_name := "Bank"
	if creditor_idx >= 0 and creditor_idx < GameState.players.size():
		creditor_name = GameState.players[creditor_idx].player_name

	bankruptcy_popup.show_popup(
		debtor_idx,
		creditor_name,
		reason,
		amount,
		GameController.get_player_balance(debtor_idx)
	)


func _clear_pending_bankruptcy() -> void:
	pending_debtor_index = -1
	pending_creditor_index = -1
	pending_amount_owed = 0
	pending_reason = ""


func _show_assets_popup_for_player(player: PlayerState) -> void:
	if not assets_popup:
		assets_popup = PropertiesDetailPopupScene.instantiate() as CanvasLayer
		assets_popup.name = "AssetsPopup"
		assets_popup.layer = 200
		get_tree().root.add_child(assets_popup)

	# Ensure ready
	if assets_popup and not assets_popup.is_node_ready():
		await assets_popup.ready

	# Connect the per-asset trade/sell signal
	if assets_popup.has_signal("trade_sell_requested"):
		if not assets_popup.trade_sell_requested.is_connected(_on_bankruptcy_asset_trade_sell_requested):
			assets_popup.trade_sell_requested.connect(_on_bankruptcy_asset_trade_sell_requested)

	assets_popup.visible = true

	# Bankruptcy state active so the row buttons appear
	if assets_popup.has_method("show_properties"):
		assets_popup.call("show_properties", player, true)

	if assets_popup.has_method("show_popup"):
		assets_popup.call("show_popup")


func _setup_bankruptcy_popup_async() -> void:
	await _setup_bankruptcy_popup()


func _resolve_bankruptcy_transfer(debtor_idx: int, creditor_idx: int) -> void:
	# Transfer properties
	for i in range(GameState.board.size()):
		var space = GameState.board[i]
		if space is Ownable:
			var ownable := space as Ownable
			if ownable._is_owned and int(ownable._player_owner) == debtor_idx:
				if creditor_idx >= 0:
					# Transfer to creditor player
					ownable._player_owner = creditor_idx
					ownable._is_owned = true
				else:
					ownable._player_owner = -1
					ownable._is_owned = false

	# Transfer cash
	var debtor_cash := GameController.get_player_balance(debtor_idx)
	if debtor_cash > 0:
		GameState.charge_player(debtor_idx, debtor_cash)

		if creditor_idx >= 0 and creditor_idx < GameState.players.size():
			GameState.credit_player(creditor_idx, debtor_cash)

	# Mark debtor eliminated
	if debtor_idx >= 0 and debtor_idx < GameState.players.size():
		if GameState.players[debtor_idx].has_variable("is_bankrupt"):
			GameState.players[debtor_idx].is_bankrupt = true
		if GameState.players[debtor_idx].has_variable("is_active"):
			GameState.players[debtor_idx].is_active = false

	# remove debtor piece so it doesn't keep moving
	if debtor_idx >= 0 and debtor_idx < pieces.size():
		var debtor_piece := pieces[debtor_idx]
		if is_instance_valid(debtor_piece):
			debtor_piece.visible = false
			debtor_piece.set_process(false)
			debtor_piece.set_physics_process(false)


func _count_active_players() -> int:
	var count := 0
	for p in GameState.players:
		var active := true
		if p.has_variable("is_active"):
			active = p.is_active
		elif p.has_variable("is_bankrupt"):
			active = not p.is_bankru
		if active:
			count += 1
	return count


func _get_last_active_player_index() -> int:
	for i in range(GameState.players.size()):
		var p = GameState.players[i]
		var active := true
		if p.has_variable("is_active"):
			active = p.is_active
		elif p.has_variable("is_bankrupt"):
			active = not p.is_bankrupt
		if active:
			return i
	return -1


func _check_for_winner_and_show_screen() -> void:
	var alive := _count_active_players()
	if alive > 1:
		return

	var winner_idx := _get_last_active_player_index()
	if winner_idx == -1:
		return

	print("GAME OVER: Winner is ", GameState.players[winner_idx].player_name)

	# TODO: Show the Win screen scene here


func _show_win_screen(winner_index: int) -> void:
	print("GAME OVER. Winner is player:", winner_index)

	var winner_name := GameState.players[winner_index].player_name

	if notification_popup:
		notification_popup.show_notification(winner_name + " Wins!", "Congratulations! The game is over.")


func _on_bankruptcy_asset_trade_sell_requested(space_index: int) -> void:
	if pending_debtor_index < 0 or pending_debtor_index >= GameState.players.size():
		push_warning("Bankruptcy trade/sell requested but no pending debtor.")
		return

	# Close the Assets popup immediately
	if assets_popup:
		if assets_popup.has_method("hide_popup"):
			assets_popup.call("hide_popup")
		else:
			assets_popup.visible = false

	if trade_popup == null:
		push_warning("Trade popup is null.")
		return

	# Open trade popup with preselected asset
	if trade_popup.has_method("show_for_player_with_preselected_offer"):
		trade_popup.call("show_for_player_with_preselected_offer", pending_debtor_index, space_index)
	else:
		trade_popup.call("show_for_current_player", pending_debtor_index)


func _skip_inactive_turn() -> void:
	if not GameState.game_active:
		return
	GameController.next_player()


func _advance_after_bankruptcy() -> void:
	# If the eliminated player was the current player, move on.
	GameController.next_player()
	
func _on_action_completed() -> void:
	var p := GameController.get_current_player()
	if not p:
		return
	# If they rolled doubles, allow another roll by clearing has_rolled
	# (DiceRollPanel should re-enable the Roll button automatically)
	if p.last_roll_was_doubles:
		p.has_rolled = false
		p.last_roll_was_doubles = false

func _on_doubles_rolled() -> void:
	if notification_popup:
		notification_popup.show_notification("Doubles!", "Roll again.")
		

func _on_colorblind_mode_changed(enabled: bool) -> void:
	if not has_node("ColorBlindSymbols"):
		return

	if enabled:
		_spawn_colorblind_symbols()

	$ColorBlindSymbols.visible = enabled
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		# If settings is open, close settings first and return to pause menu
		if settings_menu and settings_menu.visible:
			if settings_menu.has_method("close_menu"):
				settings_menu.close_menu()
			else:
				settings_menu.hide()
				if pause_menu and pause_menu.has_method("show_menu_only"):
					pause_menu.show_menu_only()

			get_viewport().set_input_as_handled()
			return

		# Toggle pause using the REAL pause state, not visibility
		if pause_menu:
			var currently_paused: bool = pause_menu.is_game_paused() if pause_menu.has_method("is_game_paused") else get_tree().paused
			pause_menu.set_paused(not currently_paused)
			get_viewport().set_input_as_handled()
			
			
func _setup_pause_menu() -> void:
	pause_menu_layer = CanvasLayer.new()
	pause_menu_layer.name = "PauseMenuLayer"
	pause_menu_layer.layer = 500

	pause_menu = PauseMenuScene.instantiate()
	pause_menu.name = "PauseMenu"

	pause_menu_layer.add_child(pause_menu)
	get_tree().root.call_deferred("add_child", pause_menu_layer)

	pause_menu.hide()

	if pause_menu.has_signal("settings_requested"):
		pause_menu.settings_requested.connect(_on_pause_settings_requested)

	if pause_menu.has_signal("quit_requested"):
		pause_menu.quit_requested.connect(_on_pause_quit_requested)
		
		
func _on_pause_settings_requested() -> void:
	if pause_menu:
		pause_menu.hide_menu_only()

	if settings_menu:
		if settings_menu.has_method("open"):
			settings_menu.open()
		else:
			settings_menu.show()
		
		
func _setup_settings_menu() -> void:
	settings_menu_layer = CanvasLayer.new()
	settings_menu_layer.name = "SettingsMenuLayer"
	settings_menu_layer.layer = 501

	settings_menu = SettingsMenuScene.instantiate()
	settings_menu.name = "SettingsMenu"

	settings_menu_layer.add_child(settings_menu)
	get_tree().root.call_deferred("add_child", settings_menu_layer)

	settings_menu.hide()

	if settings_menu.has_signal("closed"):
		settings_menu.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	if settings_menu:
		settings_menu.hide()

	
	if pause_menu and pause_menu.has_method("show_menu_only"):
		pause_menu.show_menu_only()

func _on_pause_quit_requested() -> void:
	if pause_menu:
		pause_menu.set_paused(false)

	_cleanup_root_ui()
	call_deferred("_go_to_start_menu")


func _go_to_start_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")


func _cleanup_root_ui() -> void:
	# Free CanvasLayers / root-level UI added by Board
	var names_to_remove := [
		"DiceRollLayer",
		"MoneyHUDLayer",
		"PlayerNameHUDLayer",
		"PlayerPropertiesPreviewLayer",
		"EndTurnButtonLayer",
		"PauseMenuLayer",
		"SettingsMenuLayer"
	]

	for child in get_tree().root.get_children():
		if child.name in names_to_remove:
			child.queue_free()

	# Free root-added popups/panels that are instantiated directly
	if space_info_panel and is_instance_valid(space_info_panel):
		space_info_panel.queue_free()
		space_info_panel = null

	if space_action_popup and is_instance_valid(space_action_popup):
		space_action_popup.queue_free()
		space_action_popup = null

	if trade_popup and is_instance_valid(trade_popup):
		trade_popup.queue_free()
		trade_popup = null

	if auction_popup and is_instance_valid(auction_popup):
		auction_popup.queue_free()
		auction_popup = null

	if property_details_popup and is_instance_valid(property_details_popup):
		property_details_popup.queue_free()
		property_details_popup = null

	if bankruptcy_popup and is_instance_valid(bankruptcy_popup):
		bankruptcy_popup.queue_free()
		bankruptcy_popup = null

	if assets_popup and is_instance_valid(assets_popup):
		assets_popup.queue_free()
		assets_popup = null

	# Optional: if settings menu layer exists but wasn't found by name for some reason
	if pause_menu_layer and is_instance_valid(pause_menu_layer):
		pause_menu_layer.queue_free()
		pause_menu_layer = null

	if settings_menu_layer and is_instance_valid(settings_menu_layer):
		settings_menu_layer.queue_free()
		settings_menu_layer = null
		
		
		
func _spawn_colorblind_symbols() -> void:
	if not has_node("ColorBlindSymbols"):
		return

	var symbol_layer = $ColorBlindSymbols

	for child in symbol_layer.get_children():
		child.queue_free()

	var board_layer: TileMapLayer = $TileMap/TileMapLayer

	for space_index in COLORBLIND_SYMBOL_SPACES.keys():
		var set_name = COLORBLIND_SYMBOL_SPACES[space_index]

		if not symbol_textures.has(set_name):
			continue

		var coords := _get_coords_from_space_index(space_index)
		if coords == Vector2i(-1, -1):
			continue

		var tile_pos = board_layer.map_to_local(coords)
		var pos = tile_pos + _get_symbol_offset_for_space(space_index, coords)
		var scale = _get_symbol_scale_for_coords(coords)
		var texture = symbol_textures[set_name]

		var outline_offsets = [
			Vector2(-2, 0),
			Vector2(2, 0),
			Vector2(0, -2),
			Vector2(0, 2),
			Vector2(-2, -2),
			Vector2(2, -2),
			Vector2(-2, 2),
			Vector2(2, 2)
		]

		for o in outline_offsets:
			var outline := Sprite2D.new()
			outline.texture = texture
			outline.scale = scale
			outline.modulate = Color(0, 0, 0, 1)
			outline.position = pos + o
			outline.z_index = 49
			symbol_layer.add_child(outline)

		var symbol := Sprite2D.new()
		symbol.texture = texture
		symbol.scale = scale
		symbol.modulate = Color(1, 1, 1, 1)
		symbol.position = pos
		symbol.z_index = 50
		symbol_layer.add_child(symbol)
		
		
func _get_coords_from_space_index(space_index: int) -> Vector2i:
	# corners
	if space_index == 0:
		return Vector2i(10, 0)
	if space_index == 10:
		return Vector2i(10, 10)
	if space_index == 20:
		return Vector2i(0, 10)
	if space_index == 30:
		return Vector2i(0, 0)

	# right edge: 1-9
	if space_index > 0 and space_index < 10:
		return Vector2i(10, space_index)

	# bottom edge: 11-19
	if space_index > 10 and space_index < 20:
		return Vector2i(10 - (space_index - 10), 10)

	# left edge: 21-29
	if space_index > 20 and space_index < 30:
		return Vector2i(0, 10 - (space_index - 20))

	# top edge: 31-39
	if space_index > 30 and space_index < 40:
		return Vector2i(space_index - 30, 0)

	return Vector2i(-1, -1)


func _get_symbol_offset_for_coords(coords: Vector2i) -> Vector2:
	# Tune each side independently
	if coords.y == 10:
		# bottom row
		return Vector2(-1, -8)

	if coords.y == 0:
		# top row
		return Vector2(1, 8)

	if coords.x == 0:
		# left side
		return Vector2(8, 1)

	if coords.x == 10:
		# right side
		return Vector2(-8, -1)

	return Vector2.ZERO


func _get_symbol_scale_for_coords(coords: Vector2i) -> Vector2:
	return Vector2(0.13, 0.13)


func _get_symbol_offset_for_space(space_index: int, coords: Vector2i) -> Vector2:
	# Optional per-space override if needed later
	if COLORBLIND_SYMBOL_OFFSET_OVERRIDES.has(space_index):
		return COLORBLIND_SYMBOL_OFFSET_OVERRIDES[space_index]

	# Right side
	if coords.x == 10:
		return Vector2(-3, -4)

	# Bottom side
	if coords.y == 10:
		return Vector2(3, -2)
		
	#left side
	if coords.x == 0:
		return Vector2(7, 1)

	# Top side
	if coords.y == 0:
		return Vector2(-5, 1)

	return Vector2.ZERO
