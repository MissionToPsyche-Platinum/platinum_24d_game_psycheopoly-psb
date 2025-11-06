extends Node



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var p1 = PlayerState.new()
	add_child(p1)
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
