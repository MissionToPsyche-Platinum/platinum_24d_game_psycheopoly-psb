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

const MATCH_STATS_POPUP_SCENE = preload("res://scenes/MatchStatsPopup.tscn")
var match_stats_popup: MatchStatsPopup = null
var match_stats_popup_layer: CanvasLayer = null

# Reference to the piece (backward compatibility if needed, but we use pieces/current_piece)
var piece: Node2D = null

# Tile map references
var tile_map_layer: TileMapLayer = null
var highlight_layer: TileMapLayer = null

var pending_card_player_index: int = -1
var pending_card_space_num: int = -1
var pending_card_followup_movement: bool = false


@onready var board_tilemap: Node = $TileMap # reference to tilemap so we can implement the colorblind mode.
@onready var turn_log_panel: Control = $TurnLogLayer/TurnLogPanel

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

const AiTurnBannerScene = preload("res://scenes/AiTurnBanner.tscn")
var ai_turn_banner: Control = null

const AiActionToastScene = preload("res://scenes/AiActionToast.tscn")
var ai_action_toast: Control = null

const FloatingNumberScene = preload("res://scenes/FloatingNumber.tscn")

const SettingsMenuScene = preload("res://scenes/SettingsMenu.tscn")
var settings_menu: Control = null
var settings_menu_layer: CanvasLayer = null

const PauseMenuScene = preload("res://scenes/PauseMenu.tscn")
var pause_menu: Control = null
var pause_menu_layer: CanvasLayer = null

const EndGamePopupScene = preload("res://scenes/EndGamePopup.tscn")
var end_game_popup: EndGamePopup = null
var end_game_popup_layer: CanvasLayer = null

#Game Rules popup
const GameRulesPopupScene = preload("res://scenes/GameRulesPopup.tscn")

var game_rules_popup: CanvasLayer = null
var game_rules_popup_layer: CanvasLayer = null

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
		
	if not GameController.transaction_logged.is_connected(_on_transaction_logged):
		GameController.transaction_logged.connect(_on_transaction_logged)
	if not GameController.player_money_changed.is_connected(_on_player_money_changed):
		GameController.player_money_changed.connect(_on_player_money_changed)

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
	
	#Instantiate game rules
	_setup_game_rules_popup()
	
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
	_setup_ai_turn_banner()
	_setup_ai_action_toast()

	call_deferred("_setup_end_game_popup_async")
	_setup_match_stats_popup()

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
	if not GameController.player_sent_to_jail.is_connected(_on_player_sent_to_jail):
		GameController.player_sent_to_jail.connect(_on_player_sent_to_jail)

	# AI action feedback is handled via transaction_logged (see _on_transaction_logged)

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

func _setup_ai_turn_banner() -> void:
	var banner_layer = CanvasLayer.new()
	banner_layer.name = "AiTurnBannerLayer"
	banner_layer.layer = 15 # Above game board but below most popups

	ai_turn_banner = AiTurnBannerScene.instantiate()
	banner_layer.add_child(ai_turn_banner)
	get_tree().root.call_deferred("add_child", banner_layer)

func _setup_ai_action_toast() -> void:
	var toast_layer = CanvasLayer.new()
	toast_layer.name = "AiActionToastLayer"
	toast_layer.layer = 50 # Below popups but above game

	ai_action_toast = AiActionToastScene.instantiate()
	toast_layer.add_child(ai_action_toast)
	get_tree().root.call_deferred("add_child", toast_layer)
	
func _setup_end_game_popup() -> void:
	# Prevent duplicate creation
	if end_game_popup and is_instance_valid(end_game_popup):
		return

	end_game_popup_layer = CanvasLayer.new()
	end_game_popup_layer.name = "EndGamePopupLayer"
	end_game_popup_layer.layer = 600  # Above pause/settings/notification

	end_game_popup = EndGamePopupScene.instantiate() as EndGamePopup
	end_game_popup.name = "EndGamePopup"

	end_game_popup_layer.add_child(end_game_popup)
	get_tree().root.add_child(end_game_popup_layer)

	# Wait until popup is fully ready before connecting signals
	if end_game_popup and not end_game_popup.is_node_ready():
		await end_game_popup.ready

	if not end_game_popup.replay_current_requested.is_connected(_on_end_game_replay_current_requested):
		end_game_popup.replay_current_requested.connect(_on_end_game_replay_current_requested)

	if not end_game_popup.stats_requested.is_connected(_on_end_game_stats_requested):
		end_game_popup.stats_requested.connect(_on_end_game_stats_requested)

	if not end_game_popup.reconfigure_requested.is_connected(_on_end_game_reconfigure_requested):
		end_game_popup.reconfigure_requested.connect(_on_end_game_reconfigure_requested)

	if not end_game_popup.exit_requested.is_connected(_on_end_game_exit_requested):
		end_game_popup.exit_requested.connect(_on_end_game_exit_requested)

	print("Board: EndGamePopup setup complete")

func _setup_money_hud() -> void:	# Create a CanvasLayer to hold the money HUD (ensures it's always on top)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "MoneyHUDLayer"
	canvas_layer.layer = 9 # Just below dice UI layer

	# Instantiate the money HUD
	money_hud = MoneyHUDScene.instantiate()
	canvas_layer.add_child(money_hud)

	# Add to scene tree
	get_tree().root.call_deferred("add_child", canvas_layer)


