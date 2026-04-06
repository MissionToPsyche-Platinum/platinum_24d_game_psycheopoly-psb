extends Control

signal quit_requested
signal how_to_play_requested

@onready var resume_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeBtn
@onready var settings_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SettingsBtn
@onready var quit_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitBtn
@onready var how_to_play_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HowToPlayBtn

const SettingsMenuScene = preload("res://scenes/SettingsMenu.tscn")

var settings_menu: Control = null

var _is_paused: bool = false:
	set = set_paused


func _ready() -> void:
	print("PauseMenu READY V2")
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

	_connect_signals()

	call_deferred("_setup_settings_menu")


func _connect_signals() -> void:
	print("PauseMenu: how_to_play_btn =", how_to_play_btn)

	if resume_btn and not resume_btn.pressed.is_connected(_on_resume_btn_pressed):
		resume_btn.pressed.connect(_on_resume_btn_pressed)

	if settings_btn and not settings_btn.pressed.is_connected(_on_settings_btn_pressed):
		settings_btn.pressed.connect(_on_settings_btn_pressed)

	if how_to_play_btn:
		print("PauseMenu: connecting How to Play button")
		if not how_to_play_btn.pressed.is_connected(_on_how_to_play_btn_pressed):
			how_to_play_btn.pressed.connect(_on_how_to_play_btn_pressed)

	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_btn_pressed):
		quit_btn.pressed.connect(_on_quit_btn_pressed)


func _setup_settings_menu() -> void:
	# Prevent duplicates
	if settings_menu and is_instance_valid(settings_menu):
		return

	settings_menu = SettingsMenuScene.instantiate()
	settings_menu.name = "SettingsMenu"

	var parent_node := get_parent()
	if parent_node:
		parent_node.add_child(settings_menu)
	else:

		add_child(settings_menu)

	settings_menu.z_index = self.z_index + 1

	await get_tree().process_frame

	if settings_menu and is_instance_valid(settings_menu):
		settings_menu.hide()

		if settings_menu.has_signal("closed") and not settings_menu.closed.is_connected(_on_settings_closed):
			settings_menu.closed.connect(_on_settings_closed)

	print("PauseMenu: SettingsMenu created =", settings_menu != null)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		# If settings is open, close settings and return to pause menu
		if settings_menu and is_instance_valid(settings_menu) and settings_menu.visible:
			settings_menu.close_menu()
			get_viewport().set_input_as_handled()
			return

		if visible:
			set_paused(false)
			get_viewport().set_input_as_handled()
			return


func set_paused(value: bool) -> void:
	_is_paused = value

	if _is_paused:
		get_tree().paused = true

		show()
		move_to_front()


		if settings_menu and is_instance_valid(settings_menu):
			settings_menu.hide()

		await get_tree().process_frame
		if resume_btn:
			resume_btn.grab_focus()
	else:
		if settings_menu and is_instance_valid(settings_menu):
			settings_menu.hide()

		hide()
		get_tree().paused = false


func show_menu_only() -> void:
	show()
	move_to_front()

	if resume_btn:
		resume_btn.grab_focus()


func hide_menu_only() -> void:
	hide()


func is_game_paused() -> bool:
	return _is_paused


func _on_resume_btn_pressed() -> void:
	set_paused(false)


func _on_settings_btn_pressed() -> void:
	print("PauseMenu: Settings button pressed")

	if settings_menu == null or not is_instance_valid(settings_menu):
		print("PauseMenu: SettingsMenu missing, rebuilding...")
		await _setup_settings_menu()

	hide_menu_only()

	if settings_menu and is_instance_valid(settings_menu):
		if settings_menu.has_method("open"):
			settings_menu.call("open", true)
		else:
			settings_menu.show()
			settings_menu.move_to_front()
	else:
		print("PauseMenu ERROR: SettingsMenu still invalid")


func _on_settings_closed() -> void:
	print("PauseMenu: Settings closed")

	if settings_menu and is_instance_valid(settings_menu):
		settings_menu.hide()

	# Return to pause menu if game is still paused
	if _is_paused:
		show_menu_only()


func _on_quit_btn_pressed() -> void:
	# Unpause first, then let GameBoard handle scene change
	set_paused(false)
	quit_requested.emit()


func _exit_tree() -> void:
	if settings_menu and is_instance_valid(settings_menu):
		settings_menu.queue_free()

	settings_menu = null

func _on_how_to_play_btn_pressed() -> void:
	print("PauseMenu: How to Play pressed")
	how_to_play_requested.emit()
