extends CanvasLayer

signal purchase_pressed(space_num: int)
signal auction_pressed(space_num: int)
signal pay_pressed(space_num: int)
signal draw_card_pressed(space_num: int)
signal move_pressed(space_num: int)
signal close_pressed()

# Load popups
const PropertyDetailsPopup = preload("res://scenes/PropertyDetailsPopup.tscn")

# Load chance card data.
const ChanceCardData = preload("res://scripts/core/chance_card_data.gd")
const ChanceCardPopup = preload("res://scenes/ChanceCardPopup.tscn")

# References to UI elements
@onready var panel_container: Panel = $Control/PanelContainer
@onready var color_bar: ColorRect = $Control/PanelContainer/MarginContainer/VBoxContainer/ColorBar
@onready var space_name_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/ColorBar/SpaceName
@onready var action_description: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/ActionDescription
@onready var details_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/DetailsButton
@onready var purchase_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/PurchaseButton
@onready var pay_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/PayButton
@onready var draw_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/DrawButton
@onready var move_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/MoveButton
@onready var auction_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/AuctionButton
@onready var close_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/CloseButton

var current_space_num: int = -1

# Popup instance
var _details_popup: CanvasLayer = null
var _chance_card_popup: CanvasLayer = null

func _ready() -> void:
	# Initially hidden
	hide_popup()
	
	# Connect signals
	details_button.pressed.connect(_on_details_pressed)
	purchase_button.pressed.connect(_on_purchase_pressed)
	pay_button.pressed.connect(_on_pay_pressed)
	draw_button.pressed.connect(_on_draw_pressed)
	move_button.pressed.connect(_on_move_pressed)
	auction_button.pressed.connect(_on_auction_pressed)
	close_button.pressed.connect(_on_close_pressed)

func show_actions(space_num: int) -> void:
	current_space_num = space_num
	var space_info = SpaceData.get_space_info(space_num)
	
	space_name_label.text = space_info.name
	
	# Set color bar color
	if space_info.has("color"):
		color_bar.color = space_info.color
		color_bar.visible = true
	else:
		color_bar.visible = false
	
	# Determine what actions are available
	var can_purchase = false
	var can_auction = false
	var can_pay = false
	var can_draw = false
	var can_move = false
	var has_details = false
	var description = ""
	
	match space_info.type:
		"property", "instrument", "planet":
			has_details = true
			# Check if already owned in GameState
			var property = GameState.board[space_num]
			if property is Ownable and not property._is_owned:
				can_auction = true
				if space_info.has("price"):
					var price = space_info.price
					var player_idx = GameState.current_player_index
					if GameState.players[player_idx].balance >= price:
						can_purchase = true
						description = "You landed on %s. Would you like to purchase it for $%d or put it up for auction?" % [space_info.name, price]
					else:
						can_purchase = false
						description = "You landed on %s. It costs $%d, but you only have $%d. It must be auctioned." % [space_info.name, price, GameState.players[player_idx].balance]
				else:
					description = "You landed on %s." % space_info.name
			elif property is Ownable and property._is_owned:
				if property._player_owner == GameState.current_player_index:
					description = "You landed on %s. You own this property." % [space_info.name]
				else:
					description = "You landed on %s. It is owned by Player %d." % [space_info.name, property._player_owner + 1]
					can_pay = true
			else:
				description = "You landed on %s." % space_info.name
		"cost":
			description = "You must pay $%d." % space_info.get("amount", 0)
			can_pay = true
		"card":
			description = space_info.description if space_info.has("description") else "Draw a card!"
			can_draw = true
		"corner":
			description = space_info.description if space_info.has("description") else "Welcome to %s." % space_info.name
			# Check for Solar Storm specifically
			if current_space_num == 30:
				can_move = true
		_:
			description = "You landed on space %d." % space_num
			
	action_description.text = description
	purchase_button.visible = can_purchase
	pay_button.visible = can_pay
	draw_button.visible = can_draw
	move_button.visible = can_move
	auction_button.visible = can_auction
	details_button.visible = has_details
	close_button.visible = not can_auction and not can_pay and not can_draw and not can_move # Show Close only if no other mandatory action
	
	# Show the UI
	self.visible = true

func hide_popup() -> void:
	self.visible = false

func _on_details_pressed() -> void:
	# Create popup if it doesn't exist
	if _details_popup == null:
		_details_popup = PropertyDetailsPopup.instantiate()
		# CanvasLayers must be added to the SceneTree directly
		get_tree().root.add_child(_details_popup)
	
	# Show the popup with current space details
	var property = GameState.board[current_space_num]
	var owner_str = "Unowned"
	var owner_color: Color = Color(0.7, 0.7, 0.7, 1)
	if property is Ownable and property._is_owned:
		var owner_index := int(property._player_owner)
		if owner_index >= 0 and owner_index < GameState.players.size():
			owner_str = GameState.players[owner_index].player_name
			owner_color = GameState.players[owner_index].player_color
		else:
			owner_str = "Player %d" % (owner_index + 1)
		
	_details_popup.show_space_details(current_space_num, owner_str, owner_color)

func _on_purchase_pressed() -> void:
	purchase_pressed.emit(current_space_num)

	# Previously this was hard-coded to 0, which caused Player 1 to be charged
	# even when Player 2/3/etc made the purchase.
	# now using the current active player index from GameState.
	GameController.purchase_property.emit(GameState.board[current_space_num], GameState.current_player_index)

	hide_popup()

func _on_pay_pressed() -> void:
	pay_pressed.emit(current_space_num)

	# Previously this was hard-coded to 0, which caused Player 1 to pay/owe rent
	# even when Player 2/3/etc landed here.
	# now using the current active player index from GameState.
	GameController.pay_rent.emit(GameState.board[current_space_num], GameState.current_player_index)

	hide_popup()

func _on_draw_pressed() -> void:
	# Create popup if it doesn't exist
	if _chance_card_popup == null:
		_chance_card_popup = ChanceCardPopup.instantiate()
		# CanvasLayers must be added to the SceneTree directly
		get_tree().root.add_child(_chance_card_popup)
	
	_chance_card_popup.show_card_details(current_space_num)
	
	draw_card_pressed.emit(current_space_num)
	
	hide_popup()
	
func _on_move_pressed() -> void:
	move_pressed.emit(current_space_num)
	hide_popup()

func _on_auction_pressed() -> void:
	auction_pressed.emit(current_space_num)
	hide_popup()

func _on_close_pressed() -> void:
	close_pressed.emit()
	hide_popup()
