extends Sprite2D
# THis sctipt is meant to move the asteroid across the screen on random off-screen-to-off-screen "legs"
# with gentle bobbing, tumbling rotation, subtle scaling, and fade-in/out.
#This is very similar to the probe script with minor adjustments.

# ---------------------------
# Flight settings (asteroid = slower + heavier)
# ---------------------------
@export var margin: float = 160.0
# How far off-screen (padding) the asteroid spawns/ends.
# Bigger margin = it starts farther outside the viewport.

@export var travel_time_min: float = 10.0
@export var travel_time_max: float = 18.0
# Each "leg" lasts a random duration between these values.
# Asteroids are slower than the probe, so the times are larger.

# Quality rules (recommended)
@export var min_leg_distance: float = 700.0
# Prevents short legs where the asteroid barely moves (avoids tiny hops).

@export var max_vertical_ratio: float = 0.90
# Guard for legs that are too vertical (dy/dx).
# 0.90 allows more steep angles than the probe (probe had a tighter value).

@export var fade_in_time: float = 0.75
@export var fade_out_time: float = 0.75
# Time spent fading in at the start and fading out near the end of each leg.

@export var base_alpha: float = 0.55
# Normal transparency while visible.
# Lower alpha keeps background asteroids subtle so they don’t distract gameplay.

# ---------------------------
# Asteroid motion 
# ---------------------------
@export var float_amplitude: float = 2.5
# Small bob amplitude (in pixels). Subtle movement for a “drifting rock” feel.

@export var float_speed: float = 0.18
# Bob frequency in cycles/sec. Lower = slower bob.

# Rotates more than probe (rocks tumbling)
@export var spin_degrees_per_sec_min: float = -18.0
@export var spin_degrees_per_sec_max: float = 18.0
# Random spin speed range (degrees per second).
# Negative values mean clockwise vs counterclockwise depending on Godot’s rotation direction.

# Tiny scale pulse 
@export var scale_pulse: float = 0.004
# Small scale pulse amount (very subtle, can be adjusted).

@export var scale_speed: float = 0.10
# How fast the scale pulse oscillates (cycles/sec).

# Random size variation per asteroid instance
@export var random_scale_min: float = 0.55
@export var random_scale_max: float = 1.15
# Random size multiplier applied once when the asteroid spawns.
# Creates variation: some rocks are smaller, some are bigger.

var start_pos: Vector2
# Start position of the current travel leg (usually off-screen).

var end_pos: Vector2
# End position of the current travel leg (usually off-screen on a different side).

var base_pos: Vector2
# The “main path” position without bob/sway offsets.

var t_leg: float = 0.0
# Elapsed time within the current leg.

var travel_time: float = 12.0
# Actual chosen duration for the current leg (randomized per leg).

var clock: float = 0.0
# General timer used to drive sin/cos micro-motion.

var base_scale: Vector2
# Stores the asteroid’s base scale so scale pulses can be applied relative to it.

var spin_rads_per_sec: float = 0.0
# Spin speed stored in radians/sec (Godot rotation is in radians).

func _ready() -> void:
	# Runs once when the node enters the scene tree.

	randomize()
	# Seeds global random generator so each run produces different motion.

	# Randomize initial look per asteroid instance
	spin_rads_per_sec = deg_to_rad(randf_range(spin_degrees_per_sec_min, spin_degrees_per_sec_max))
	# Pick a random spin speed in degrees/sec and convert to radians/sec.

	rotation = randf_range(0.0, TAU)
	# Random initial rotation so not every asteroid starts at the same angle.
	# TAU = 2*PI (full circle in radians).

	var s = randf_range(random_scale_min, random_scale_max)
	# Choose a random scale multiplier for this asteroid instance.

	scale *= s
	# Apply that multiplier to the sprite’s current scale.

	base_scale = scale
	# Save the resulting base scale (so pulse uses this as the baseline).

	modulate.a = 0.0
	# Start fully transparent; fade logic will bring it in.

	_pick_new_leg(true)
	# Pick the first travel leg.
	# true = jump to start position immediately and start visible at base_alpha.

