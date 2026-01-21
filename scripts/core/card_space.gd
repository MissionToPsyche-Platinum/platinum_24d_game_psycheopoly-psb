extends GameSpace

class_name CardSpace

var _card_type: String 

func _init(data: Dictionary) -> void:
	super(data)
	_card_type = data.get("cardType", "")
