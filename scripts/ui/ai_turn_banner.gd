extends Control

@onready var banner_label = $PanelContainer/MarginContainer/BannerLabel
@onready var fade_timer = $FadeTimer

var tween: Tween

func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	hide()

func show_banner(player_name: String) -> void:
	"""Show the banner with the given player name."""
	banner_label.text = "%s [CPU] is acting..." % player_name
	show()

	# Fade in
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

func hide_banner() -> void:
	"""Hide the banner with fade out."""
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(hide)

func _on_fade_timer_timeout() -> void:
	hide_banner()
