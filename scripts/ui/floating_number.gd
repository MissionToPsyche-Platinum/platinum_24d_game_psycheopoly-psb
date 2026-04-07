extends Label

@export var rise_pixels: float = 18.0
@export var duration: float = 2.0
@export var start_scale: float = 1.0
@export var end_scale: float = 1.10
@export var color_ok: Color = Color("#39e26f")
@export var color_negative: Color = Color("#ff5555")

func play(value: int) -> void:
	text = ("+" + str(value)) if value > 0 else str(value)
	# Use red for negative, green for positive
	if value < 0:
		modulate = color_negative
	else:
		modulate = color_ok
	scale = Vector2.ONE * start_scale

	visible = true
	modulate.a = 1.0

	var start_pos := position
	var end_pos := start_pos + Vector2(0, -rise_pixels)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", end_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * end_scale, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.finished.connect(queue_free)
