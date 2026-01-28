extends Control

## PlayerNameHUD.gd
## Displays the current player's name in the top left corner

@onready var name_label: Label = $Panel/MarginContainer/NameLabel

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
