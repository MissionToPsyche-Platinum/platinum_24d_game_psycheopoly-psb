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
#   READY
# ============================

func _ready() -> void:
	_connect_signals()
	

	# Ensure settings menu starts hidden
	if settings_menu:
		settings_menu.hide()

	AudioManager.play_music("menu", 12.0, 0.0)


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
