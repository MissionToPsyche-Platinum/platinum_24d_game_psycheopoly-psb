extends Control
class_name EndGamePopup

signal replay_current_requested
signal stats_requested
signal reconfigure_requested
signal exit_requested

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MessageLabel

@onready var replay_current_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ReplayCurrentBtn
@onready var stats_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatsBtn
@onready var reconfigure_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ReconfigureBtn
@onready var exit_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ExitBtn

func _ready() -> void:
	replay_current_btn.pressed.connect(_on_replay_current_btn_pressed)
	stats_btn.pressed.connect(_on_stats_btn_pressed)
	reconfigure_btn.pressed.connect(_on_reconfigure_btn_pressed)
	exit_btn.pressed.connect(_on_exit_btn_pressed)

	hide_popup()

func show_end_game(winner_name: String, summary_text: String = "Congratulations! The game is over.") -> void:
	title_label.text = "%s Wins!" % winner_name
	message_label.text = summary_text
	show()

func hide_popup() -> void:
	hide()

func _on_replay_current_btn_pressed() -> void:
	replay_current_requested.emit()

func _on_stats_btn_pressed() -> void:
	stats_requested.emit()

func _on_reconfigure_btn_pressed() -> void:
	reconfigure_requested.emit()

func _on_exit_btn_pressed() -> void:
	exit_requested.emit()
