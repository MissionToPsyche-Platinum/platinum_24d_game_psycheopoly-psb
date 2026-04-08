extends CanvasLayer
## properties_detail_popup.gd
## Shows detailed list of all properties owned by a player
## Bankruptcy integration:
## - When show_properties(..., true) is used, each row shows a "Trade/Sell" button
## - Clicking it emits trade_sell_requested(space_index)

signal trade_sell_requested(space_index: int)

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

# When true, show per-asset "Trade/Sell" buttons in the list
var _bankruptcy_mode: bool = false


func _ready() -> void:
	hide_popup()

	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)

	GameController.property_ownership_changed.connect(_on_property_ownership_changed)
	GameController.property_upgraded.connect(_on_property_ownership_changed)
	GameController.player_money_updated.connect(_on_player_money_updated)


func show_popup() -> void:
	visible = true
	control.visible = true


func hide_popup() -> void:
	visible = false
	control.visible = false


# NOTE: second argument is optional; Board can call show_properties(player, true) during bankruptcy
func show_properties(player, bankruptcy_mode: bool = false) -> void:
	if player == null:
		return

	_bankruptcy_mode = bankruptcy_mode
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

	# Title
	var display_name := _get_player_display_name(player, _current_player_index)
	if _bankruptcy_mode:
		title_label.text = "%s's Assets (Trade/Sell)" % display_name
	else:
		title_label.text = "%s's Properties" % display_name

	# In bankruptcy mode we generally DON'T want paging to other players' assets.
	if prev_button:
		prev_button.visible = not _bankruptcy_mode
	if next_button:
		next_button.visible = not _bankruptcy_mode

	# Clear existing list
	for child in properties_list.get_children():
		child.queue_free()

	# Collect owned assets
	var owned_properties: Array[Dictionary] = []
	var total_value: int = 0

	if GameState and GameState.board.size() > 0:
		for i in range(GameState.board.size()):
			var space = GameState.board[i]

			if space is Ownable:
				var ownable := space as Ownable
				if ownable.is_owned() and ownable.get_property_owner() == player.player_id:
					var space_info = SpaceData.SPACE_INFO[i]
					var price := int(space_info.get("price", 0))
					total_value += price

					var current_rent := int(space_info.get("rent", 0))
					if space is PropertySpace:
						match (space as PropertySpace)._current_upgrades:
							1: current_rent = int(space_info.get("rent1data", 0))
							2: current_rent = int(space_info.get("rent2data", 0))
							3: current_rent = int(space_info.get("rent3data", 0))
							4: current_rent = int(space_info.get("rent4data", 0))
							5: current_rent = int(space_info.get("rentDiscovery", 0))

					owned_properties.append({
						"asset_kind": "property",
						"space_index": i,
						"name": space_info.get("name", "Unknown"),
						"color": space_info.get("color", Color.WHITE),
						"type": space_info.get("type", "property"),
						"price": price,
						"rent": current_rent,
						"space": space
					})

	# Add Go For Launch cards as assets
	if player.go_for_launch_cards > 0:
		for n in range(player.go_for_launch_cards):
			owned_properties.append({
				"asset_kind": "go_for_launch_card",
				"space_index": -1,
				"name": "Go For Launch Card",
				"color": Color(0.35, 0.85, 1.0, 1.0),
				"type": "card",
				"price": 0,
				"rent": 0,
				"space": null
			})

	owned_properties.sort_custom(_sort_properties)

	# Render list
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
			var property_item := _create_property_item(prop, _bankruptcy_mode)
			properties_list.add_child(property_item)

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


