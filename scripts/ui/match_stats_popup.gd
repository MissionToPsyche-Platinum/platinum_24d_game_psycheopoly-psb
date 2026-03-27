extends Control
class_name MatchStatsPopup

signal back_requested

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var summary_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SummaryLabel
@onready var stats_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsLabel
@onready var back_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackBtn

func _ready() -> void:
	back_btn.pressed.connect(_on_back_btn_pressed)

	# Readability improvements
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	hide_popup()

func show_stats(summary_text: String, details_text: String) -> void:
	title_label.text = "Match Stats"
	summary_label.text = summary_text
	stats_label.text = details_text
	show()

func hide_popup() -> void:
	hide()

func _on_back_btn_pressed() -> void:
	back_requested.emit()
