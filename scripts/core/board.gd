extends Node2D

# Reference to the piece
var piece: Node2D = null


func _ready() -> void:
	# Load and spawn the piece
	var piece_scene = preload("res://scenes/Piece.tscn")
	piece = piece_scene.instantiate()
	add_child(piece)

	# Start the piece at position (10, 0) on the board (space 0 - GO)
	piece.move_to(10, 0)
