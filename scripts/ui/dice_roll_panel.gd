extends Control

# ---------------------------
# Signals
# ---------------------------
signal dice_rolled(die1: int, die2: int, total: int, is_doubles: bool)

# ---------------------------
# Visuals (dice faces)
# ---------------------------
@export var dice_faces: Array[Texture2D] = []
# Exposed in the Inspector so we can drag in 6 dice face textures.

# ---------------------------
# Timing for the roll animation
# ---------------------------
@export var roll_duration: float = 0.75
# Total time the dice "roll animation" runs before it lands on the final values.

@export var tick_interval_start: float = 0.06
# How fast the dice faces change at the beginning of the roll (small = faster ticks).

@export var tick_interval_end: float = 0.12
# How fast the dice faces change near the end of the roll (bigger = slower ticks).

# If true, both dice change every tick (this would make things more chaotic looking).
# If false, dice alternate changes (this can make things look smoother).
@export var change_both_each_tick: bool = true
# Controls the “feel” of the roll animation:
# - true: both dice update every tick (more movement)

# ---------------------------
# Pop animation (landing feel)
# ---------------------------
@export var pop_scale: float = 1.08
# How much to scale up the dice when they land (1.15 = 15% bigger). We can adjust this setting freely to see what we like

@export var pop_time: float = 0.08
# How long each half of the pop takes (up then back down).

# ---------------------------
# Sound polish
# ---------------------------
# Minimum seconds between roll tick SFX plays (prevents spamming the same sound repeatedly).
@export var roll_sfx_min_gap: float = 0.10
# If ticks happen faster than this, we skip some roll sounds so audio doesn't spam.

# Delay after setting final faces / updating TOTAL before result sound plays.
@export var result_sfx_delay: float = 0.08
# Small delay so the "result" sound doesn't clash with the final visual update.

# slight pitch variety on result sound (subtle) so the sounds doesn't sound the exact smae all the time
@export var result_pitch_min: float = 0.96
@export var result_pitch_max: float = 1.08


@export var die1_path: NodePath
@export var die2_path: NodePath
@export var roll_button_path: NodePath
@export var total_label_path: NodePath
# These are NodePaths we set in the Inspector so the script can find the UI nodes.

@onready var die1: TextureRect = get_node(die1_path) as TextureRect
# When the node is ready, fetch the node at die1_path and cast it to TextureRect.

@onready var die2: TextureRect = get_node(die2_path) as TextureRect
# Same idea for die2.

@onready var roll_button: Button = get_node(roll_button_path) as Button
# Grabs the roll button node and casts it to Button.

@onready var total_label: Label = get_node(total_label_path) as Label


var rng := RandomNumberGenerator.new()
# Godot RNG object used for dice values (more controllable than built-in randi()).

var is_rolling := false
# Lock flag so the player can't start a second roll while one is already running.

var _alternate := false
# Used only when change_both_each_tick is false.
# Toggles which die changes each tick (die1 then die2 then die1...).

var _last_roll_sfx_time := -999.0
# Stores the last time a roll tick sound was played (in seconds).
# Set this to basically max negative val so first tick can always be played.

var _roll_text_idle := "Roll Dice"
# Default "idle" button text.

var _roll_text_rolling := "Rolling..."
# Button text while rolling.

func _ready() -> void:
	# Called once when the node enters the scene tree and is fully initialized.

	rng.randomize()
	# Seeds the RNG so results are different each run (otherwise may repeat).

	# Set initial faces (show "1" by default)
	if dice_faces.size() >= 1 and die1 and die2:
		# Only run if at least one face exists, and both dice nodes are valid.
		die1.texture = dice_faces[0]
		# Set die1 image to face "1" (index 0).
		die2.texture = dice_faces[0]
		# Set die2 image to face "1" as well.

	total_label.text = "TOTAL: --"
	# Initialize label to show no roll has happened yet.


	if roll_button and roll_button.text != "":
		# If the button exists and already has text in the scene…
		_roll_text_idle = roll_button.text
		# …store it so we can restore it after rolling.

	roll_button.pressed.connect(_on_roll_pressed)
	# Connect the button press signal to our handler function.
	
	# Connect to GameState turn signals
	if GameState:
		GameState.turn_started.connect(_on_turn_started)
		# Update button states when turn changes
	
	# Initialize button states for first player
	_update_button_states()


func _on_roll_pressed() -> void:
	AudioManager.play_ui("click")
	# Runs when the Roll button is clicked/pressed.
	roll_dice()
	# Calls the main roll function.

