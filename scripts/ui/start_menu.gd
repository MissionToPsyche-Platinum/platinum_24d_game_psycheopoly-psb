extends Control

# ============================
#   NODE REFERENCES
# ============================

@onready var start_btn: Button        = $CenterBox/Menu/Start
@onready var settings_btn: Button     = $CenterBox/Menu/Settings
@onready var exit_btn: Button         = $CenterBox/Menu/Exit

@onready var settings_popup: PopupPanel = $SettingsPopUp
@onready var diff_opt: OptionButton = $SettingsPopUp/Center/Box/DifficultyRow/DifficultyOption
@onready var close_btn: Button = $SettingsPopUp/Center/Box/Close


# ============================
#   READY
# ============================

func _ready() -> void:
	_initialize_difficulty()
	_connect_signals()


# ============================
#   INITIALIZE UI
# ============================

func _initialize_difficulty() -> void:
	# Default: Normal = index 1
	var index := 1

	match GameState.difficulty:
		"Easy":
			index = 0
		"Normal":
			index = 1
		"Hard":
			index = 2

	if diff_opt and diff_opt.item_count > index:
		diff_opt.select(index)


func _connect_signals() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	if diff_opt:
		diff_opt.item_selected.connect(_on_difficulty_selected)


# ============================
#   SIGNAL CALLBACKS
# ============================

func _on_start_pressed() -> void:
	# Change this to match your game scene path
	get_tree().change_scene_to_file("res://ui/main_test.tscn")


func _on_settings_pressed() -> void:
	settings_popup.popup_centered()


func _on_close_pressed() -> void:
	settings_popup.hide()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_difficulty_selected(index: int) -> void:
	var difficulty_text := diff_opt.get_item_text(index)
	GameState.set_difficulty(difficulty_text)
