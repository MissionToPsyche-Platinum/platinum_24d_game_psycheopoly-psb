extends GameSpace

class_name ExpenseSpace

var _expense_type: String 

func _init(
	space_name: String,
	space_description: String,
	expense_type: String,
	color: Color,

) -> void:
	_space_name = space_name
	_space_description = space_description
	_expense_type = expense_type
	_color = color