func roll_dice() -> void:
	# Main roll routine: animates dice, plays sounds, and updates TOTAL.

	if is_rolling:
		# If we're already rolling, ignore this call.
		return

	if dice_faces.size() < 6:
		# If we don't have all 6 faces, we can't safely display results.
		push_warning("dice_faces needs 6 textures (1..6).")
		# Show a warning in Godot output.
		return

	is_rolling = true
	# Lock input so you can’t trigger another roll during this roll.
	
	# Lower game bg music while dice is rolling.
	AudioManager.duck_music(-20.0, 0.12)


	roll_button.disabled = true
	# Disables the button in UI so user can’t click it again.

	roll_button.text = _roll_text_rolling
	# Updates button text to show it’s rolling.

	# Pick final values
	var final1 := rng.randi_range(1, 6)
	# Random integer 1..6 for die1 final result.

	var final2 := rng.randi_range(1, 6)
	# Random integer 1..6 for die2 final result.

	var total := final1 + final2
	# Total of both dice.

	# Start-of-roll sound (one "shake")
	_play_roll_sfx(true)
	# Plays the roll tick sound immediately 

	var elapsed := 0.0
	# Tracks how long the roll has been running.

	var tick := tick_interval_start
	# Current time between ticks. Starts fast.

	# Rolling loop
	while elapsed < roll_duration:
		# Keep updating faces until we hit roll_duration seconds.

		if change_both_each_tick:
			# Update BOTH dice every tick.
			_set_die_faces(rng.randi_range(1, 6), rng.randi_range(1, 6))
			# Random face for die1 and die2 (not the final values yet).
		else:
			# Alternate which die changes (can look smoother)
			_alternate = !_alternate
			# Flip the boolean each tick.

			if _alternate:
				# If true this tick: change die1, keep die2 the same.
				_set_die_faces(rng.randi_range(1, 6), _current_face_value(die2))
			else:
				# Otherwise: keep die1 the same, change die2.
				_set_die_faces(_current_face_value(die1), rng.randi_range(1, 6))

		# Tick sound
		_play_roll_sfx(false)
		# Plays tick sound if enough time has passed since last tick sound.

		var t: float = elapsed / max(roll_duration, 0.001)
		# Normalized progress (0.0 -> 1.0) through the roll.
		# max(..., 0.001) prevents divide-by-zero if roll_duration is ever 0.

		tick = lerp(tick_interval_start, tick_interval_end, t)
		# Smoothly increases tick interval over time:
		# early roll = fast ticks, late roll = slower ticks.

		await get_tree().create_timer(tick).timeout
		# Wait for "tick" seconds before next loop iteration.

		elapsed += tick
		# Advance elapsed time by how long we just waited.

	# Final faces + UI
	_set_die_faces(final1, final2)
	# Set the dice textures to the actual final RNG results.

	total_label.text = "TOTAL: %d" % total
	# Update label with final total. %d inserts the integer total.

	# Pop animation (landing feel)
	await _pop(die1)
	# Run pop tween on die1 and wait until it finishes.

	await _pop(die2)
	# Run pop tween on die2 and wait until it finishes.

	# Result sound AFTER a tiny delay (to avoid clash with visual lag)
	if result_sfx_delay > 0.0:
		# Only delay if the delay value is positive.
		await get_tree().create_timer(result_sfx_delay).timeout
		# Wait a short moment before playing the result sound.

	_play_result_sfx()
	# Play the final result sound (with optional pitch variance).

	# Return game bg music to normal AFTER the roll finishes.
	AudioManager.unduck_music(0.18)


	# Notify listeners (like GameBoard) that the roll is finished
	dice_rolled.emit(final1, final2, total, final1 == final2)

	is_rolling = false
	# Unlock rolling state.

	roll_button.text = _roll_text_idle
	# Restore the original button label.
	
	# Update button states based on turn rules
	_update_button_states()

func _set_die_faces(v1: int, v2: int) -> void:
	# Helper: sets die textures based on numeric values 1..6.
	die1.texture = dice_faces[v1 - 1]
	# v1 is 1..6, but arrays are 0..5, so subtract 1.

	die2.texture = dice_faces[v2 - 1]
	# Same for die2.

func _pop(node: Control) -> void:
	# Helper: creates a quick "pop" tween (scale up then back down).
	# Used to make the dice landing feel satisfying and appealing to player

	var base := node.scale
	# Store current scale so we can return to it afterward.

	var up := base * pop_scale
	# Compute scaled-up target size.

	var tw := create_tween()
	# Create a Tween object managed by this node.

	tw.tween_property(node, "scale", up, pop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Tween: scale up to "up" over pop_time using a smooth sine curve, that eases out

	tw.tween_property(node, "scale", base, pop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Tween: scale back down to base over pop_time, which eases in.

	await tw.finished
	# Wait for tween to fully finish before returning.

func _play_roll_sfx(force: bool) -> void:
	# Plays the rolling tick sound, but throttles it to avoid spam.

	var now := Time.get_ticks_msec() / 1000.0
	# Current time in seconds (ticks_msec gives milliseconds since engine start).

	if not force and (now - _last_roll_sfx_time) < roll_sfx_min_gap:
		# If we are NOT forcing playback and the last sound was too recent, skip.
		return

	_last_roll_sfx_time = now
	# Update last-played timestamp.

	# Slight boost so dice cuts through background music
	AudioManager.play_sfx("dice_tick", 1.0, +4.5)

func _play_result_sfx() -> void:
	# Plays the final result sound, optionally with slight pitch randomness.

	var pitch := rng.randf_range(result_pitch_min, result_pitch_max)
	# randf_range returns a float between min/max.

	# Slight boost so result cuts through background music
	AudioManager.play_sfx("dice_result", pitch, +5.5) #

#  figure out current die value from its current texture.
# If it can't find it, returns 1.
func _current_face_value(die: TextureRect) -> int:
	# Used only when change_both_each_tick is false (alternate mode),
	# so we can “keep” one die’s current face while changing the other.

	if die == null or die.texture == null:
		# If die node is missing or has no texture, assume 1.
		return 1

	for i in range(min(dice_faces.size(), 6)):
		# Loop through up to 6 textures we have loaded (or less if array is smaller).
		if dice_faces[i] == die.texture:
			# If the current die texture matches one of our face textures...
			return i + 1
			# ...return that face value (array index 0->value 1, etc.)

	return 1
	# If no match found, default to 1.


func _on_turn_started(player_index: int) -> void:
	## Called when a new turn starts
	print("DicePanel: Turn started for player ", player_index)
	_update_button_states()


func _update_button_states() -> void:
	## Update button enabled/disabled states based on turn state
	var current_player = GameState.get_current_player()
	if not current_player:
		return
	
	# Roll button: enabled if player hasn't rolled yet (and not currently rolling)
	if roll_button:
		roll_button.disabled = current_player.has_rolled or is_rolling
