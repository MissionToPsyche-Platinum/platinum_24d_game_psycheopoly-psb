extends Control
class_name MatchStatsPopup

signal back_requested

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var summary_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SummaryLabel
@onready var stats_scroll: ScrollContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsScroll
@onready var stats_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsScroll/StatsLabel
@onready var back_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackBtn

func _ready() -> void:
	back_btn.pressed.connect(_on_back_btn_pressed)

	# Readability improvements
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	hide_popup()

func show_stats(summary_text: String, details_text: String) -> void:
	title_label.text = "Match Stats"
	summary_label.text = summary_text
	stats_label.text = _format_details_text(details_text)

	show()

	# Reset scroll to top whenever popup opens
	await get_tree().process_frame
	if stats_scroll:
		stats_scroll.scroll_vertical = 0

func hide_popup() -> void:
	hide()

func _on_back_btn_pressed() -> void:
	back_requested.emit()

func _format_details_text(details_text: String) -> String:
	var lines := details_text.split("\n")
	var formatted: Array[String] = []

	for line in lines:
		if line.contains("Earnings:") and line.contains("Final Net Worth:"):
			var parts := line.split("Final Net Worth:")
			if parts.size() == 2:
				var left := parts[0].strip_edges()
				var right := "Final Net Worth:" + parts[1]
				formatted.append(left)
				formatted.append(right.strip_edges())
				continue

		if line.contains("Cash:") and line.contains("Properties Owned:"):
			var parts := line.split("Properties Owned:")
			if parts.size() == 2:
				var left := parts[0].strip_edges()
				var right := "Properties Owned:" + parts[1]
				formatted.append(left + "    " + right.strip_edges())
				continue

		formatted.append(line)

	return "\n".join(formatted)
