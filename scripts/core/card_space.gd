extends GameSpace

class_name CardSpace

var _card_type: String 

func _init(
	space_name: String,
	space_description: String,
	card_type: String,
	color: Color,
	
) -> void:
	_space_name = space_name
	_space_description = space_description
	_card_type = card_type
	_color = color
