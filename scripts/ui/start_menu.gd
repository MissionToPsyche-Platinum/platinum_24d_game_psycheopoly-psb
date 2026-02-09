extends Control

# ============================
#   NODE REFERENCES
# ============================

@onready var start_btn: Button        = $CenterBox/Menu/Start
@onready var settings_btn: Button     = $CenterBox/Menu/Settings
@onready var exit_btn: Button         = $CenterBox/Menu/Exit

# Main menu container (so we can hide/show when SettingsMenu is open)
@onready var main_menu: Control       = $CenterBox/Menu

@onready var settings_menu: Control   = $SettingsMenu

# ============================
#   WEB AUDIO UNLOCK OVERLAY
# ============================
var _audio_overlay: Button = null
var _audio_unlocked: bool = false

# Desired menu music volume (match what you want once unlocked)
const MENU_MUSIC_DB := 12.0
const MENU_FADE_IN := 0.25

# ============================
#   READY
# ============================

func _ready() -> void:
	_connect_signals()

	# Ensure settings menu starts hidden
	if settings_menu:
		settings_menu.hide()

	# Start music attempt (browser may block until user gesture)
	# We still call it; worst case it won't be audible yet.
	AudioManager.play_music("menu", MENU_MUSIC_DB, 0.0)

	# Web builds: require a user gesture to allow audio
	if OS.has_feature("web"):
		_create_audio_unlock_overlay()



# ============================
#   SIGNAL WIRING
# ============================

func _connect_signals() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

	# Listen for SettingsMenu "closed" signal (SettingsMenu.gd must have: signal closed)
	if settings_menu and settings_menu.has_signal("closed"):
		settings_menu.closed.connect(_on_settings_closed)


# ===================================
#   OVERLAY FOR START MENU / HANDLERS
# ===================================

func _create_audio_unlock_overlay() -> void:
	# Don’t create twice
	if _audio_overlay != null:
		return

	# Create a full-screen button overlay (captures the first click)
	_audio_overlay = Button.new()
	_audio_overlay.name = "AudioUnlockOverlay"
	_audio_overlay.text = "Click to Start"
	_audio_overlay.focus_mode = Control.FOCUS_ALL

	# Make it fill the whole screen
	_audio_overlay.anchor_left = 0.0
	_audio_overlay.anchor_top = 0.0
	_audio_overlay.anchor_right = 1.0
	_audio_overlay.anchor_bottom = 1.0
	_audio_overlay.offset_left = 0
	_audio_overlay.offset_top = 0
	_audio_overlay.offset_right = 0
	_audio_overlay.offset_bottom = 0

	# Put it on top of everything
	_audio_overlay.z_index = 9999

	# Optional: make it look like an overlay
	_audio_overlay.add_theme_color_override("font_color", Color(1, 1, 1))
	_audio_overlay.add_theme_font_size_override("font_size", 32)

	
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.65)

	_audio_overlay.add_theme_stylebox_override("normal", bg)
	_audio_overlay.add_theme_stylebox_override("hover", bg)
	_audio_overlay.add_theme_stylebox_override("pressed", bg)

	add_child(_audio_overlay)

	# When clicked: unlock audio and remove overlay
	_audio_overlay.pressed.connect(_on_audio_overlay_pressed)

	# Helpful on web: ensure it’s ready for immediate click
	_audio_overlay.grab_focus()


func _on_audio_overlay_pressed() -> void:
	if _audio_unlocked:
		return
	_audio_unlocked = true

	# Play a tiny UI sound (this user gesture usually "unlocks" audio)
	AudioManager.play_ui("click")

	# Ensure menu music is playing and fade it in to target volume
	AudioManager.play_music("menu", MENU_MUSIC_DB, 0.0)

	# Fade in (requires AudioManager.fade_music_to; if you don't have it, we do a simple tween here)
	# We'll tween the player volume by calling duck/unduck is messy, so do a local fade by replaying with fade:
	AudioManager.play_music("menu", MENU_MUSIC_DB, MENU_FADE_IN)

	# Remove overlay
	if _audio_overlay:
		_audio_overlay.queue_free()
		_audio_overlay = null


# ============================
#   SIGNAL CALLBACKS
# ============================

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameSetupScreen.tscn")


func _on_settings_pressed() -> void:
	# Hide the start menu buttons and show the settings overlay
	if main_menu:
		main_menu.hide()

	if settings_menu:
		settings_menu.show()
		settings_menu.grab_focus()


func _on_settings_closed() -> void:
	# SettingsMenu already hides itself on close, but safe to ensure it hides:
	if settings_menu:
		settings_menu.hide()

	if main_menu:
		main_menu.show()


func _on_exit_pressed() -> void:
	get_tree().quit()
