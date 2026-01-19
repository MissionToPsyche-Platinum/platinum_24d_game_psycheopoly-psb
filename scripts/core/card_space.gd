extends GameSpace

class_name CardSpace

var _card_type: String 

func _init(
	space_name: String,
	card_type: String,
) -> void:
	_space_name = space_name
	_card_type = card_type
