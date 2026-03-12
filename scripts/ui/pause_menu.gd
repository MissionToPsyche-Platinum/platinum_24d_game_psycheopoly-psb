extends Control

signal settings_requested
signal quit_requested

var _is_paused: bool = false:
	set = set_paused

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause") and visible:
		set_paused(false)
		get_viewport().set_input_as_handled()

func set_paused(value: bool) -> void:
	_is_paused = value
	get_tree().paused = _is_paused
	visible = _is_paused

func _on_resume_btn_pressed() -> void:
	set_paused(false)

func _on_settings_btn_pressed() -> void:
	settings_requested.emit()

func _on_quit_btn_pressed() -> void:
	quit_requested.emit()