func _setup_match_stats_popup() -> void:
	# Prevent duplicate creation
	if match_stats_popup and is_instance_valid(match_stats_popup):
		return

	match_stats_popup_layer = CanvasLayer.new()
	match_stats_popup_layer.name = "MatchStatsPopupLayer"
	match_stats_popup_layer.layer = 601  

	match_stats_popup = MATCH_STATS_POPUP_SCENE.instantiate() as MatchStatsPopup
	match_stats_popup.name = "MatchStatsPopup"

	match_stats_popup_layer.add_child(match_stats_popup)
	get_tree().root.add_child(match_stats_popup_layer)

	# Wait until popup is fully ready before connecting signals
	if match_stats_popup and not match_stats_popup.is_node_ready():
		await match_stats_popup.ready

	if not match_stats_popup.back_requested.is_connected(_on_match_stats_back_requested):
		match_stats_popup.back_requested.connect(_on_match_stats_back_requested)

	print("Board: MatchStatsPopup setup complete")
	

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

	AiManager.ai_declare_bankruptcy.connect(_on_bankruptcy_declared)
	AiManager.ai_pay_bankruptcy.connect(_on_bankruptcy_attempt_pay_requested)

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
	
	var player_name := get_player_log_name(player_index)

	var turn_number: int = _calculate_display_turn_number(player_index)
	var is_new_round: bool = _is_first_active_player_of_round(player_index)

	if turn_log_panel and turn_log_panel.has_method("add_turn_header"):
		turn_log_panel.add_turn_header(player_index, player_name, turn_number, is_new_round)
	else:
			log_event("Turn %d - %s's turn" % [turn_number, player_name])

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

	# Show AI turn banner for AI players
	if current_player and current_player.player_is_ai and ai_turn_banner and ai_turn_banner.has_method("show_banner"):
		ai_turn_banner.show_banner(current_player.player_name)

	if current_player and current_player.is_in_jail:
		current_player.has_rolled = true # Disable regular rolling temporarily
		if jail_popup and jail_popup.has_method("show_for_player") and current_player.player_is_ai == false:
			jail_popup.show_for_player(player_index)
	GameController.turn_setup_complete.emit(player_index)


func _on_turn_ended(player_index: int) -> void:
	print("Board: Turn ended for player ", player_index)

	var player_name := get_player_log_name(player_index)
	log_event("%s ended their turn." % player_name)

	# Hide AI turn banner
	if ai_turn_banner and ai_turn_banner.has_method("hide_banner"):
		ai_turn_banner.hide_banner()
	


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

	# If this movement came from a card, the follow-up movement has now completed.
	# Clear the flag here so doubles logic is not released too early, but future
	# action_completed calls can behave normally again after this landing resolves.
	if pending_card_followup_movement:
		pending_card_followup_movement = false

	var player_name := get_player_log_name(GameState.current_player_index)
	var default_space_name := "Space %d" % space_num
	var space_name := default_space_name
	var landed_space = null

	if space_num >= 0 and space_num < GameState.board.size():
		landed_space = GameState.board[space_num]

		if landed_space != null and landed_space.has_method("get_name"):
			var candidate = str(landed_space.get_name()).strip_edges()
			if candidate != "":
				space_name = candidate
		elif landed_space != null and "space_name" in landed_space:
			var candidate = str(landed_space.space_name).strip_edges()
			if candidate != "":
				space_name = candidate

	if space_name == default_space_name:
		var info = SpaceDataRef.get_space_info(space_num)
		if info.has("name"):
			var fallback_name = str(info["name"]).strip_edges()
			if fallback_name != "":
				space_name = fallback_name

	log_event("%s landed on %s." % [player_name, space_name])

	# Capture card context NOW so delayed card logging doesn't use the next player
	if landed_space != null:
		var scr: Script = landed_space.get_script() as Script
		var gname := ""
		if scr != null:
			gname = scr.get_global_name()

		if gname == "CardSpace":
			pending_card_player_index = GameState.current_player_index
			pending_card_space_num = space_num
		else:
			pending_card_player_index = -1
			pending_card_space_num = -1
	else:
		pending_card_player_index = -1
		pending_card_space_num = -1

	# Skip space action popup if the player was just sent to jail — the
	# notification popup and jail popup handle everything from here.
	var current_player := GameController.get_current_player()
	if current_player and current_player.is_in_jail:
		return

	if space_action_popup:
		if not space_action_popup.is_node_ready():
			await space_action_popup.ready

		if current_player.player_is_ai == false:
			space_action_popup.show_actions(space_num)

			# Only humans use this fallback auto-complete behavior
			await get_tree().process_frame
			if not space_action_popup.visible:
				GameController.action_completed.emit()
		else:
			# AI may trigger async card / popup flows, so try not to auto-complete here
			AiManager.ai_lands_on_space(space_num)


func _on_purchase_pressed(space_num: int) -> void:
	print("Player wants to purchase space: ", space_num)

	if space_num < 0 or space_num >= GameState.board.size():
		push_warning("Purchase pressed with invalid space number: %d" % space_num)
		GameController.action_completed.emit()
		return

	var player_index := GameState.current_player_index
	if player_index < 0 or player_index >= GameState.players.size():
		push_warning("Purchase pressed with invalid player index: %d" % player_index)
		GameController.action_completed.emit()
		return

	var space = GameState.board[space_num]
	if space == null:
		push_warning("Purchase pressed but space is null at index: %d" % space_num)
		GameController.action_completed.emit()
		return

	if space is Ownable:
		GameController.purchase_property.emit(space, player_index)
	else:
		push_warning("Purchase pressed on non-ownable space: %d" % space_num)

	GameController.action_completed.emit()


func _on_auction_pressed(space_num: int) -> void:
	_start_auction(space_num)
	
