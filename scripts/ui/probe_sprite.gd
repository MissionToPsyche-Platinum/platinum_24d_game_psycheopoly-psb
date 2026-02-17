extends Sprite2D

# ---------------------------
# Flight settings
# ---------------------------
@export var margin: float = 140.0
# How far OFF SCREEN (padding) we allow the sprite to start/end.
# Bigger margin = it spawns further outside the viewport before flying in.

@export var travel_time_min: float = 5.0
@export var travel_time_max: float = 8.0
# Random range for how long each travel "leg" takes (in seconds).
# Each time it chooses a new leg, it picks a time between these.

#quality rules 
@export var min_leg_distance: float = 650.0
# Prevents legs that are too short (sprite barely moves).

@export var max_vertical_ratio: float = 0.75
# Prevents legs that are "too vertical".
# This uses dy/dx: if dy is much larger than dx, it feels like straight up/down.

@export var fade_in_time: float = 0.55
@export var fade_out_time: float = 0.55
# How long (in seconds) the fade in/out takes near the ends of each leg.

@export var base_alpha: float = 0.85
# The normal alpha (transparency) level while flying (1.0 = fully opaque).

# ---------------------------
# the wobble(sort of bobbing) motion
# ---------------------------
@export var float_amplitude: float = 7.0
# Vertical bob amplitude in pixels (how far up/down it floats).

@export var float_speed: float = 0.35
# Bob frequency in cycles per second (higher = faster bobbing).

@export var rot_degrees: float = 2.0
# Maximum rotation angle (in degrees) during the subtle sway.

@export var rot_speed: float = 0.20
# Rotation oscillation speed in cycles per second.

@export var scale_pulse: float = 0.015
# How much the sprite scales up/down slightly.

@export var scale_speed: float = 0.18
# Scale pulse speed in cycles per second.

# ---------------------------
# Sound
# ---------------------------
@export var whoosh_enabled: bool = true
# Master toggle for whether the whoosh sound will play when it enters the screen.

@export var whoosh_cooldown_time: float = 1.0
# Cooldown to prevent the sound triggering too often (audio spam protection).

@export var whoosh_pitch_min: float = 0.95
@export var whoosh_pitch_max: float = 1.05
# Small random pitch range so repeated whooshes don't sound identical.

@export var whoosh_volume_db: float = -18.0
# Default volume for the whoosh sound (decibels; more negative = quieter).

# ---------------------------
# Internals
# ---------------------------
var start_pos: Vector2
# Where this travel leg starts (usually off-screen).

var end_pos: Vector2
# Where this travel leg ends (usually off-screen on another side).

var base_pos: Vector2
# The "main path" position without micro-motion (bob/sway).

var t_leg: float = 0.0
# Time elapsed within the current travel leg.

var travel_time: float = 6.0
# Actual chosen travel time for the current leg (randomized per leg).

var clock: float = 0.0
# A general timer used to drive sin/cos animations (bob/rotation/scale pulse).

var base_scale: Vector2
# The sprite’s original scale (so we can pulse relative to it).

# Sound internals
@onready var whoosh: AudioStreamPlayer2D = get_node_or_null("ProbeWhoosh") as AudioStreamPlayer2D
# Gets a child node named "ProbeWhoosh" and casts it as AudioStreamPlayer2D.


var whoosh_cooldown: float = 0.0
# Timer used to enforce cooldown between whoosh sounds.

var ignore_first_enter: bool = true
# Used to ignore the first screen_entered event 

func _ready() -> void:
	# Runs once when the node enters the scene tree.

	randomize()
	# Seeds the global random functions (randi/randf_range) so you don't get the same pattern each run.

	base_scale = scale
	# Store initial scale so we can restore/pulse from the original.

	modulate.a = 0.0
	# Set alpha to 0 (fully transparent) at start, then fade logic will bring it in.

	# Sound setup (safe even if disabled)
	if whoosh:
		# If the whoosh node exists...
		whoosh.volume_db = whoosh_volume_db
		# ...set its volume from the exported value.

	_pick_new_leg(true)
	# Choose the first flight leg immediately (true = start visible instantly at start_pos).

func _process(delta: float) -> void:
	# Called every frame. delta = seconds since last frame.

	clock += delta
	# Advance our general animation clock.

	t_leg += delta
	# Advance elapsed time on the current travel leg.

	# cooldown tick-down (prevents spamming audio)
	if whoosh_cooldown > 0.0:
		# If cooldown is active...
		whoosh_cooldown = maxf(0.0, whoosh_cooldown - delta)
		# ...reduce it by delta and clamp to 0.

	# progress along this leg (0..1)
	var p := clampf(t_leg / travel_time, 0.0, 1.0)
	# p is how far along the current leg we are:
	# 0.0 at start, 1.0 at end.
	# clampf prevents overshoot if t_leg exceeds travel_time.

	# smoothstep for nicer easing
	p = p * p * (3.0 - 2.0 * p)
	# This is a "smoothstep" easing curve.
	# It makes movement start slow, speed up, then slow down near the end.

	# base travel
	base_pos = start_pos.lerp(end_pos, p)
	# Linear interpolation from start_pos to end_pos using p.
	# This gives the main flight path position (without bobbing/sway).

	# bobbing-motion layered on top
	var bob := sin(clock * TAU * float_speed) * float_amplitude
	# Vertical bob: sin wave over time, scaled by amplitude.

	var sway := cos(clock * TAU * (float_speed * 0.9)) * (float_amplitude * 0.35)
	# Horizontal sway: cos wave, slightly different frequency and smaller amplitude.

	position = base_pos + Vector2(sway, bob)
	# Final sprite position = main path + small bob-motion offset.

	var rot := deg_to_rad(sin(clock * TAU * rot_speed) * rot_degrees)
	# Compute a small rotation angle (sin wave), convert degrees -> radians for Godot.

	rotation = rot
	# Apply rotation to the sprite.

	var sp := 1.0 + sin(clock * TAU * scale_speed) * scale_pulse
	# Compute a scale multiplier around 1.0 (ex: 1.015 then 0.985), based on sin wave.

	scale = base_scale * sp
	# Apply pulsing scale relative to the original scale.

	# fade in/out near endpoints (keeps it soft)
	_apply_fade(p)
	# Adjust alpha based on how close we are to start/end of the leg.

	# when leg ends, pick a new one
	if t_leg >= travel_time:
		# If this leg finished...
		_pick_new_leg(false)
		# ...choose a new start/end leg (false = do not force instant full alpha).