func _process(delta: float) -> void:
	# Called every frame. delta = seconds since last frame.

	clock += delta
	# Advance general animation clock.

	t_leg += delta
	# Advance time along the current travel leg.

	# progress along this leg (0..1)
	var p := clampf(t_leg / travel_time, 0.0, 1.0)
	# Convert elapsed time into normalized progress from 0 to 1.
	# clampf prevents overshoot.

	# smoothstep for nicer easing
	p = p * p * (3.0 - 2.0 * p)
	# Smoothstep easing (starts slow, speeds up, ends slow).

	# base travel
	base_pos = start_pos.lerp(end_pos, p)
	# Interpolate from start_pos to end_pos using progress p.

	
	var bob := sin(clock * TAU * float_speed) * float_amplitude
	# Vertical bob using a sine wave.

	var sway := cos(clock * TAU * (float_speed * 0.9)) * (float_amplitude * 0.35)
	# Horizontal sway using cosine wave, slightly different speed and smaller amplitude.

	position = base_pos + Vector2(sway, bob)
	# Final position combines the main travel path + micro sway/bob offsets.

	# tumble spin
	rotation += spin_rads_per_sec * delta
	# Apply continuous rotation each frame based on spin speed and frame time.

	# subtle scale pulse
	var sp := 1.0 + sin(clock * TAU * scale_speed) * scale_pulse
	# Compute scale multiplier around 1.0 (tiny pulse).

	scale = base_scale * sp
	# Apply pulse relative to base_scale (preserves the random size chosen in _ready).

	# fade in/out near endpoints
	_apply_fade(p)
	# Adjust alpha based on how close we are to the start/end of the leg.

	# when leg ends, pick a new one
	if t_leg >= travel_time:
		# If the leg finished...
		_pick_new_leg(false)
		# ...choose another leg.
		# false = don’t force instant alpha; fade-in/out will happen normally.

func _apply_fade(p: float) -> void:
	# Adjusts transparency based on leg progress p (0..1).

	var a := base_alpha
	# Start from normal alpha.

	# fade in
	var in_p = fade_in_time / max(travel_time, 0.001)
	# Convert fade-in duration (seconds) into a fraction of the leg.
	# max prevents divide-by-zero if travel_time is ever 0.

	if p < in_p:
		# If within the fade-in region near the start...
		a *= clampf(p / in_p, 0.0, 1.0)
		# Scale alpha up from 0 to base_alpha.

	# fade out
	var out_p = fade_out_time / max(travel_time, 0.001)
	# Convert fade-out duration into a fraction of the leg.

	if p > 1.0 - out_p:
		# If within the fade-out region near the end...
		a *= clampf((1.0 - p) / out_p, 0.0, 1.0)
		# Scale alpha down toward 0 as p approaches 1.0.

	modulate.a = a
	# Apply final alpha to the sprite.

func _pick_new_leg(immediate: bool) -> void:
	# Chooses a new start/end off-screen path and resets timers.

	travel_time = randf_range(travel_time_min, travel_time_max)
	# Randomize how long this new leg will take.

	var rect := get_viewport_rect()
	# Get the viewport rectangle (screen size in pixels).

	var w := rect.size.x
	var h := rect.size.y
	# Store screen width/height for convenience.

	# Try a bunch of times until we get a "good" leg
	for attempt in range(50):
		# Attempt up to 50 times to find a leg that meets the quality rules.

		var a := _random_offscreen_point(w, h)
		# Random off-screen start point.

		var b := _random_offscreen_point(w, h)
		# Random off-screen end point.

		var d := b - a
		# Vector from a to b.

		var dist := d.length()
		# Distance between a and b.

		# too short?
		if dist < min_leg_distance:
			# Skip if the path is too short.
			continue

		# too vertical? (optional)
		var dx := absf(d.x)
		var dy := absf(d.y)
		# Absolute horizontal/vertical differences.

		if dx < 1.0:
			# Avoid division by zero and near-vertical legs.
			continue

		if (dy / dx) > max_vertical_ratio:
			# Skip if slope is too steep (too vertical).
			continue

		# found a good leg
		start_pos = a
		# Store start position.

		end_pos = b
		# Store end position.

		break
		# Exit the loop once a valid leg is found.

	# reset timer
	t_leg = 0.0
	# Reset leg timer so progress starts at 0.

	# If we want it to appear immediately at the start
	if immediate:
		# Used for the first leg (or any time you want instant start).
		position = start_pos
		# Jump directly to the start position.

		modulate.a = base_alpha
		# Make it visible immediately at normal alpha (skips fade-in).

func _random_offscreen_point(w: float, h: float) -> Vector2:
	# Returns a random point outside the viewport on one of 4 sides.

	# pick a random side: 0=left, 1=right, 2=top, 3=bottom
	var side := randi() % 4
	# randi() gives an integer; % 4 constrains it to 0..3.

	match side:
		0: # left
			return Vector2(-margin, randf_range(-margin, h + margin))
			# X is left of screen; Y is random (includes extra margin above/below).
		1: # right
			return Vector2(w + margin, randf_range(-margin, h + margin))
			# X is right of screen; Y random.
		2: # top
			return Vector2(randf_range(-margin, w + margin), -margin)
			# Y is above screen; X random.
		3: # bottom
			return Vector2(randf_range(-margin, w + margin), h + margin)
			# Y is below screen; X random.

	return Vector2(-margin, randf_range(-margin, h + margin))
	# Fallback return (should rarely happen).
