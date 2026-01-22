extends Node
class_name GameSpace

var _space_name: String
var _space_description: String
var _color: Color

func _init(data: Dictionary = {}) -> void:
	if not data.is_empty():
		_space_name = data.get("name", "")
		_space_description = data.get("description", "")
		_color = data.get("color", Color.BLACK)

func get_space_info():
	pass
