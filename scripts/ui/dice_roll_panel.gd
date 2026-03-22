extends Control

# ---------------------------
# Signals
# ---------------------------
signal dice_rolled(die1: int, die2: int, total: int, is_doubles: bool)
signal doubles_rolled()

# ---------------------------
# Visuals (dice faces)
# ---------------------------
@export var dice_faces: Array[Texture2D] = []

# ---------------------------
# Timing for the roll animation
# ---------------------------
@export var roll_duration: float = 0.75
@export var tick_interval_start: float = 0.06
@export var tick_interval_end: float = 0.12
@export var change_both_each_tick: bool = true

# ---------------------------
# Pop animation (landing feel)
# ---------------------------
@export var pop_scale: float = 1.08
@export var pop_time: float = 0.08

# ---------------------------
# Sound polish
# ---------------------------
@export var roll_sfx_min_gap: float = 0.10
@export var result_sfx_delay: float = 0.08
@export var result_pitch_min: float = 0.96
@export var result_pitch_max: float = 1.08

@export var die1_path: NodePath
@export var die2_path: NodePath
@export var roll_button_path: NodePath
@export var total_label_path: NodePath

@onready var die1: TextureRect = get_node(die1_path) as TextureRect
@onready var die2: TextureRect = get_node(die2_path) as TextureRect
@onready var roll_button: Button = get_node(roll_button_path) as Button
@onready var total_label: Label = get_node(total_label_path) as Label

var rng := RandomNumberGenerator.new()
var is_rolling := false
var _alternate := false
var _last_roll_sfx_time := -999.0
var _roll_text_idle := "Roll Dice"
var _roll_text_rolling := "Rolling..."


func _ready() -> void:
	rng.randomize()

	if dice_faces.size() >= 1 and die1 and die2:
		die1.texture = dice_faces[0]
		die2.texture = dice_faces[0]

	if total_label:
		total_label.text = "TOTAL: --"

	if roll_button and roll_button.text != "":
		_roll_text_idle = roll_button.text

	roll_button.pressed.connect(_on_roll_pressed)
	AiManager.ai_dice_roll.connect(roll_dice)

	if GameController:
		if not GameController.turn_started.is_connected(_on_turn_started):
			GameController.turn_started.connect(_on_turn_started)

		if not GameController.action_completed.is_connected(_on_action_completed):
			GameController.action_completed.connect(_on_action_completed)

		if not GameController.current_player_changed.is_connected(_on_current_player_changed):
			GameController.current_player_changed.connect(_on_current_player_changed)

	_update_button_states()


func _on_roll_pressed() -> void:
	AudioManager.play_ui("click")
	roll_dice()


func roll_dice() -> void:
	if is_rolling:
		return

	if dice_faces.size() < 6:
		push_warning("dice_faces needs 6 textures (1..6).")
		return

	is_rolling = true

	AudioManager.duck_music(-20.0, 0.12)

	if roll_button:
		roll_button.disabled = true
		roll_button.text = _roll_text_rolling

	var final1 := rng.randi_range(1, 6)
	var final2 := rng.randi_range(1, 6)
	var total := final1 + final2

	_play_roll_sfx(true)

	var elapsed := 0.0
	var tick := tick_interval_start

	while elapsed < roll_duration:
		if change_both_each_tick:
			_set_die_faces(rng.randi_range(1, 6), rng.randi_range(1, 6))
		else:
			_alternate = !_alternate
			if _alternate:
				_set_die_faces(rng.randi_range(1, 6), _current_face_value(die2))
			else:
				_set_die_faces(_current_face_value(die1), rng.randi_range(1, 6))

		_play_roll_sfx(false)

		var t: float = elapsed / max(roll_duration, 0.001)
		tick = lerp(tick_interval_start, tick_interval_end, t)

		await get_tree().create_timer(tick).timeout
		elapsed += tick

	_set_die_faces(final1, final2)

	var is_doubles := (final1 == final2)

	# Keep TOTAL clean (no doubles text here)
	if total_label:
		total_label.text = "TOTAL: %d" % total

	await _pop(die1)
	await _pop(die2)

	if result_sfx_delay > 0.0:
		await get_tree().create_timer(result_sfx_delay).timeout

	_play_result_sfx()
	AudioManager.unduck_music(0.18)

	# Notify listeners (like Board) that the roll is finished
	dice_rolled.emit(final1, final2, total, is_doubles)

	# NEW: notify Board that doubles happened so it can show a popup toast
	if is_doubles:
		doubles_rolled.emit()

	is_rolling = false

	if roll_button:
		roll_button.text = _roll_text_idle

	_update_button_states()


func _set_die_faces(v1: int, v2: int) -> void:
	die1.texture = dice_faces[v1 - 1]
	die2.texture = dice_faces[v2 - 1]


func _pop(node: Control) -> void:
	var base := node.scale
	var up := base * pop_scale

	var tw := create_tween()
	tw.tween_property(node, "scale", up, pop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, pop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tw.finished


func _play_roll_sfx(force: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	if not force and (now - _last_roll_sfx_time) < roll_sfx_min_gap:
		return

	_last_roll_sfx_time = now
	AudioManager.play_sfx("dice_tick", -3.0, +0.5)


func _play_result_sfx() -> void:
	var pitch := rng.randf_range(result_pitch_min, result_pitch_max)
	AudioManager.play_sfx("dice_result", pitch, +1.0)


func _current_face_value(die: TextureRect) -> int:
	if die == null or die.texture == null:
		return 1

	for i in range(min(dice_faces.size(), 6)):
		if dice_faces[i] == die.texture:
			return i + 1

	return 1


func _on_turn_started(player_index: int) -> void:
	print("DicePanel: Turn started for player ", player_index)
	_update_button_states()


func _on_action_completed() -> void:
	_update_button_states()


func _on_current_player_changed(_player) -> void:
	_update_button_states()


func _update_button_states() -> void:
	var current_player = GameController.get_current_player()
	if not current_player:
		return

	if roll_button:
		roll_button.disabled = current_player.has_rolled or is_rolling or current_player.player_is_ai
