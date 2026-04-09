extends Control

## PlayerNameHUD.gd
## Displays the current player's name and chosen color in the top left corner

@onready var panel: Panel = $Panel
@onready var margin_container: MarginContainer = $Panel/MarginContainer
@onready var hbox: HBoxContainer = $Panel/MarginContainer/HBox
@onready var name_label: Label = $Panel/MarginContainer/HBox/NameLabel
@onready var color_indicator: ColorRect = $Panel/MarginContainer/HBox/ColorIndicator

const MIN_PANEL_WIDTH := 120
const MAX_PANEL_WIDTH := 360
const EXTRA_WIDTH_PADDING := 28

func _ready() -> void:
	# Prevent clipping/truncation for longer names
	name_label.clip_text = false
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	if GameController:
		if not GameController.current_player_changed.is_connected(_on_current_player_changed):
			GameController.current_player_changed.connect(_on_current_player_changed)
		
		# Initial update if game already started
		var current = GameController.get_current_player()
		if current:
			_on_current_player_changed(current)
		elif GameState and GameState.players.size() > 0:
			name_label.text = GameState.get_player_display_name(GameState.current_player_index)
			var idx := clampi(GameState.current_player_index, 0, GameState.players.size() - 1)
			color_indicator.color = GameState.players[idx].player_color
			_resize_to_fit_name()


func _on_current_player_changed(player) -> void:
	if player == null:
		return

	# Name
	if "player_name" in player:
		name_label.text = player.player_name

	# Use the actual chosen color from PlayerState
	if "player_color" in player:
		color_indicator.color = player.player_color
	else:
		# Fallback only (should rarely happen)
		if "player_id" in player:
			var color_idx := int(player.player_id) % GameState.PLAYER_COLORS.size()
			color_indicator.color = GameState.PLAYER_COLORS[color_idx]

	_resize_to_fit_name()


func _resize_to_fit_name() -> void:
	# Wait one frame so the label finishes updating
	await get_tree().process_frame

	var font := name_label.get_theme_font("font")
	if font == null:
		return

	var font_size := name_label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		name_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	).x

	var target_width := clampi(int(text_width) + EXTRA_WIDTH_PADDING, MIN_PANEL_WIDTH, MAX_PANEL_WIDTH)

	# Resize the outer panel; container children will flow inside it
	panel.custom_minimum_size.x = target_width
