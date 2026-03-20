extends Control
class_name NotificationPopup

signal dismissed

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var dismiss_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DismissBtn

func _ready() -> void:
	hide()

## Show a notification with a dismiss button the player must click.
## Emits `dismissed` when closed, so callers can `await popup.dismissed`.
func show_notification(title: String, message: String) -> void:
	title_label.text = title
	message_label.text = message
	show()

func _close() -> void:
	hide()
	dismissed.emit()

func _on_dismiss_btn_pressed() -> void:
	_close()
