extends CanvasLayer
## properties_detail_popup.gd
## Shows detailed list of all properties owned by a player

const PROPERTY_DETAILS_POPUP_SCENE := preload("res://scenes/PropertyDetailsPopup.tscn")

@onready var properties_list: VBoxContainer = $Control/PopupPanel/MarginContainer/VBox/ScrollContainer/PropertiesList
@onready var title_label: Label = $Control/PopupPanel/MarginContainer/VBox/HeaderHBox/TitleLabel
@onready var prev_button: Button = $Control/PopupPanel/MarginContainer/VBox/HeaderHBox/PrevButton
@onready var next_button: Button = $Control/PopupPanel/MarginContainer/VBox/HeaderHBox/NextButton
@onready var close_button: Button = $Control/PopupPanel/MarginContainer/VBox/HeaderHBox/CloseButton
@onready var total_value_label: Label = $Control/PopupPanel/MarginContainer/VBox/TotalValueLabel
@onready var popup_panel: PanelContainer = $Control/PopupPanel
@onready var control: Control = $Control

var _current_player_index: int = 0
var _property_details_popup: CanvasLayer = null

func _ready() -> void:
	# Hide initially
	hide_popup()
	
	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)


func show_popup() -> void:
	visible = true
	control.visible = true


func hide_popup() -> void:
	visible = false
	control.visible = false


func show_properties(player) -> void:
	if player == null:
		return
	_set_current_player_index(player)
	_show_player_by_index(_current_player_index)


func _show_player_by_index(player_index: int) -> void:
	if not GameState or GameState.players.is_empty():
		return

	var clamped_index := player_index % GameState.players.size()
	if clamped_index < 0:
		clamped_index = GameState.players.size() - 1

	_current_player_index = clamped_index
	var player = GameState.players[_current_player_index]
	
	# Update title with player name
	var display_name := _get_player_display_name(player, _current_player_index)
	title_label.text = "%s's Properties" % display_name
	
	# Clear existing list
	for child in properties_list.get_children():
		child.queue_free()
	
	# Get all properties owned by this player
	var owned_properties: Array[Dictionary] = []
	var total_value: int = 0
	
	if GameState and GameState.board.size() > 0:
		for i in range(GameState.board.size()):
			var space = GameState.board[i]
			
			# Check if this space is ownable and owned by the current player
			if space is Ownable:
				var ownable := space as Ownable
				if ownable.is_owned() and ownable.get_property_owner() == player.player_id:
					# Get the space info
					var space_info = SpaceData.SPACE_INFO[i]
					var price = space_info.get("price", 0)
					total_value += price
					
					owned_properties.append({
						"space_index": i,
						"name": space_info.get("name", "Unknown"),
						"color": space_info.get("color", Color.WHITE),
						"type": space_info.get("type", "property"),
						"price": price,
						"rent": space_info.get("rent", 0),
						"space": space
					})
	
	# Sort properties by type and name
	owned_properties.sort_custom(_sort_properties)
	
	# Create list items for each property
	if owned_properties.is_empty():
		var no_props_label := Label.new()
		no_props_label.text = "No properties owned yet"
		no_props_label.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8.ttf"))
		no_props_label.add_theme_font_size_override("font_size", 12)
		no_props_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		no_props_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		properties_list.add_child(no_props_label)
	else:
		for prop in owned_properties:
			var property_item := _create_property_item(prop)
			properties_list.add_child(property_item)
	
	# Update total value
	total_value_label.text = "Total Property Value: $%d" % total_value


func _set_current_player_index(player) -> void:
	if not GameState or GameState.players.is_empty():
		_current_player_index = 0
		return

	if player is PlayerState:
		_current_player_index = int(player.player_id)
		return

	var idx := GameState.players.find(player)
	_current_player_index = max(idx, 0)


func _get_player_display_name(player, player_index: int) -> String:
	if GameState:
		return GameState.get_player_display_name(player_index)

	if player != null:
		var player_name := str(player.player_name).strip_edges()
		if player_name != "":
			return player_name

	return "Player %d" % (player_index + 1)


func _create_property_item(prop: Dictionary) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	# Color indicator
	var color_indicator := ColorRect.new()
	color_indicator.custom_minimum_size = Vector2(20, 20)
	color_indicator.color = prop.color
	color_indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Add border to color indicator
	var border_panel := PanelContainer.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 0)
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.3, 0.3, 0.3, 1)
	border_panel.add_theme_stylebox_override("panel", stylebox)
	border_panel.add_child(color_indicator)
	border_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(border_panel)
	
	# Property info VBox
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	
	# Property name
	var name_label := Label.new()
	name_label.text = prop.name
	name_label.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8-Bold.ttf"))
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)
	
	# Property details
	var details_label := Label.new()
	var type_name := _get_type_display_name(prop.type)
	details_label.text = "%s • Price: $%d" % [type_name, prop.price]
	details_label.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8.ttf"))
	details_label.add_theme_font_size_override("font_size", 11)
	details_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(details_label)
	
	hbox.add_child(vbox)
	
	# Add rent info for properties
	if prop.type == "property" and prop.has("rent"):
		var rent_label := Label.new()
		rent_label.text = "Rent: $%d" % prop.rent
		rent_label.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8.ttf"))
		rent_label.add_theme_font_size_override("font_size", 12)
		rent_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(rent_label)
	
	return hbox


func _get_type_display_name(type: String) -> String:
	match type:
		"property":
			return "Asteroid"
		"instrument":
			return "Instrument"
		"planet":
			return "Planet"
		_:
			return type.capitalize()


func _sort_properties(a: Dictionary, b: Dictionary) -> bool:
	# Match PlayerPropertiesPreview ordering: board space order (ascending index)
	return int(a.get("space_index", 999)) < int(b.get("space_index", 999))


func _show_property_details_popup(space_index: int) -> void:
	if _property_details_popup == null:
		_property_details_popup = PROPERTY_DETAILS_POPUP_SCENE.instantiate()
		_property_details_popup.layer = max(110, int(layer) + 1)
		get_tree().root.add_child(_property_details_popup)
	else:
		_property_details_popup.layer = max(110, int(layer) + 1)

	var owner_name := "Unowned"
	var owner_color := Color(0.7, 0.7, 0.7, 1)

	if space_index >= 0 and space_index < GameState.board.size() and GameState.board[space_index] is Ownable:
		var ownable := GameState.board[space_index] as Ownable
		if ownable.is_owned() and ownable.get_property_owner() >= 0 and ownable.get_property_owner() < GameState.players.size():
			var owner_index := ownable.get_property_owner()
			owner_name = GameState.get_player_display_name(owner_index)
			owner_color = GameState.players[owner_index].player_color

	if _property_details_popup.has_method("show_space_details"):
		_property_details_popup.call("show_space_details", space_index, owner_name, owner_color)


func _on_close_pressed() -> void:
	hide_popup()


func _on_prev_pressed() -> void:
	_show_player_by_index(_current_player_index - 1)


func _on_next_pressed() -> void:
	_show_player_by_index(_current_player_index + 1)
