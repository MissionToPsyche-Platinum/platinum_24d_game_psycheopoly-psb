extends CanvasLayer

const ChanceCardData = preload("res://scripts/core/chance_card_data.gd")

#Reference for Card Information
@onready var card_type: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/CardType
@onready var card_description: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/CardInfoContainer/CardDescription
@onready var card_effect: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/CardEffectContainer/Effect
@onready var card_effect_value: Label = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/CardEffectContainer/EffectValue

#close button
@onready var close_button: Button = $Control/CenterContainer/Panel/PanelContainer/VBoxContainer/ButtonContainer/CloseButton

# Current card being displayed
var current_card: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ensure the popup stays fixed on screen (HUD mode)
	follow_viewport_enabled = false
	
	# Connect button signals
	close_button.pressed.connect(_on_close_pressed)
	
	# Start hidden
	visible = false
	
## Show the popup with information about a randomly selected Chance card.
## `card_num` is the board/space number that triggered this popup and is used
## to decide which range of Chance cards to draw from.
func show_card_details(card_num: int) -> void:
	if card_num in [7, 22, 36]:
		current_card = randi_range(0, 17)
	else:
		current_card = randi_range(18, 35)
	
	var card_info = ChanceCardData.get_card_info(current_card)
	
	if card_info.is_empty():
		push_warning("Invalid card number: ", current_card)
		return
		
	# Set Card type
	match card_info.type:
		"Metal":
			card_type.text = "METAL CARD"
			card_effect_value.text = str(card_info.value)
		"Silicate":
			card_type.text = "SILICATE CARD"
			card_effect_value.text = card_info.value

	
	card_description.text = card_info.description
	card_effect.text = card_info.effect
	
	# Show the popup and bring to front
	visible = true
	
	
func _on_close_pressed() -> void:
	visible = false