func _start_auction(space_num: int) -> void:
	print("Auction started for space: ", space_num)

	# Hide the action popup so it doesn't sit on top
	if space_action_popup:
		space_action_popup.hide()

	# If an AI toast is currently showing, let it finish before opening auction
	await _wait_for_ai_toast_before_popup()

	# Make sure auction popup is fully ready (prevents null @onready fields)
	if auction_popup and not auction_popup.is_node_ready():
		await auction_popup.ready

	# Build participant list (only active / non-bankrupt players)
	var bidder_indexes: Array[int] = []
	for i in range(GameState.players.size()):
		var is_active := true
		if not GameState.player_active.is_empty() and i < GameState.player_active.size():
			is_active = bool(GameState.player_active[i])

		if not is_active:
			continue

		var p = GameState.players[i]
		if p == null:
			continue

		if "is_bankrupt" in p and p.is_bankrupt:
			continue

		bidder_indexes.append(i)

	# No valid auction participants
	if bidder_indexes.size() <= 1:
		if auction_popup:
			auction_popup.hide_popup()
		GameController.action_completed.emit()
		return

	# Show the auction popup
	if auction_popup:
		auction_popup.visible = true
		auction_popup.show_popup(space_num)

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
		await get_tree().create_timer(1.4).timeout
		auction_popup.hide_popup()

	# tell the game flow we’re done with this action and move on.
	GameController.action_completed.emit()


func _on_move_pressed(space_num: int) -> void:
	# Handling for "Solar Storm" (Go to Jail/Launch Pad)
	if space_num == 30:
		print("Solar Storm! Transporting to Launch Pad...")
		# Jail must be set before teleporting so movement_finished skips the space action popup
		GameController.send_player_to_jail(GameState.current_player_index)
		if current_piece:
			var old_space: int = int(current_piece.board_space)
			current_piece.teleport_to_space(10)
			update_piece_layouts_at(old_space)
			update_piece_layouts_at(10)
		# _on_player_sent_to_jail handles the notification and action_completed
		return
	GameController.action_completed.emit()


func _on_draw_card_pressed(space_num: int) -> void:
	var acting_player_index := pending_card_player_index
	if acting_player_index < 0:
		acting_player_index = GameState.current_player_index

	var player_name := get_player_log_name(acting_player_index)
	var space_name := "a card space"

	var effective_space_num := space_num
	if effective_space_num < 0 and pending_card_space_num >= 0:
		effective_space_num = pending_card_space_num

	var space_info = SpaceDataRef.get_space_info(effective_space_num)
	if space_info.has("name"):
		var candidate := str(space_info["name"]).strip_edges()
		if candidate != "":
			space_name = candidate

	log_event("%s drew a card from %s." % [player_name, space_name])

	# Clear pending card context after logging
	pending_card_player_index = -1
	pending_card_space_num = -1

	# action_completed is emitted by chance_card_popup once the card is closed
	pass


func _on_player_sent_to_jail(player_index: int) -> void:
	var player_name := get_player_log_name(player_index)
	log_event("%s was sent to the Launch Pad." % player_name)

	if notification_popup && GameController.get_current_player().player_is_ai == false:
		notification_popup.show_notification("Sent to the Launch Pad!", "You have been sent to the Launch Pad.")
		await notification_popup.dismissed

	GameController.action_completed.emit()


func _on_pay_pressed(space_num: int) -> void:
	print("Player pressed PAY on space:", space_num)

	var current_player := GameState.current_player_index
	if current_player < 0 or current_player >= GameState.players.size():
		push_warning("PAY: invalid current player index")
		GameController.action_completed.emit()
		return

	var player_name := get_player_log_name(current_player)
	var space_name := "Space %d" % space_num

	var space_info = SpaceDataRef.get_space_info(space_num)
	if space_info.has("name"):
		var candidate := str(space_info["name"]).strip_edges()
		if candidate != "":
			space_name = candidate

	var space := GameState.board[space_num]

	if space is Ownable:
		var property := space as Ownable
		print("PAY DEBUG: script=", property.get_script(), " global_name=", property.get_script().get_global_name())
		GameController.pay_rent.emit(property, current_player)
		GameController.action_completed.emit()
		return

	var t := str(space_info.get("type", ""))

	if t == "cost" or t == "expense":
		var amount := int(space_info.get("amount", 0))
		if amount > 0:
			var paid := GameController.request_payment(current_player, amount, "space cost")
			if paid:
				log_event("%s paid $%d on %s." % [player_name, amount, space_name])
		else:
			push_warning("PAY: cost/expense space but amount missing/0 at space " + str(space_num))

	GameController.action_completed.emit()


