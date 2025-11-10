extends Node

var board: Array[GameSpace] = [] # contains all of the properties and game spaces on the board
var spaces_list := BoardSpaceList.new() # fetches all of the game spaces from the resource

# places all of the properties onto the board
func _setUpBoard() -> void:
	board.append(spaces_list.TESTPROPERTY1)
	board.append(spaces_list.TESTPROPERTY2)
	board.append(spaces_list.TESTPROPERTY3)

	pass



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#var p1 = PlayerState.new()
	#add_child(p1)
	
	_setUpBoard()
	print(board[0]._property_name) # temprary to test output of accessing an element on the board

	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
