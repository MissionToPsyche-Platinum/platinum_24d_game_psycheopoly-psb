extends GameSpace

class_name SpecialSpace

var _space_type: String 

func _init(
	space_name: String,
	space_description: String,
	space_type: String,
	color: Color,

) -> void:
	_space_name = space_name
	_space_description = space_description
	_space_type = space_type
	_color = color