func _on_close_pressed() -> void:
	print("Player closed the action popup")

	var space_num := -1
	if current_piece and is_instance_valid(current_piece):
		space_num = int(current_piece.board_space)

	var player_name := get_player_log_name(GameState.current_player_index)

	if space_num >= 0:
		var space_name := "Space %d" % space_num
		var space_info = SpaceDataRef.get_space_info(space_num)

		if space_info.has("name"):
			var candidate := str(space_info["name"]).strip_edges()
			if candidate != "":
				space_name = candidate

		match space_num:
			0:
				log_event("%s landed on %s." % [player_name, space_name])
			10:
				var current_player := GameController.get_current_player()
				if current_player and current_player.is_in_jail:
					pass
				else:
					log_event("%s is just visiting the Launch Pad." % player_name)
			20:
				log_event("%s landed on %s." % [player_name, space_name])
			_:
				pass

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

	if has_node("ColorBlindSymbols"):
		$ColorBlindSymbols.visible = SettingsManager.is_colorblind_enabled()


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

	# If the mouse is over the Turn Log UI, do not allow board hover/click handling.
	if turn_log_panel and turn_log_panel.has_method("is_mouse_over_ui") and turn_log_panel.is_mouse_over_ui():
		# Clear hover highlight while hovering over the turn log area
		if hovered_tile != Vector2i(-1, -1) and hovered_tile != selected_tile:
			highlight_layer.erase_cell(hovered_tile)
		hovered_tile = Vector2i(-1, -1)
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
	
	var roller_name := get_player_log_name(GameState.current_player_index)

	if is_doubles:
		log_event("%s rolled %d + %d = %d (Doubles!)" % [roller_name, d1, d2, total])
	else:
		log_event("%s rolled %d + %d = %d" % [roller_name, d1, d2, total])

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
				log_event("%s rolled doubles three times and was sent to the Launch Pad." % roller_name)
				GameController.send_player_to_jail(GameState.current_player_index)
				_card_teleport_movement(10) # Jail space
				GameController.emit_signal("player_rolled", current_player)
				# _on_player_sent_to_jail handles the notification and action_completed
				if (current_player.player_is_ai == true):
					AiManager.handle_doubles_jail()
				else:
					# For humans, end turn after going to jail
					GameController.end_turn()
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

	var player_name := get_player_log_name(GameState.current_player_index)

	if is_doubles:
		log_event("%s rolled doubles in the Launch Pad and left it." % player_name)

		print("Rolled doubles! Escaped jail.")

		GameController.release_player_from_jail(GameState.current_player_index)

		# Move the rolled amount
		var old_space: int = int(current_piece.board_space)
		current_piece.move_forward(total)
		update_piece_layouts_at(old_space)
	else:
		if player.turns_in_jail == 3:
			print("3rd turn in jail without doubles. Forced to pay $50 bail.")
			log_event("%s did not roll doubles on their final Launch Pad turn and must pay $50 to leave." % player_name)

			var paid := GameController.request_payment(GameState.current_player_index, 50, "Launch Permit")
			if not paid:
				log_event("%s could not afford the $50 Launch Permit and may go bankrupt." % player_name)
			else:
				log_event("%s paid $50 to leave the Launch Pad after failing to roll doubles." % player_name)

			GameController.release_player_from_jail(GameState.current_player_index)

			var old_space: int = int(current_piece.board_space)
			current_piece.move_forward(total)
			update_piece_layouts_at(old_space)
		else:
			print("Did not roll doubles. Stay in jail.")
			log_event("%s did not roll doubles and remains on the Launch Pad (%d/3 attempts used)." % [player_name, player.turns_in_jail])

			# Don't move, turn effectively over. Need to simulate action completed so End Turn button enables.
			GameController.action_completed.emit()

	GameController.emit_signal("player_rolled", player)



func _card_forward_movement(move_spaces: int) -> void:
	pending_card_followup_movement = true

	# Move the current player's piece forward to the correct space
	if current_piece:
		var old_space: int = int(current_piece.board_space)
		current_piece.move_forward(move_spaces)
		# Update the space we just left so remaining pieces re-center
		update_piece_layouts_at(old_space)


func _card_teleport_movement(space_location: int) -> void:
	pending_card_followup_movement = true

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
	
	## Colors are muddy on token pieces looks like color is applied in piece script and here
	## commenting this out to see if it helps
		#if i < GameState.players.size():
			#var c: Color = GameState.players[i].player_color
			#call_deferred("_apply_color_to_piece", piece_instance, c)

	# Layout at GO so pieces don't overlap
	update_piece_layouts_at(0)

	if pieces.size() > 0:
		current_piece = pieces[0]
		piece = current_piece


	##commenting out this whole function to see if it helps. Colors are applied twice, letting
	## piece script handle coloring.
#func _apply_color_to_piece(piece_instance: Node2D, c: Color) -> void:
	## 1) Best: Piece exposes an API
	#if piece_instance.has_method("set_player_color"):
		#piece_instance.call("set_player_color", c)
		#return
#
	## 2) Try to color ANY Sprite2D under the piece (recursive)
	#var painted := false
	#for n in piece_instance.find_children("*", "Sprite2D", true, false):
		#(n as Sprite2D).modulate = c
		#painted = true
#
	#if not painted:
		#for n in piece_instance.find_children("*", "CanvasItem", true, false):
			#(n as CanvasItem).modulate = c
			#painted = true
#
	#if not painted and piece_instance is CanvasItem:
		#(piece_instance as CanvasItem).modulate = c
