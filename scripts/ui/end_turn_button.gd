extends Control

## End Turn Button UI
## Centered button that allows players to end their turn after rolling

@onready var ui_container: Control = $CenterContainer
@onready var end_turn_button: Button = $CenterContainer/Panel/MarginContainer/EndTurnButton

func _ready() -> void:
	# Connect button signal
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Connect to GameState turn signals
	if GameController:
		GameController.turn_started.connect(_on_turn_started)
		GameController.action_completed.connect(_on_action_completed)
	
	# Initialize button state (hidden at start)
	if ui_container:
		ui_container.visible = false
	if end_turn_button:
		end_turn_button.disabled = true


func _on_end_turn_pressed() -> void:
	## Called when player presses End Turn button
	var current_player = GameController.get_current_player()
	if not current_player:
		return
	
	if not current_player.has_rolled:
		print("You must roll the dice before ending your turn!")
		return
	
	# End the turn
	GameController.next_player()

func _on_turn_started(_player_index: int) -> void:
	## Called when a new turn starts
	if ui_container:
		ui_container.visible = true
	if end_turn_button:
		end_turn_button.disabled = true


func _on_action_completed() -> void:
	## Called when player completes an action - show button
	var current_player = GameController.get_current_player()
	if not current_player:
		return
	
	if end_turn_button:
		end_turn_button.disabled = not current_player.has_rolled
