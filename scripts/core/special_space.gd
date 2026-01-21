extends GameSpace

class_name SpecialSpace

var _space_type: String

func _init(data: Dictionary) -> void:
	super(data)
	_space_type = data.get("specialType", "")
