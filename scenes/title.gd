extends Label

@export var amplitude := 2.0   # pixels (2–3 is ideal)
@export var period := 1.6      # seconds per cycle (1.6–2.2 feels premium)

var base_y := 0.0

func _ready() -> void:
	var t := create_tween().set_loops()
	base_y = position.y
	
	if label_settings == null:
		push_warning("Title Label is missing LabelSettings (shadow pulse will be skipped).")
		return
		
	t.tween_property(self, "modulate:a", 0.55, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "modulate:a", 1.00, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Shadow pulse
	t.tween_property(self.label_settings, "shadow_color:a", 0.35, 1.5)
	t.tween_property(self.label_settings, "shadow_color:a", 0.55, 1.5)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	position.y = base_y + sin((t * TAU) / period) * amplitude
	
																																																																																																																																																																																																																																																																																																																																																																																																																												