#
	#print("Applied color to piece", piece_instance.name, " painted=", painted, " color=", c)


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
	var creditor := pending_creditor_index
	var amount := pending_amount_owed
	var reason := pending_reason

	if eliminated_player < 0 or eliminated_player >= GameState.players.size():
		push_warning("Board: invalid eliminated player during bankruptcy.")
		return

	# Capture names BEFORE we clear anything
	var debtor_name := get_player_log_name(eliminated_player)
	var creditor_name := "the Bank"

	if creditor >= 0 and creditor < GameState.players.size():
		creditor_name = get_player_log_name(creditor)

	# -------------------------
	# Turn Log: bankruptcy declaration
	# -------------------------
	if creditor >= 0 and creditor < GameState.players.size():
		log_event("%s declared bankruptcy to %s." % [debtor_name, creditor_name])
	else:
		log_event("%s declared bankruptcy to the Bank." % debtor_name)

	# Optional detail line (nice for clarity in the log)
	if amount > 0 and reason.strip_edges() != "":
		log_event("%s could not pay $%d for %s." % [debtor_name, amount, reason])
	elif amount > 0:
		log_event("%s could not pay $%d." % [debtor_name, amount])


	# Capture net worth beforethe assets/cash are transferred away
	var debtor := GameState.players[eliminated_player]
	if debtor != null and debtor.net_worth_before_bankruptcy < 0:
		debtor.net_worth_before_bankruptcy = int(GameState.get_player_final_net_worth(eliminated_player))
	
	# Resolve transfer of assets/cash before elimination
	_resolve_bankruptcy_transfer(eliminated_player, creditor)

	# Log asset transfer result

	if creditor >= 0 and creditor < GameState.players.size():
		log_event("%s's remaining assets were transferred to %s." % [debtor_name, creditor_name])
	else:
		log_event("%s's remaining assets were returned to the Bank." % debtor_name)

	# Mark player inactive in GameState

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

	# Final elimination log
	log_event("%s was removed from the game." % debtor_name)

	_clear_pending_bankruptcy()


	# Check win condition
	var active_count := 0
	var last_active := -1
	for i in range(GameState.player_active.size()):
		if GameState.player_active[i]:
			active_count += 1
			last_active = i

	if active_count == 1:
		log_event("%s wins the game!" % get_player_log_name(last_active))
		_show_win_screen(last_active)
		return


	# Advance turn immediately so we never land on a bankrupt player

	call_deferred("_advance_after_bankruptcy")

func enter_bankruptcy(debtor_idx: int, creditor_idx: int, amount: int, reason: String) -> void:
	pending_debtor_index = debtor_idx
	pending_creditor_index = creditor_idx
	pending_amount_owed = amount
	pending_reason = reason

	var creditor_name := "Bank"
	if creditor_idx >= 0 and creditor_idx < GameState.players.size():
		creditor_name = GameState.players[creditor_idx].player_name

	if (GameState.players[debtor_idx].player_is_ai == false):
		bankruptcy_popup.show_popup(
			debtor_idx,
			creditor_name,
			reason,
			amount,
			GameController.get_player_balance(debtor_idx)
		)
	else:
		AiManager.ai_bankruptcy.emit(amount)

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
		if "is_bankrupt" in GameState.players[debtor_idx]:
			GameState.players[debtor_idx].is_bankrupt = true
		if "is_active" in GameState.players[debtor_idx]:
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
		if "is_active" in p:
			active = p.is_active
		elif "is_bankrupt" in p:
			active = not p.is_bankrupt
		if active:
			count += 1
	return count


func _get_last_active_player_index() -> int:
	for i in range(GameState.players.size()):
		var p = GameState.players[i]
		var active := true
		if "is_active" in p:
			active = p.is_active
		elif "is_bankrupt" in p:
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

	if winner_index < 0 or winner_index >= GameState.players.size():
		push_warning("Invalid winner index for end game screen.")
		return

	var winner_name := get_player_log_name(winner_index)

	# Stop the game so no more turns/actions continue
	GameState.game_active = false

	# Hide/disable normal gameplay UI if they exist
	if space_action_popup and is_instance_valid(space_action_popup):
		if space_action_popup.has_method("hide_popup"):
			space_action_popup.hide_popup()
		else:
			space_action_popup.visible = false

	if bankruptcy_popup and is_instance_valid(bankruptcy_popup):
		if bankruptcy_popup.has_method("hide_popup"):
			bankruptcy_popup.hide_popup()
		else:
			bankruptcy_popup.visible = false

	if assets_popup and is_instance_valid(assets_popup):
		if assets_popup.has_method("hide_popup"):
			assets_popup.hide_popup()
		else:
			assets_popup.visible = false

	if auction_popup and is_instance_valid(auction_popup):
		if auction_popup.has_method("hide_popup"):
			auction_popup.hide_popup()
		else:
			auction_popup.visible = false

	if trade_popup and is_instance_valid(trade_popup):
		if trade_popup.has_method("hide_popup"):
			trade_popup.hide_popup()
		else:
			trade_popup.visible = false

	
	if end_game_popup and is_instance_valid(end_game_popup):
		end_game_popup.show_end_game(
			winner_name,
			"Congratulations! %s is the last player remaining." % winner_name
		)
	else:
		push_warning("EndGamePopup is null, falling back to notification popup.")
		if notification_popup and is_instance_valid(notification_popup):
			notification_popup.show_notification(
				winner_name + " Wins!",
				"Congratulations! The game is over."
			)

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

	# If a chance/community-style card is still causing follow-up movement,
	# do not clear doubles/rolled state yet. The destination landing still
	# needs to resolve as part of the same turn.
	if pending_card_followup_movement:
		return

	# If they rolled doubles, allow another roll by clearing has_rolled
	# (DiceRollPanel should re-enable the Roll button automatically)
	if p.last_roll_was_doubles:
		p.has_rolled = false
		p.last_roll_was_doubles = false

func _on_doubles_rolled() -> void:
	var current_player := GameController.get_current_player()
	if current_player and current_player.player_is_ai:
		if ai_action_toast and ai_action_toast.has_method("show_toast"):
			if current_player.is_in_jail:
				ai_action_toast.show_toast("Rolled doubles! Leaving the Launch Pad.")
			else:
				ai_action_toast.show_toast("Rolled doubles! Rolling again.")
		return

	if notification_popup:
		if current_player and current_player.is_in_jail:
			notification_popup.show_notification("Doubles!", "Go for Launch! Move forward.")
		else:
			notification_popup.show_notification("Doubles!", "Roll again.")
		