func _create_property_item(prop: Dictionary, show_trade_sell: bool) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var asset_kind := str(prop.get("asset_kind", "property"))
	var space_index := int(prop.get("space_index", -1))

	# Color indicator OR colorblind symbol
	var border_panel := PanelContainer.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 0)
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.3, 0.3, 0.3, 1)
	border_panel.add_theme_stylebox_override("panel", stylebox)
	border_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if asset_kind == "go_for_launch_card":
		var card_holder := CenterContainer.new()
		card_holder.custom_minimum_size = Vector2(20, 20)
		card_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var background := ColorRect.new()
		background.custom_minimum_size = Vector2(20, 20)
		background.color = prop.get("color", Color(0.35, 0.85, 1.0, 1.0))
		card_holder.add_child(background)

		var letter := Label.new()
		letter.text = "G"
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
		letter.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8-Bold.ttf"))
		letter.add_theme_font_size_override("font_size", 12)
		letter.add_theme_color_override("font_color", Color.WHITE)
		card_holder.add_child(letter)

		border_panel.add_child(card_holder)
	else:
		var symbol_texture: Texture2D = null
		if space_index >= 0:
			symbol_texture = ColorblindHelpers.get_symbol_texture_for_space(space_index)

		if SettingsManager.is_colorblind_enabled() and symbol_texture != null:
			var icon_holder := Control.new()
			icon_holder.custom_minimum_size = Vector2(20, 20)
			icon_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER

			var symbol_shadow := TextureRect.new()
			symbol_shadow.texture = symbol_texture
			symbol_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			symbol_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			symbol_shadow.custom_minimum_size = Vector2(10, 10)
			symbol_shadow.position = Vector2(5, 5)
			symbol_shadow.scale = Vector2(1.0, 1.0)
			symbol_shadow.modulate = Color.BLACK
			icon_holder.add_child(symbol_shadow)

			var symbol := TextureRect.new()
			symbol.texture = symbol_texture
			symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			symbol.custom_minimum_size = Vector2(10, 10)
			symbol.position = Vector2(4, 4)
			symbol.scale = Vector2(1.0, 1.0)
			icon_holder.add_child(symbol)

			border_panel.add_child(icon_holder)
		else:
			var color_indicator := ColorRect.new()
			color_indicator.custom_minimum_size = Vector2(20, 20)
			color_indicator.color = prop.color
			color_indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			border_panel.add_child(color_indicator)

	hbox.add_child(border_panel)

	# Property info VBox
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)

	var is_mortgaged := false
	if prop.get("space", null) is Ownable:
		is_mortgaged = (prop.space as Ownable)._is_mortgaged

	var name_label := Label.new()
	name_label.text = str(prop.name)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8-Bold.ttf"))
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	if is_mortgaged:
		var mortgaged_label := Label.new()
		mortgaged_label.text = "[MORTGAGED]"
		mortgaged_label.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8-Bold.ttf"))
		mortgaged_label.add_theme_font_size_override("font_size", 11)
		mortgaged_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))
		vbox.add_child(mortgaged_label)

	var details_label := Label.new()
	if asset_kind == "go_for_launch_card":
		details_label.text = "Special Card"
	else:
		var type_name := _get_type_display_name(str(prop.type))
		details_label.text = "%s • Price: $%d" % [type_name, int(prop.price)]
	details_label.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8.ttf"))
	details_label.add_theme_font_size_override("font_size", 11)
	details_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(details_label)

	hbox.add_child(vbox)

	# Rent label for true properties only
	if asset_kind == "property" and str(prop.type) == "property" and prop.has("rent") and not is_mortgaged:
		var rent_label := Label.new()
		rent_label.text = "Rent: $%d" % int(prop.rent)
		rent_label.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8.ttf"))
		rent_label.add_theme_font_size_override("font_size", 12)
		rent_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(rent_label)

	# Bankruptcy mode: Trade/Sell button next to each asset
	if show_trade_sell and asset_kind == "property":
		var trade_btn := Button.new()
		trade_btn.text = "Trade/Sell"
		trade_btn.custom_minimum_size = Vector2(84, 24)
		trade_btn.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8-Bold.ttf"))
		trade_btn.add_theme_font_size_override("font_size", 10)
		trade_btn.flat = false
		trade_btn.focus_mode = Control.FOCUS_NONE
		trade_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		trade_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		trade_btn.pressed.connect(_on_trade_sell_pressed.bind(space_index))
		hbox.add_child(trade_btn)

	# Bankruptcy mode: Sell button for GOOJ cards
	if show_trade_sell and asset_kind == "go_for_launch_card":
		var sell_btn := Button.new()
		sell_btn.text = "Sell"
		sell_btn.custom_minimum_size = Vector2(50, 24)
		sell_btn.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8-Bold.ttf"))
		sell_btn.add_theme_font_size_override("font_size", 10)
		sell_btn.flat = false
		sell_btn.focus_mode = Control.FOCUS_NONE
		sell_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		sell_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sell_btn.tooltip_text = "Sell for $50"
		sell_btn.pressed.connect(_on_gooj_sell_pressed)
		hbox.add_child(sell_btn)

	# Mortgage/unmortgage button — only for ownable board properties
	var is_player_turn := not _bankruptcy_mode and _current_player_index == GameState.current_player_index
	if is_player_turn and asset_kind == "property" and prop.get("space", null) is Ownable:
		var ownable := prop.space as Ownable
		if ownable._is_mortgaged:
			var unmortgage_btn := Button.new()
			unmortgage_btn.text = "Unmortgage"
			unmortgage_btn.custom_minimum_size = Vector2(90, 24)
			unmortgage_btn.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8-Bold.ttf"))
			unmortgage_btn.add_theme_font_size_override("font_size", 10)
			unmortgage_btn.flat = false
			unmortgage_btn.focus_mode = Control.FOCUS_NONE
			unmortgage_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			unmortgage_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			unmortgage_btn.disabled = not GameController.check_unmortgage_valid(ownable, _current_player_index)
			unmortgage_btn.tooltip_text = "$%d (mortgage + 10%%)" % GameController.get_unmortgage_cost(ownable)
			unmortgage_btn.pressed.connect(_on_unmortgage_pressed.bind(space_index))
			hbox.add_child(unmortgage_btn)
		else:
			var mortgage_btn := Button.new()
			mortgage_btn.text = "Mortgage"
			mortgage_btn.custom_minimum_size = Vector2(90, 24)
			mortgage_btn.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8-Bold.ttf"))
			mortgage_btn.add_theme_font_size_override("font_size", 10)
			mortgage_btn.flat = false
			mortgage_btn.focus_mode = Control.FOCUS_NONE
			mortgage_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			mortgage_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mortgage_btn.disabled = not GameController.check_mortgage_valid(ownable, _current_player_index)
			mortgage_btn.tooltip_text = "Receive $%d" % GameController.get_mortgage_value(ownable)
			mortgage_btn.pressed.connect(_on_mortgage_pressed.bind(space_index))
			hbox.add_child(mortgage_btn)

	# Details button only for real board spaces
	if asset_kind == "property":
		var details_btn := Button.new()
		details_btn.text = "..."
		details_btn.custom_minimum_size = Vector2(30, 24)
		details_btn.add_theme_font_override("font", load("res://assets/fonts/PixelOperator8-Bold.ttf"))
		details_btn.add_theme_font_size_override("font_size", 10)
		details_btn.flat = false
		details_btn.focus_mode = Control.FOCUS_NONE
		details_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		details_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		details_btn.pressed.connect(_show_property_details_popup.bind(space_index))
		hbox.add_child(details_btn)

	return hbox


func _on_trade_sell_pressed(space_index: int) -> void:
	trade_sell_requested.emit(space_index)


func _on_gooj_sell_pressed() -> void:
	GameController.sell_gooj_card(_current_player_index)
	_show_player_by_index(_current_player_index)


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
	# board space order (ascending index)
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


func _on_property_ownership_changed() -> void:
	if visible:
		_show_player_by_index(_current_player_index)


func _on_player_money_updated(_player) -> void:
	if visible:
		_show_player_by_index(_current_player_index)


func _on_mortgage_pressed(space_index: int) -> void:
	var space = GameState.board[space_index]
	if space is Ownable:
		GameController.mortgage_property.emit(space, _current_player_index)


func _on_unmortgage_pressed(space_index: int) -> void:
	var space = GameState.board[space_index]
	if space is Ownable:
		GameController.unmortgage_property.emit(space, _current_player_index)
