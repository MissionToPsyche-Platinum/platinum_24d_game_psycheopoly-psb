extends CanvasLayer

const ChanceCardData = preload("res://scripts/core/chance_card_data.gd")
const ChanceCardManager	= preload("res://scripts/core/chance_card_manager.gd")

#Reference for Card Information
@onready var card_type: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/CardType
@onready var card_description: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/CardInfoContainer/CardDescription
@onready var card_effect: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/CardEffectContainer/Effect
@onready var card_effect_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/CardEffectContainer/EffectValue

#close button
@onready var close_button: Button = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ButtonContainer/CloseButton

# Current card being displayed
var current_card: int = 0
var money_value: int = 0
var movement_value: int = -1
var card_info

#space that the player landed on
var space_number: int = -1

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
	if space_number in [7, 22, 36]:
		current_card = randi_range(0, 17)
	else:
		current_card = randi_range(18, 35)
		while current_card == 35 and not ChanceCardMgr.go_for_launch2_available:
			current_card = randi_range(18, 35)
		while current_card == 34 and not ChanceCardMgr.go_for_launch1_available:
			current_card = randi_range(18, 35)
		
	
	card_info = ChanceCardData.get_card_info(current_card)
	
	if card_info.is_empty():
		push_warning("Invalid card number: ", current_card)
		return
		
	# Set Card type
	match card_info.type:
		"Metal":
			card_type.text = "METAL CARD"
			if current_card == 14:
				var pay_opponents = (GameState.player_count - 1) * 50
				card_effect_value.text = str(pay_opponents)
			elif current_card == 15:
				var earn_from_opponents = (GameState.player_count - 1) * 10
				card_effect_value.text = str(earn_from_opponents)
			elif current_card == 16:
				var upgrades_fee = 9999 		##NEED TO UPDATE, PROPERTY BUILDING FEE
				card_effect_value.text = str(upgrades_fee)
			elif current_card == 17:	
				var upgrades_fee = 9999 		##NEED TO UPDATE, PROPERTY BUILDING FEE
				card_effect_value.text = str(upgrades_fee)
			else:
				card_effect_value.text = str(card_info.value)
		"Silicate":
			card_type.text = "SILICATE CARD"
			card_effect_value.text = card_info.value

	
	card_description.text = card_info.description
	card_effect.text = card_info.effect
	
	# Show the popup and bring to front
	visible = true
	
	money_value = card_info.functionalValue
	movement_value = card_info.movementValue
	
	
	
func _on_close_pressed() -> void:
	ChanceCardMgr.resolve_card(current_card,money_value,movement_value,space_number)
	
	visible = false
