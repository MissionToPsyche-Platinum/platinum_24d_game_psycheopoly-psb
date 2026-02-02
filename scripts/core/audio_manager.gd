extends Node
class_name AudioManager

# -------------------------
# Bus names 
# -------------------------
const BUS_MASTER := "Master"
const BUS_MUSIC  := "Music"
const BUS_SFX    := "SFX"
const BUS_UI     := "UI"


const SETTINGS_PATH := "user://audio_settings.cfg"

# -------------------------
# Players (one-shots)
# -------------------------
var _ui_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer

# Cooldown to prevent click spam (tweak to taste)
var _ui_cooldown := 0.04
var _ui_last_time := -999.0

func _ready() -> void:
	# Create players
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UIPlayer"
	_ui_player.bus = BUS_UI
	add_child(_ui_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	_sfx_player.bus = BUS_SFX
	add_child(_sfx_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	_music_player.autoplay = false
	add_child(_music_player)

	_load_settings() # safe even if file doesn't exist


# ==========================================================
#  Play Sounds
# ==========================================================
func play_ui(stream: AudioStream, pitch := 1.0, volume_db := 0.0) -> void:
	if stream == null:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _ui_last_time < _ui_cooldown:
		return
	_ui_last_time = now

	_ui_player.stop()
	_ui_player.stream = stream
	_ui_player.pitch_scale = pitch
	_ui_player.volume_db = volume_db
	_ui_player.play()

func play_sfx(stream: AudioStream, pitch := 1.0, volume_db := 0.0) -> void:
	if stream == null:
		return
	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.pitch_scale = pitch
	_sfx_player.volume_db = volume_db
	_sfx_player.play()

func play_music(stream: AudioStream, volume_db := 0.0, fade_in := 0.0) -> void:
	if stream == null:
		return

	_music_player.stream = stream
	_music_player.volume_db = volume_db

	if fade_in > 0.0:
		_music_player.volume_db = -60.0
		_music_player.play()
		var t := create_tween()
		t.tween_property(_music_player, "volume_db", volume_db, fade_in)
	else:
		_music_player.play()

func stop_music(fade_out := 0.0) -> void:
	if fade_out > 0.0 and _music_player.playing:
		var t := create_tween()
		t.tween_property(_music_player, "volume_db", -60.0, fade_out)
		t.finished.connect(func(): _music_player.stop())
	else:
		_music_player.stop()


# ==========================================================
# Public API — Volume Controls (0.0 to 1.0)
# ==========================================================
func set_master_volume(linear: float) -> void:
	_set_bus_volume_linear(BUS_MASTER, linear)
	_save_settings()

func set_sfx_volume(linear: float) -> void:
	_set_bus_volume_linear(BUS_SFX, linear)
	_save_settings()

func set_ui_volume(linear: float) -> void:
	_set_bus_volume_linear(BUS_UI, linear)
	_save_settings()

func set_music_volume(linear: float) -> void:
	_set_bus_volume_linear(BUS_MUSIC, linear)
	_save_settings()

func get_master_volume() -> float:
	return _get_bus_volume_linear(BUS_MASTER)

func get_sfx_volume() -> float:
	return _get_bus_volume_linear(BUS_SFX)

func get_ui_volume() -> float:
	return _get_bus_volume_linear(BUS_UI)

func get_music_volume() -> float:
	return _get_bus_volume_linear(BUS_MUSIC)


# ==========================================================
#  Bus helpers
# ==========================================================
func _set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("AudioManager: Bus not found: " + bus_name)
		return

	linear = clampf(linear, 0.0, 1.0)

	# Convert 0..1 to dB (Godot uses dB)
	# 0 -> -60db (effectively silent), 1 -> 0db
	var db := lerpf(-60.0, 0.0, linear)
	AudioServer.set_bus_volume_db(idx, db)

	# Optional: mute when at 0
	AudioServer.set_bus_mute(idx, linear <= 0.001)

func _get_bus_volume_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0

	if AudioServer.is_bus_mute(idx):
		return 0.0

	var db := AudioServer.get_bus_volume_db(idx)
	# Map -60..0 back to 0..1
	return inverse_lerp(-60.0, 0.0, db)


# ==========================================================
# Settings persistence
# ==========================================================
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", get_master_volume())
	cfg.set_value("audio", "sfx", get_sfx_volume())
	cfg.set_value("audio", "ui", get_ui_volume())
	cfg.set_value("audio", "music", get_music_volume())
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		# Defaults (feel free to tweak)
		set_master_volume(1.0)
		set_sfx_volume(0.9)
		set_ui_volume(0.9)
		set_music_volume(0.7)
		return

	set_master_volume(float(cfg.get_value("audio", "master", 1.0)))
	set_sfx_volume(float(cfg.get_value("audio", "sfx", 0.9)))
	set_ui_volume(float(cfg.get_value("audio", "ui", 0.9)))
	set_music_volume(float(cfg.get_value("audio", "music", 0.7)))
