extends Control

signal closed

@onready var close_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)

func open() -> void:
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _on_close_pressed() -> void:
	close()
