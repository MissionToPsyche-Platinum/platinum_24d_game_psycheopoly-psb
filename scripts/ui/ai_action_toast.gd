extends Control

@onready var toast_label = $PanelContainer/MarginContainer/ToastLabel
@onready var dismiss_timer = $DismissTimer

var tween: Tween

func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	hide()

func show_toast(message: String) -> void:
	"""Show the toast with the given message and auto-dismiss after 2 seconds."""
	toast_label.text = message
	show()

	# Fade in
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_callback(dismiss_timer.start)

func _on_dismiss_timer_timeout() -> void:
	# Fade out and hide
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(hide)
