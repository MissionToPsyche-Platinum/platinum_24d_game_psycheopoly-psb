extends Control

@onready var start_btn: Button = $CenterBox/Menu/Start
@onready var settings_btn: Button = $CenterBox/Menu/Settings
@onready var credits_btn: Button = $CenterBox/Menu/Credits
@onready var exit_btn: Button = $CenterBox/Menu/Exit
@onready var main_menu: Control = $CenterBox

const SettingsMenuScene = preload("res://scenes/SettingsMenu.tscn")

const CreditsMenuScene = preload("res://scenes/CreditsMenu.tscn")

var settings_menu: Control = null

var credits_menu: Control = null

var _audio_overlay: Button = null
var _audio_unlocked: bool = false

const MENU_MUSIC_DB := 12.0
const MENU_FADE_IN := 0.25


func _ready() -> void:
	_connect_signals()

	# Build SettingsMenu after the tree is stable
	call_deferred("_setup_settings_menu")
	
	call_deferred("_setup_credits_menu")

	# Start menu music
	AudioManager.play_music("menu", MENU_MUSIC_DB, 0.0)

	# Web builds may require a user interaction before audio can fully start
	if OS.has_feature("web"):
		_create_audio_unlock_overlay()


func _connect_signals() -> void:
	if not start_btn.pressed.is_connected(_on_start_pressed):
		start_btn.pressed.connect(_on_start_pressed)

	if not settings_btn.pressed.is_connected(_on_settings_pressed):
		settings_btn.pressed.connect(_on_settings_pressed)

	if not exit_btn.pressed.is_connected(_on_exit_pressed):
		exit_btn.pressed.connect(_on_exit_pressed)
		
	if not credits_btn.pressed.is_connected(_on_credits_pressed):
		credits_btn.pressed.connect(_on_credits_pressed)


func _setup_settings_menu() -> void:
	# Prevent duplicates
	if settings_menu and is_instance_valid(settings_menu):
		return

	settings_menu = SettingsMenuScene.instantiate()
	settings_menu.name = "SettingsMenu"

	# Add directly under StartMenu so Control layout behaves correctly
	add_child(settings_menu)

	# Let SettingsMenu finish _ready()
	await get_tree().process_frame

	if settings_menu and is_instance_valid(settings_menu):
		settings_menu.hide()

		if settings_menu.has_signal("closed") and not settings_menu.closed.is_connected(_on_settings_closed):
			settings_menu.closed.connect(_on_settings_closed)

	print("StartMenu: SettingsMenu created =", settings_menu != null)


func _create_audio_unlock_overlay() -> void:
	if _audio_overlay != null:
		return

	_audio_overlay = Button.new()
	_audio_overlay.name = "AudioUnlockOverlay"
	_audio_overlay.text = "Click to Start"
	_audio_overlay.focus_mode = Control.FOCUS_ALL

	# Full-screen overlay
	_audio_overlay.anchor_left = 0.0
	_audio_overlay.anchor_top = 0.0
	_audio_overlay.anchor_right = 1.0
	_audio_overlay.anchor_bottom = 1.0
	_audio_overlay.offset_left = 0
	_audio_overlay.offset_top = 0
	_audio_overlay.offset_right = 0
	_audio_overlay.offset_bottom = 0

	_audio_overlay.z_index = 9999
	_audio_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	_audio_overlay.add_theme_color_override("font_color", Color(1, 1, 1))
	_audio_overlay.add_theme_font_size_override("font_size", 32)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.65)

	_audio_overlay.add_theme_stylebox_override("normal", bg)
	_audio_overlay.add_theme_stylebox_override("hover", bg)
	_audio_overlay.add_theme_stylebox_override("pressed", bg)

	add_child(_audio_overlay)

	if not _audio_overlay.pressed.is_connected(_on_audio_overlay_pressed):
		_audio_overlay.pressed.connect(_on_audio_overlay_pressed)

	_audio_overlay.grab_focus()


