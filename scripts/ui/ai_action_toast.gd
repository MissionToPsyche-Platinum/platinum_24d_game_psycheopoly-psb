extends Control

signal toast_finished

@onready var toast_label = $PanelContainer/MarginContainer/ToastLabel
@onready var dismiss_timer = $DismissTimer

var tween: Tween
var _is_showing: bool = false

func _ready() -> void:
	modulate.a = 0.0
	hide()

func show_toast(message: String) -> void:
	toast_label.text = message
	show()
	_is_showing = true

	if tween:
		tween.kill()

	dismiss_timer.stop()
	modulate.a = 0.0

	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_callback(dismiss_timer.start)

func is_showing_toast() -> bool:
	return _is_showing

func wait_until_finished() -> void:
	if _is_showing:
		await toast_finished

func hide_toast_immediately() -> void:
	if tween:
		tween.kill()
	dismiss_timer.stop()
	hide()
	modulate.a = 0.0
	_is_showing = false
	toast_finished.emit()

func _on_dismiss_timer_timeout() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(hide)
	tween.tween_callback(_finish_toast)

func _finish_toast() -> void:
	_is_showing = false
	toast_finished.emit()