func _apply_fade(p: float) -> void:
	# Adjusts sprite transparency based on progress p (0..1).

	var a := base_alpha
	# Start from the normal alpha.

	# fade in
	var in_p = fade_in_time / max(travel_time, 0.001)
	# Convert fade_in_time (seconds) into a fraction of the leg (0..1).
	# max(...) avoids divide-by-zero if travel_time is 0.

	if p < in_p:
		# If we are in the fade-in region...
		a *= clampf(p / in_p, 0.0, 1.0)
		# Scale alpha from 0..base_alpha over that region.

	# fade out
	var out_p = fade_out_time / max(travel_time, 0.001)
	# Same conversion for fade_out_time.

	if p > 1.0 - out_p:
		# If we are in the fade-out region near the end...
		a *= clampf((1.0 - p) / out_p, 0.0, 1.0)
		# Scale alpha down toward 0 as we approach p=1.0.

	modulate.a = a
	# Apply computed alpha to the sprite’s modulate color.

func _pick_new_leg(immediate: bool) -> void:
	# Chooses a new off-screen start/end point pair and resets timers.

	travel_time = randf_range(travel_time_min, travel_time_max)
	# Pick a random travel time for this new leg.

	var rect := get_viewport_rect()
	# Get the current viewport rectangle (the visible screen area).

	var w := rect.size.x
	var h := rect.size.y
	# Store width/height for convenience.

	# Try a bunch of times until we get a "good" leg
	for attempt in range(40):
		# Attempt up to 40 random legs to find one that meets quality rules.

		var a := _random_offscreen_point(w, h)
		# Random start point off-screen.

		var b := _random_offscreen_point(w, h)
		# Random end point off-screen.

		var d := b - a
		# Vector from a to b.

		var dist := d.length()
		# Distance between points.

		# too short?
		if dist < min_leg_distance:
			# Skip if movement is too small.
			continue

		# too vertical? (avoid boring straight up/down travel)
		var dx := absf(d.x)
		var dy := absf(d.y)
		# Absolute horizontal/vertical deltas.

		if dx < 1.0:
			# Avoid division by ~0 and also avoid nearly-vertical legs.
			continue

		if (dy / dx) > max_vertical_ratio:
			# If slope is too steep, skip (too vertical).
			continue

		# found a good leg
		start_pos = a
		# Save the leg start.

		end_pos = b
		# Save the leg end.

		break
		# Exit loop once we have a good leg.

	# reset timer
	t_leg = 0.0
	# Reset leg time so p starts at 0.0 again.

	# If we want it to appear immediately at the start (first leg),
	# jump to start_pos and optionally skip the fade-in.
	if immediate:
		# On first leg we usually want it placed instantly.
		position = start_pos
		# Move sprite to the start position now.

		modulate.a = base_alpha
		# Make it visible immediately at base alpha (skips fade-in on first leg).

func _random_offscreen_point(w: float, h: float) -> Vector2:
	# Returns a random point off-screen on one of the 4 sides.

	# pick a random side: 0=left, 1=right, 2=top, 3=bottom
	var side := randi() % 4
	# randi() is a random integer; % 4 limits it to 0..3.

	match side:
		0: # left
			return Vector2(-margin, randf_range(-margin, h + margin))
			# X is left of the screen, Y is random (slightly beyond top/bottom too).
		1: # right
			return Vector2(w + margin, randf_range(-margin, h + margin))
			# X is right of screen, Y random.
		2: # top
			return Vector2(randf_range(-margin, w + margin), -margin)
			# Y is above the screen, X random.
		3: # bottom
			return Vector2(randf_range(-margin, w + margin), h + margin)
			# Y is below the screen, X random.

	return Vector2(-margin, randf_range(-margin, h + margin))
	# Fallback return (should almost never hit).

# Connected from VisibleOnScreenNotifier2D (OnScreen) -> screen_entered()
func _on_on_screen_screen_entered() -> void:
	# This should be connected to a VisibleOnScreenNotifier2D's "screen_entered" signal.
	# It fires when the sprite becomes visible on screen.

	if not whoosh_enabled:
		# If audio is disabled, do nothing.
		return

	if whoosh == null:
		# If the whoosh sound node doesn't exist, do nothing.
		return

	# If the probe starts already visible when the scene loads,
	# ignore that first "entered" event so it doesn't fire instantly.
	if ignore_first_enter:
		# First event after load is ignored.
		ignore_first_enter = false
		# Next entries will be allowed.
		return

	# Prevent machine-gun spam
	if whoosh_cooldown > 0.0:
		# If we're still within cooldown, skip playing the sound.
		return

	whoosh_cooldown = whoosh_cooldown_time
	# Start cooldown timer.

	# Slight pitch variation so repeated passes feel natural
	whoosh.pitch_scale = randf_range(whoosh_pitch_min, whoosh_pitch_max)
	# Randomize pitch slightly.

	whoosh.play()
	# Play the sound.
