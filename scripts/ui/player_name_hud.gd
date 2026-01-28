extends Control

## PlayerNameHUD.gd
## Displays the current player's name and color in the top left corner

@onready var name_label: Label = $Panel/MarginContainer/HBox/NameLabel
@onready var color_indicator: ColorRect = $Panel/MarginContainer/HBox/ColorIndicator

# Reference to piece colors (using same array as piece.gd)
const PLAYER_COLORS: Array[Color] = [
	Color(0.9, 0.2, 0.2),   # Soft Red
	Color(0.2, 0.5, 0.9),   # Royal Blue
	Color(0.2, 0.8, 0.2),   # Forest Green
	Color(0.9, 0.8, 0.1),   # Golden Yellow
	Color(0.9, 0.5, 0.1),   # Burnt Orange
	Color(0.8, 0.3, 0.8),   # Plum Purple
]

func _ready() -> void:
	if GameState:
		GameState.current_player_changed.connect(_on_current_player_changed)
		
		# Initial update if game already started
		var current = GameState.get_current_player()
		if current:
			_on_current_player_changed(current)

func _on_current_player_changed(player: Object) -> void:
	if player and "player_name" in player:
		name_label.text = player.player_name
		
		# Update color indicator based on player_id
		if "player_id" in player:
			var color_idx = player.player_id % PLAYER_COLORS.size()
			color_indicator.color = PLAYER_COLORS[color_idx]
