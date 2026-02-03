extends Control

## PlayerNameHUD.gd
## Displays the current player's name and chosen color in the top left corner

@onready var name_label: Label = $Panel/MarginContainer/HBox/NameLabel
@onready var color_indicator: ColorRect = $Panel/MarginContainer/HBox/ColorIndicator

func _ready() -> void:
	if GameController:
		if not GameController.current_player_changed.is_connected(_on_current_player_changed):
			GameController.current_player_changed.connect(_on_current_player_changed)
		
		# Initial update if game already started
		var current = GameController.get_current_player()
		if current:
			_on_current_player_changed(current)

func _on_current_player_changed(player) -> void:
	if player == null:
		return

	# Name
	if "player_name" in player:
		name_label.text = player.player_name

	# Use the actual chosen color from PlayerState
	if "player_color" in player:
		color_indicator.color = player.player_color
	else:
		# Fallback only (should rarely happen)
		if "player_id" in player:
			var color_idx := int(player.player_id) % GameState.PLAYER_COLORS.size()
			color_indicator.color = GameState.PLAYER_COLORS[color_idx]