func _on_colorblind_mode_changed(enabled: bool) -> void:
	if has_node("ColorBlindSymbols"):
		if enabled:
			_spawn_colorblind_symbols()

		$ColorBlindSymbols.visible = enabled

	if space_info_panel and current_piece and not is_tile_selected:
		space_info_panel.update_space_display(current_piece.board_space)
	
func _on_transaction_logged(message: String) -> void:
	log_event(message)

	var current_player := GameController.get_current_player()

	# Show special toast for passing GO
	if "Passed GO" in message:
		if ai_action_toast and ai_action_toast.has_method("show_toast"):
			ai_action_toast.show_toast("Passed GO! Collect $200")
	# Show AI action toast for other AI actions
	elif current_player and current_player.player_is_ai and ai_action_toast and ai_action_toast.has_method("show_toast"):
		ai_action_toast.show_toast(message)

func _on_player_money_changed(player_index: int, delta: int) -> void:
	# Only show floating numbers for the human player viewing the board
	var current_player := GameController.get_current_player()
	if not current_player:
		return
	if GameState.current_player_index != player_index:
		return
	if delta == 0:
		return
	_spawn_floating_number(delta)

func _spawn_floating_number(amount: int) -> void:
	if not money_hud or not is_instance_valid(money_hud):
		return

	var floating_num = FloatingNumberScene.instantiate()
	floating_num.add_to_group("floating_money_numbers")
	money_hud.add_child(floating_num)
	floating_num.z_index = 100

	# Stagger if other floating numbers are still alive
	var existing := get_tree().get_nodes_in_group("floating_money_numbers").size() - 1
	var stack_offset := Vector2(0, -18 * existing)

	# Position to the right of the money panel
	var panel := money_hud.get_node_or_null("Panel") as Control
	if panel:
		floating_num.position = Vector2(panel.position.x + panel.size.x + 8, panel.position.y + (panel.size.y - 24) * 0.5) + stack_offset
	else:
		floating_num.position = Vector2(120, -20) + stack_offset

	if floating_num.has_method("play"):
		floating_num.call("play", amount)

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

	if pause_menu.has_signal("how_to_play_requested"):
		pause_menu.how_to_play_requested.connect(_on_pause_how_to_play_requested)
		

func _on_pause_settings_requested() -> void:
	if pause_menu:
		pause_menu.hide_menu_only()

	if settings_menu:
		if settings_menu.has_method("open"):
			settings_menu.open()
		else:
			settings_menu.show()
			
			
func _on_pause_quit_requested() -> void:
	if pause_menu:
		pause_menu.set_paused(false)

	# Reset persistent singleton state before leaving the board
	if GameState and GameState.has_method("reset_for_new_game"):
		GameState.reset_for_new_game()

	_cleanup_root_ui()
	call_deferred("_go_to_start_menu")
		
		
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
		
func _setup_game_rules_popup() -> void:
	game_rules_popup_layer = CanvasLayer.new()
	game_rules_popup_layer.name = "GameRulesPopupLayer"
	game_rules_popup_layer.layer = 550

	game_rules_popup = GameRulesPopupScene.instantiate()
	game_rules_popup.name = "GameRulesPopup"

	game_rules_popup_layer.add_child(game_rules_popup)
	get_tree().root.call_deferred("add_child", game_rules_popup_layer)

	if game_rules_popup and is_instance_valid(game_rules_popup):
		game_rules_popup.hide()

	if game_rules_popup.has_signal("closed"):
		game_rules_popup.closed.connect(_on_game_rules_closed)

	print("Board: GameRulesPopup setup complete")
	
func _on_game_rules_closed() -> void:
	print("Board: Game Rules closed")

	_show_board_ui_after_rules()

	if pause_menu and is_instance_valid(pause_menu):
		pause_menu.show_menu_only()

	
func _on_pause_how_to_play_requested() -> void:
	print("Board: How to Play requested")

	_hide_board_ui_for_rules()

	if pause_menu and is_instance_valid(pause_menu):
		pause_menu.hide_menu_only()

	if game_rules_popup and is_instance_valid(game_rules_popup):
		game_rules_popup.show_popup()


func _go_to_start_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")
	
func _reload_current_game_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/GameBoard.tscn")


func _go_to_game_setup_screen() -> void:
	get_tree().change_scene_to_file("res://scenes/GameSetupScreen.tscn")