func _on_audio_overlay_pressed() -> void:
	if _audio_unlocked:
		return

	_audio_unlocked = true

	AudioManager.play_ui("click")

	# Some browsers need a user interaction before audio is fully allowed
	AudioManager.play_music("menu", MENU_MUSIC_DB, 0.0)
	AudioManager.play_music("menu", MENU_MUSIC_DB, MENU_FADE_IN)

	if _audio_overlay and is_instance_valid(_audio_overlay):
		_audio_overlay.queue_free()
		_audio_overlay = null


func _on_start_pressed() -> void:
	_cleanup_start_menu_ui()
	get_tree().change_scene_to_file("res://scenes/GameSetupScreen.tscn")


func _on_settings_pressed() -> void:
	print("StartMenu: Settings button pressed")

	# If web overlay is still up, remove it so it can't block the settings menu
	if _audio_overlay and is_instance_valid(_audio_overlay):
		_audio_overlay.queue_free()
		_audio_overlay = null

	# Rebuild if missing for any reason
	if settings_menu == null or not is_instance_valid(settings_menu):
		print("StartMenu: SettingsMenu missing, rebuilding...")
		await _setup_settings_menu()

	if settings_menu and is_instance_valid(settings_menu):
		print("StartMenu: Opening SettingsMenu...")
		print("Before open visible =", settings_menu.visible)

		if settings_menu.has_method("open"):
			settings_menu.call("open", false)
		else:
			settings_menu.show()
			settings_menu.move_to_front()

		print("After open visible =", settings_menu.visible)
	else:
		print("StartMenu ERROR: SettingsMenu still invalid")


func _on_settings_closed() -> void:
	print("StartMenu: Settings closed")

	if settings_menu and is_instance_valid(settings_menu):
		settings_menu.hide()

	if settings_btn:
		settings_btn.grab_focus()


func _on_exit_pressed() -> void:
	_cleanup_start_menu_ui()
	get_tree().quit()


func _exit_tree() -> void:
	_cleanup_start_menu_ui()


func _cleanup_start_menu_ui() -> void:
	if _audio_overlay and is_instance_valid(_audio_overlay):
		_audio_overlay.queue_free()
		_audio_overlay = null

	if settings_menu and is_instance_valid(settings_menu):
		settings_menu.queue_free()

	if credits_menu and is_instance_valid(credits_menu):
		credits_menu.queue_free()

	settings_menu = null
	credits_menu = null

func _setup_credits_menu() -> void:
	# Prevent duplicates
	if credits_menu and is_instance_valid(credits_menu):
		return

	credits_menu = CreditsMenuScene.instantiate()
	credits_menu.name = "CreditsMenu"

	add_child(credits_menu)

	# Let CreditsMenu finish _ready()
	await get_tree().process_frame

	if credits_menu and is_instance_valid(credits_menu):
		credits_menu.hide()

		if credits_menu.has_signal("closed") and not credits_menu.closed.is_connected(_on_credits_closed):
			credits_menu.closed.connect(_on_credits_closed)

	print("StartMenu: CreditsMenu created =", credits_menu != null)
	

func _on_credits_pressed() -> void:
	print("StartMenu: Credits button pressed")

	# If web overlay is still up, remove it so it can't block the credits menu
	if _audio_overlay and is_instance_valid(_audio_overlay):
		_audio_overlay.queue_free()
		_audio_overlay = null

	# Rebuild if missing for any reason
	if credits_menu == null or not is_instance_valid(credits_menu):
		print("StartMenu: CreditsMenu missing, rebuilding...")
		await _setup_credits_menu()

	if credits_menu and is_instance_valid(credits_menu):
		print("StartMenu: Opening CreditsMenu...")
		print("Before open visible =", credits_menu.visible)

		if credits_menu.has_method("open"):
			credits_menu.call("open")
		else:
			credits_menu.show()
			credits_menu.move_to_front()

		print("After open visible =", credits_menu.visible)
	else:
		print("StartMenu ERROR: CreditsMenu still invalid")


func _on_credits_closed() -> void:
	print("StartMenu: Credits closed")

	if credits_menu and is_instance_valid(credits_menu):
		credits_menu.hide()

	if credits_btn:
		credits_btn.grab_focus()
