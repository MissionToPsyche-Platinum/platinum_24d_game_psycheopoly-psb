extends CanvasLayer

const ChanceCardData = preload("res://scripts/core/chance_card_data.gd")

# Reference for Card Information
@onready var color_bar: ColorRect = $Control/PanelContainer/MarginContainer/VBoxContainer/ColorBar
@onready var card_type: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/ColorBar/CardType
@onready var card_description: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/CardDescription
@onready var card_effect: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/CardEffectContainer/Effect
@onready var card_effect_value: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/CardEffectContainer/EffectValue

# close button
@onready var close_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/CloseButton

# Current card being displayed
var current_card: int = 0
var money_value: int = 0
var movement_value: int = -1
var card_info

# space that the player landed on
var space_number: int = -1

# lock the player who actually drew this card
var acting_player_index: int = -1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ensure the popup stays fixed on screen (HUD mode)
	follow_viewport_enabled = false
	
	# Connect button signals
	close_button.pressed.connect(_on_close_pressed)
	
	# Start hidden
	visible = false


## Show the popup with information about a randomly selected Chance card.
## `space_num` is the board/space number that triggered this popup and is used
## to decide which range of Chance cards to draw from.
func show_card_details(space_num: int) -> void:
	space_number = space_num
	acting_player_index = GameState.current_player_index
	var current_player = acting_player_index
	current_card = ChanceCardMgr.draw_card(space_number)
		
	card_info = ChanceCardData.get_card_info(current_card)
	
	if card_info.is_empty():
		push_warning("Invalid card number: ", current_card)
		return
		
	# Set Card type
	match card_info.type:
		"Metal":
			card_type.text = "METAL CARD"
			color_bar.color = Color.LIGHT_BLUE
			if current_card == 14:
				var pay_opponents = (GameState.player_count - 1) * 50
				card_effect_value.text = str(pay_opponents)
			elif current_card == 15:
				var earn_from_opponents = (GameState.player_count - 1) * 10
				card_effect_value.text = str(earn_from_opponents)
			elif current_card == 16:
				var total_data_points = GameState.players[current_player].total_data_points
				var total_discoveries = GameState.players[current_player].total_discoveries
				var upgrades_fee = (total_data_points * 45) + (total_discoveries * 120)
				card_effect_value.text = str(upgrades_fee)
			elif current_card == 17:
				var total_data_points = GameState.players[current_player].total_data_points
				var total_discoveries = GameState.players[current_player].total_discoveries
				var upgrades_fee = (total_data_points * 25) + (total_discoveries * 100)
				card_effect_value.text = str(upgrades_fee)
			else:
				card_effect_value.text = str(card_info.value)

		"Silicate":
			card_type.text = "SILICATE CARD"
			color_bar.color = Color.ORANGE
			card_effect_value.text = str(card_info.value)

	card_description.text = card_info.description
	card_effect.text = card_info.effect
	
	# Show the popup and bring to front
	visible = true
	
	money_value = card_info.functionalValue
	movement_value = card_info.movementValue
	
	# If the player is AI, immediately resolve the card using the stored player context
	if GameState.players[current_player].player_is_ai == true:
		_on_close_pressed()


func _on_close_pressed() -> void:
	var is_jail_card := current_card in [32, 33]

	# Lock card resolution to the player/space that actually triggered the popup
	ChanceCardMgr.set_pending_card_context(acting_player_index, space_number)
	ChanceCardMgr.resolve_card(current_card, money_value, movement_value, space_number)

	if current_card in range(0, 18):
		ChanceCardMgr.discard_metal_card(current_card)
	elif current_card in range(18, 36):
		ChanceCardMgr.discard_silicate_card(current_card)

	visible = false

	# Clear local context after resolution
	acting_player_index = -1
	space_number = -1

	# For jail cards, board.gd shows the notification then emits action_completed
	if not is_jail_card:
		GameController.action_completed.emit()