func _cleanup_root_ui() -> void:
	# Hide popups first
	if space_action_popup and is_instance_valid(space_action_popup):
		space_action_popup.hide()

	if trade_popup and is_instance_valid(trade_popup):
		trade_popup.hide()

	if auction_popup and is_instance_valid(auction_popup):
		auction_popup.hide()

	if property_details_popup and is_instance_valid(property_details_popup):
		property_details_popup.hide()

	if bankruptcy_popup and is_instance_valid(bankruptcy_popup):
		bankruptcy_popup.hide()

	if assets_popup and is_instance_valid(assets_popup):
		assets_popup.hide()

	if notification_popup and is_instance_valid(notification_popup):
		notification_popup.hide()

	if jail_popup and is_instance_valid(jail_popup):
		jail_popup.hide()

	if end_game_popup and is_instance_valid(end_game_popup):
		end_game_popup.hide()

	if match_stats_popup and is_instance_valid(match_stats_popup):
		match_stats_popup.hide()

	if game_rules_popup and is_instance_valid(game_rules_popup):
		game_rules_popup.hide()

	if player_properties_preview and is_instance_valid(player_properties_preview):
		player_properties_preview.hide()

	# Free root UI layers added by Board
	var names_to_remove := [
		"DiceRollLayer",
		"MoneyHUDLayer",
		"PlayerNameHUDLayer",
		"PlayerPropertiesPreviewLayer",
		"EndTurnButtonLayer",
		"PauseMenuLayer",
		"SettingsMenuLayer",
		"EndGamePopupLayer",
		"MatchStatsPopupLayer",
		"AiTurnBannerLayer",
		"AiActionToastLayer",
		"GameRulesPopupLayer"
	]

	for child in get_tree().root.get_children():
		if child.name in names_to_remove:
			child.queue_free()

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

	if notification_popup and is_instance_valid(notification_popup):
		notification_popup.queue_free()
		notification_popup = null

	if jail_popup and is_instance_valid(jail_popup):
		jail_popup.queue_free()
		jail_popup = null

	if end_game_popup and is_instance_valid(end_game_popup):
		end_game_popup.queue_free()
		end_game_popup = null
	
	if match_stats_popup and is_instance_valid(match_stats_popup):
		match_stats_popup.queue_free()
		match_stats_popup = null

	if pause_menu_layer and is_instance_valid(pause_menu_layer):
		pause_menu_layer.queue_free()
		pause_menu_layer = null

	if settings_menu_layer and is_instance_valid(settings_menu_layer):
		settings_menu_layer.queue_free()
		settings_menu_layer = null
		
	if match_stats_popup_layer and is_instance_valid(match_stats_popup_layer):
		match_stats_popup_layer.queue_free()
		match_stats_popup_layer = null

	if game_rules_popup and is_instance_valid(game_rules_popup):
		game_rules_popup.queue_free()
		game_rules_popup = null

	if game_rules_popup_layer and is_instance_valid(game_rules_popup_layer):
		game_rules_popup_layer.queue_free()
		game_rules_popup_layer = null

	if player_properties_preview and is_instance_valid(player_properties_preview):
		player_properties_preview.queue_free()
		player_properties_preview = null

	if ai_turn_banner and is_instance_valid(ai_turn_banner):
		ai_turn_banner.hide()
		ai_turn_banner = null

	if ai_action_toast and is_instance_valid(ai_action_toast):
		ai_action_toast.hide()
		ai_action_toast = null
		
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


func log_event(message: String) -> void:
	if turn_log_panel and turn_log_panel.has_method("add_log_entry"):
		turn_log_panel.add_log_entry(message)
		
		

func get_player_log_name(player_index: int) -> String:
	if player_index < 0 or player_index >= GameState.players.size():
		return "Unknown Player"

	if GameState.has_method("get_player_display_name"):
		var display_name = str(GameState.get_player_display_name(player_index)).strip_edges()
		if display_name != "":
			return display_name

	var player = GameState.players[player_index]
	if player and player.has_variable("player_name"):
		var player_name = str(player.player_name).strip_edges()
		if player_name != "":
			return player_name

	return "Player %d" % (player_index + 1)
	
func _calculate_display_turn_number(player_index: int) -> int:
	var total_players: int = maxi(1, GameState.player_count)

	# Track how many turn-start events we've processed
	if not has_meta("turn_start_counter"):
		set_meta("turn_start_counter", 0)

	var counter: int = int(get_meta("turn_start_counter"))

	var round_number: int = int(floor(float(counter) / float(total_players))) + 1
	set_meta("turn_start_counter", counter + 1)

	return round_number

func _is_first_active_player_of_round(player_index: int) -> bool:
	if not GameState.player_active.is_empty():
		for i in range(GameState.player_active.size()):
			if GameState.player_active[i]:
				return i == player_index

	return player_index == 0

func _on_end_game_replay_current_requested() -> void:
	print("EndGamePopup: Replay with current setup requested")

	if end_game_popup and is_instance_valid(end_game_popup):
		end_game_popup.hide_popup()

	# Reset persistent singleton state before reloading the board
	if GameState and GameState.has_method("reset_for_replay"):
		GameState.reset_for_replay()

	_cleanup_root_ui()

	call_deferred("_reload_current_game_scene")


func _on_end_game_stats_requested() -> void:
	print("EndGamePopup: View match stats requested")

	if end_game_popup and is_instance_valid(end_game_popup):
		end_game_popup.hide_popup()

	if match_stats_popup and is_instance_valid(match_stats_popup):
		var winner_index := -1
		var best_net_worth := -1

		for i in range(GameState.players.size()):
			var p = GameState.players[i]
			if p == null:
				continue

			var is_active := true
			if i < GameState.player_active.size():
				is_active = bool(GameState.player_active[i])

			var net_worth := int(GameState.get_player_final_net_worth(i))

			if is_active and net_worth > best_net_worth:
				best_net_worth = net_worth
				winner_index = i

		if winner_index == -1:
			for i in range(GameState.players.size()):
				var p = GameState.players[i]
				if p == null:
					continue

				var net_worth := int(GameState.get_player_final_net_worth(i))
				if net_worth > best_net_worth:
					best_net_worth = net_worth
					winner_index = i

		var winner_name := "Unknown"
		if winner_index >= 0:
			winner_name = GameState.get_player_display_name(winner_index)

		var duration_text := GameState.format_match_duration()

		var summary := "Winner: %s\nDuration: %s" % [winner_name, duration_text]

		var detail_lines := []

		for i in range(GameState.players.size()):
			var p = GameState.players[i]
			if p == null:
				continue

			var player_name := GameState.get_player_display_name(i)
			var cash := int(p.balance)
			var props := int(GameState.get_player_properties_acquired(i))
			var earnings := int(GameState.get_player_earnings(i))
			var final_net_worth := int(GameState.get_player_final_net_worth(i))
			var pre_bankruptcy_net_worth := int(p.net_worth_before_bankruptcy)
			var turns_taken := int(GameState.get_player_turns_taken(i))
			var times_in_jail := int(GameState.get_player_times_in_jail(i))

			detail_lines.append("%s" % player_name)
			detail_lines.append("Cash: $%d    Properties Owned: %d" % [cash, props])
			detail_lines.append("Earnings: $%d    Final Net Worth: $%d" % [earnings, final_net_worth])
			detail_lines.append("Turns Taken: %d    Times in Jail: %d" % [turns_taken, times_in_jail])

			if pre_bankruptcy_net_worth >= 0:
				detail_lines.append("Net Worth Before Bankruptcy: $%d" % pre_bankruptcy_net_worth)

			# Add a blank line between players (but not after the last one)
			var has_another_player := false
			for j in range(i + 1, GameState.players.size()):
				if GameState.players[j] != null:
					has_another_player = true
					break

			if has_another_player:
				detail_lines.append("")

		var details := "\n".join(detail_lines)

		match_stats_popup.show_stats(summary, details)


