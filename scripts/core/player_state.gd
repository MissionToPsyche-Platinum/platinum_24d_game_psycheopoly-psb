extends Node

class_name PlayerState

# Player identification
var player_id: int = 0
var player_name: String = "Player"

# Board position (0-39)
var board_space: int = 0

# Money
var balance: int = 0

# Turn state
var has_rolled: bool = false
var doubles_count: int = 0