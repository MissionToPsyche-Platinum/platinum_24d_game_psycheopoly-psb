extends Control

## End Turn Button UI
## Centered button that allows human players to end their turn after rolling

@onready var ui_container: Control = $CenterContainer
@onready var glow_panel: Panel = $CenterContainer/Panel
@onready var end_turn_button: Button = $CenterContainer/Panel/MarginContainer/EndTurnButton

var pulse_tween: Tween = null
var panel_stylebox: StyleBoxFlat = null

const BORDER_DIM := Color("2a5f99")
const BORDER_BRIGHT := Color("5aaaf5")


func _ready() -> void:
	# Connect button signal
	if end_turn_button and not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)

	# Connect to GameController signals
	if GameController:
		if not GameController.turn_started.is_connected(_on_turn_started):
			GameController.turn_started.connect(_on_turn_started)
		if not GameController.action_completed.is_connected(_on_action_completed):
			GameController.action_completed.connect(_on_action_completed)

	_setup_glow_panel_style()

	# Keep UI state synced even during movement / landing resolution
	set_process(true)

	# Initialize button state safely
	_stop_pulse()
	_apply_button_state(false)


func _process(_delta: float) -> void:
	_update_button_state()


func _setup_glow_panel_style() -> void:
	if not glow_panel:
		return

	var base_style := glow_panel.get_theme_stylebox("panel")
	if base_style is StyleBoxFlat:
		panel_stylebox = (base_style as StyleBoxFlat).duplicate()
	else:
		panel_stylebox = StyleBoxFlat.new()
		panel_stylebox.bg_color = Color(0.08, 0.08, 0.08, 0.92)
		panel_stylebox.corner_radius_top_left = 12
		panel_stylebox.corner_radius_top_right = 12
		panel_stylebox.corner_radius_bottom_left = 12
		panel_stylebox.corner_radius_bottom_right = 12
		panel_stylebox.border_width_left = 3
		panel_stylebox.border_width_top = 3
		panel_stylebox.border_width_right = 3
		panel_stylebox.border_width_bottom = 3

	panel_stylebox.border_color = BORDER_DIM
	glow_panel.add_theme_stylebox_override("panel", panel_stylebox)


func _on_end_turn_pressed() -> void:
	var current_player = GameController.get_current_player()
	if not current_player:
		return

	# Never allow ending turn during an AI turn
	if current_player.player_is_ai:
		return

	# Never allow ending turn while the board is still resolving movement / landing / card flow
	if _is_board_busy_resolving_turn():
		return

	# Only allow after the player has rolled
	if not current_player.has_rolled:
		print("You must roll the dice before ending your turn!")
		return

	GameController.end_turn()


func _on_turn_started(_player_index: int) -> void:
	_update_button_state()


func _on_action_completed() -> void:
	_update_button_state()


func _update_button_state() -> void:
	var current_player = GameController.get_current_player()
	var should_show := false

	if current_player \
	and not current_player.player_is_ai \
	and current_player.has_rolled \
	and not _is_board_busy_resolving_turn():
		should_show = true

	_apply_button_state(should_show)


func _apply_button_state(should_show: bool) -> void:
	if ui_container:
		ui_container.visible = should_show

	if end_turn_button:
		end_turn_button.disabled = not should_show

	if should_show:
		_start_pulse()
	else:
		_stop_pulse()


func _is_board_busy_resolving_turn() -> bool:
	var board = get_tree().current_scene
	if board == null:
		return false

	if "pending_landing_resolution" in board and bool(board.pending_landing_resolution):
		return true

	if "pending_card_followup_movement" in board and bool(board.pending_card_followup_movement):
		return true

	return false


func _start_pulse() -> void:
	if not panel_stylebox:
		return

	# Prevent duplicate looping tweens
	if pulse_tween and pulse_tween.is_valid():
		return

	panel_stylebox.border_color = BORDER_DIM

	pulse_tween = create_tween()
	pulse_tween.set_loops()

	pulse_tween.tween_method(_set_border_color, BORDER_DIM, BORDER_BRIGHT, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	pulse_tween.tween_method(_set_border_color, BORDER_BRIGHT, BORDER_DIM, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	pulse_tween = null

	if panel_stylebox:
		panel_stylebox.border_color = BORDER_DIM


func _set_border_color(color: Color) -> void:
	if panel_stylebox:
		panel_stylebox.border_color = color