func _on_end_game_reconfigure_requested() -> void:
	print("EndGamePopup: Reconfigure for new game requested")

	if end_game_popup and is_instance_valid(end_game_popup):
		end_game_popup.hide_popup()

	# Reset persistent singleton state before leaving the board
	if GameState and GameState.has_method("reset_for_new_game"):
		GameState.reset_for_new_game()

	_cleanup_root_ui()
	call_deferred("_go_to_game_setup_screen")


func _on_end_game_exit_requested() -> void:
	print("EndGamePopup: Exit requested")

	if end_game_popup and is_instance_valid(end_game_popup):
		end_game_popup.hide_popup()

	# Reset persistent singleton state before leaving the board
	if GameState and GameState.has_method("reset_for_new_game"):
		GameState.reset_for_new_game()

	_cleanup_root_ui()
	call_deferred("_go_to_start_menu")

func _setup_end_game_popup_async() -> void:
	await _setup_end_game_popup()
	

func _on_match_stats_back_requested() -> void:
	print("MatchStatsPopup: Back requested")

	if match_stats_popup and is_instance_valid(match_stats_popup):
		match_stats_popup.hide_popup()

	if end_game_popup and is_instance_valid(end_game_popup):
		end_game_popup.show()


func _hide_board_ui_for_rules() -> void:
	if space_info_panel and is_instance_valid(space_info_panel):
		space_info_panel.hide()

	if dice_roll_ui and is_instance_valid(dice_roll_ui):
		dice_roll_ui.hide()

	if money_hud and is_instance_valid(money_hud):
		money_hud.hide()

	if player_name_hud and is_instance_valid(player_name_hud):
		player_name_hud.hide()

	if player_properties_preview and is_instance_valid(player_properties_preview):
		player_properties_preview.hide()

	if end_turn_button and is_instance_valid(end_turn_button):
		end_turn_button.hide()

	if turn_log_panel and is_instance_valid(turn_log_panel):
		turn_log_panel.hide()
		

func _show_board_ui_after_rules() -> void:
	if space_info_panel and is_instance_valid(space_info_panel):
		space_info_panel.show()

	if dice_roll_ui and is_instance_valid(dice_roll_ui):
		dice_roll_ui.show()

	if money_hud and is_instance_valid(money_hud):
		money_hud.show()

	if player_name_hud and is_instance_valid(player_name_hud):
		player_name_hud.show()

	if player_properties_preview and is_instance_valid(player_properties_preview):
		player_properties_preview.show()

	if end_turn_button and is_instance_valid(end_turn_button):
		end_turn_button.show()

	if turn_log_panel and is_instance_valid(turn_log_panel):
		turn_log_panel.show()

func _wait_for_ai_toast_before_popup() -> void:
	var current_player := GameController.get_current_player()

	if current_player == null:
		return

	if not current_player.player_is_ai:
		return

	if ai_action_toast and is_instance_valid(ai_action_toast) and ai_action_toast.has_method("wait_until_finished"):
		await ai_action_toast.wait_until_finished()


	
	#This UI panel still showing up in start menu if player quits with it visible in game, creating func to help resolve.
func _force_remove_player_properties_preview_everywhere() -> void:
	var nodes_to_remove: Array[Node] = []

	for node in get_tree().root.find_children("*", "", true, false):
		if node == null or not is_instance_valid(node):
			continue

		var should_remove := false
		var node_name := str(node.name)

		if node_name == "PlayerPropertiesPreview" or node_name == "PlayerPropertiesPreviewLayer":
			should_remove = true

		var script = node.get_script()
		if script is Script:
			var script_path := str(script.resource_path).to_lower()
			if "playerpropertiespreview" in script_path or "player_properties_preview" in script_path:
				should_remove = true

		if should_remove:
			nodes_to_remove.append(node)

			var parent = node.get_parent()
			if parent and is_instance_valid(parent):
				var parent_name := str(parent.name)
				if parent_name == "PlayerPropertiesPreviewLayer" and not nodes_to_remove.has(parent):
					nodes_to_remove.append(parent)

	for node in nodes_to_remove:
		if node and is_instance_valid(node):
			if node is CanvasItem:
				node.hide()
			node.queue_free()

	player_properties_preview = null
