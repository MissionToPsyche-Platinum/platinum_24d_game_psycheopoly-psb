extends GameSpace

class_name ExpenseSpace

var _expense_type: String

func _init(data: Dictionary) -> void:
	super(data)
	_expense_type = data.get("expenseType", "")
