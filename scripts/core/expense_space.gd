extends GameSpace

class_name ExpenseSpace

var _expense_type: String 

func _init(
	space_name: String,
	expense_type: String,
) -> void:
	_space_name = space_name
	_expense_type = expense_type
