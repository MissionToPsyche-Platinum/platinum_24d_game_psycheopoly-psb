extends Control

@onready var panel_container: PanelContainer = $PanelContainer
@onready var banner_label: Label = $PanelContainer/MarginContainer/BannerLabel
@onready var fade_timer: Timer = $FadeTimer

var tween: Tween

const MIN_BANNER_WIDTH := 180
const MAX_BANNER_WIDTH := 520
const EXTRA_WIDTH_PADDING := 36

func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	hide()

	# Prevent clipping for longer names
	banner_label.clip_text = false
	banner_label.autowrap_mode = TextServer.AUTOWRAP_OFF


func show_banner(player_name: String) -> void:
	banner_label.text = "%s is acting..." % player_name
	_resize_to_fit_text()
	show()

	# Fade in
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)


func hide_banner() -> void:
	# Hide the banner with fade out
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(hide)


func _on_fade_timer_timeout() -> void:
	hide_banner()


func _resize_to_fit_text() -> void:
	await get_tree().process_frame

	var font := banner_label.get_theme_font("font")
	if font == null:
		return

	var font_size := banner_label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		banner_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	).x

	var target_width := clampi(int(text_width) + EXTRA_WIDTH_PADDING, MIN_BANNER_WIDTH, MAX_BANNER_WIDTH)
	panel_container.custom_minimum_size.x = target_width
