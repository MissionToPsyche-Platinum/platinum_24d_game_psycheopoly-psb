extends CanvasLayer

signal popup_closed

@onready var root_panel: Panel = $Control/CenterContainer/Panel
@onready var title_label: Label = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var target_option: OptionButton = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/TargetRow/TargetOption
@onready var offer_cash_spin: SpinBox = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ValueRow/OfferCashSpin
@onready var request_cash_spin: SpinBox = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ValueRow/RequestCashSpin
@onready var offered_list: Tree = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ListRow/OfferedPanel/OfferedList
@onready var requested_list: Tree = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ListRow/RequestedPanel/RequestedList
@onready var status_label: Label = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var compose_buttons: HBoxContainer = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ComposeButtons
@onready var submit_button: Button = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ComposeButtons/SubmitButton
@onready var cancel_button: Button = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ComposeButtons/CancelButton
@onready var review_box: VBoxContainer = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ReviewBox
@onready var review_label: RichTextLabel = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ReviewBox/ReviewLabel
@onready var review_buttons: HBoxContainer = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ReviewBox/ReviewButtons
@onready var back_button: Button = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ReviewBox/ReviewButtons/BackButton
@onready var reject_button: Button = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ReviewBox/ReviewButtons/RejectButton
@onready var accept_button: Button = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ReviewBox/ReviewButtons/AcceptButton

@onready var target_row: HBoxContainer = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/TargetRow
@onready var value_row: HBoxContainer = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ValueRow
@onready var list_row: HBoxContainer = $Control/CenterContainer/Panel/MarginContainer/VBoxContainer/ListRow


const ColorblindHelpersRef = preload("res://scripts/ui/colorblind_helpers.gd")

var _offering_player: int = -1
var _pending_offer: Dictionary = {}
var _color_icon_cache: Dictionary = {}
var _in_review_mode: bool = false
var _awaiting_ai_decision: bool = false

const CHECKBOX_COLUMN := 0
const PROPERTY_COLUMN := 1
const DETAILS_COLUMN := 2
const CHECKBOX_BG_COLOR := Color(0.1, 0.1, 0.1, 0.3) # Semi-transparent dark overlay
const DETAILS_BG_COLOR := Color(0.22, 0.24, 0.30, 0.0) # Transparent for just text
const DETAILS_TEXT_COLOR := Color(0.8, 0.8, 0.8, 1.0)
const PROPERTY_DETAILS_POPUP_SCENE := preload("res://scenes/PropertyDetailsPopup.tscn")

var _property_details_popup: CanvasLayer = null


func _ready() -> void:
	if _color_icon_cache == null:
		_color_icon_cache = {}

	visible = false
	target_option.item_selected.connect(_on_target_selected)
	submit_button.pressed.connect(_on_submit_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	back_button.pressed.connect(_on_back_pressed)
	reject_button.pressed.connect(_on_reject_pressed)
	accept_button.pressed.connect(_on_accept_pressed)
	offered_list.gui_input.connect(_on_tree_gui_input.bind(offered_list))
	requested_list.gui_input.connect(_on_tree_gui_input.bind(requested_list))
	offered_list.item_edited.connect(_update_review_if_active)
	requested_list.item_edited.connect(_update_review_if_active)
	offer_cash_spin.value_changed.connect(_on_offer_value_changed)
	request_cash_spin.value_changed.connect(_on_offer_value_changed)

	AiManager.ai_trade_reject.connect(_on_reject_pressed)
	AiManager.ai_trade_accept.connect(_on_accept_pressed)
	AiManager.ai_trade_create.connect(_on_ai_submit)

	_configure_property_tree(offered_list)
	_configure_property_tree(requested_list)

	if not GameController.trade_failed.is_connected(_on_trade_failed):
		GameController.trade_failed.connect(_on_trade_failed)

	if not GameController.trade_completed.is_connected(_on_trade_completed):
		GameController.trade_completed.connect(_on_trade_completed)

	_set_compose_mode()


func _configure_property_tree(tree: Tree) -> void:
	tree.columns = 3
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.column_titles_visible = false
	tree.set_column_expand(CHECKBOX_COLUMN, false)
	tree.set_column_expand(PROPERTY_COLUMN, true)
	tree.set_column_expand(DETAILS_COLUMN, false)
	tree.set_column_custom_minimum_width(CHECKBOX_COLUMN, 36)
	tree.set_column_custom_minimum_width(DETAILS_COLUMN, 36)


func show_for_current_player(player_index: int) -> void:
	_offering_player = player_index
	_pending_offer = {}
	status_label.text = ""
	visible = true
	_refresh_target_options()
	offer_cash_spin.value = 0
	request_cash_spin.value = 0
	_set_compose_mode()
	_refresh_space_lists()


func hide_popup() -> void:
	visible = false
	popup_closed.emit()


func _set_compose_mode() -> void:
	_in_review_mode = false
	_awaiting_ai_decision = false
	compose_buttons.visible = true
	review_box.visible = false
	
	target_row.visible = true
	value_row.visible = true
	list_row.visible = true
	status_label.visible = true
	
	root_panel.custom_minimum_size = Vector2(760, 450)
	
	title_label.text = "Create Trade Offer"


func _set_review_mode(summary: String) -> void:
	_in_review_mode = true
	_awaiting_ai_decision = false
	compose_buttons.visible = false
	review_box.visible = true
	
	target_row.visible = false
	value_row.visible = false
	list_row.visible = false
	status_label.visible = false
	
	root_panel.custom_minimum_size = Vector2(760, 310)

	var offering_is_ai := false
	if _offering_player >= 0 and _offering_player < GameState.players.size():
		offering_is_ai = GameState.players[_offering_player].player_is_ai

	var target_player := int(_pending_offer.get("target_player", -1))
	if target_player >= 0 and target_player < GameState.players.size():
		_awaiting_ai_decision = GameState.players[target_player].player_is_ai

	back_button.visible = (not offering_is_ai) and (not _awaiting_ai_decision)
	reject_button.visible = not _awaiting_ai_decision
	accept_button.visible = not _awaiting_ai_decision


	
	title_label.text = "Trade Review"
	review_label.text = summary

func _update_review_if_active() -> void:
	if not _in_review_mode:
		return
	_pending_offer = _build_offer_from_ui()
	review_label.text = _summarize_trade_offer(_pending_offer)


func _on_offer_value_changed(_value: float) -> void:
	_update_review_if_active()


func _refresh_target_options() -> void:
	target_option.clear()
	for i in range(GameState.players.size()):
		if i == _offering_player:
			continue
		target_option.add_item(GameState.get_player_display_name(i))
		target_option.set_item_metadata(target_option.item_count - 1, i)

	if target_option.item_count > 0:
		target_option.select(0)
	else:
		status_label.text = "No available player to trade with."


func _on_target_selected(_index: int) -> void:
	_refresh_space_lists()


func _get_selected_target_player() -> int:
	if target_option.item_count <= 0:
		return -1
	var selected := target_option.selected
	if selected < 0:
		return -1
	return int(target_option.get_item_metadata(selected))


func _refresh_space_lists() -> void:
	offered_list.clear()
	requested_list.clear()
	var offered_root := offered_list.create_item()
	var requested_root := requested_list.create_item()

	if _offering_player < 0:
		return

	var target_player := _get_selected_target_player()
	var offered_spaces: Array[int] = GameController.get_tradeable_space_indexes(_offering_player)
	for space_index in offered_spaces:
		_add_space_item(offered_list, offered_root, space_index)

	if target_player < 0:
		return
	var requested_spaces: Array[int] = GameController.get_tradeable_space_indexes(target_player)
	for space_index in requested_spaces:
		_add_space_item(requested_list, requested_root, space_index)


func _add_space_item(list_node: Tree, root_item: TreeItem, space_index: int) -> void:
	var tree_item := list_node.create_item(root_item)
	tree_item.set_cell_mode(CHECKBOX_COLUMN, TreeItem.CELL_MODE_CHECK)
	tree_item.set_editable(CHECKBOX_COLUMN, true)
	tree_item.set_checked(CHECKBOX_COLUMN, false)
	tree_item.set_selectable(CHECKBOX_COLUMN, false)
	tree_item.set_custom_bg_color(CHECKBOX_COLUMN, CHECKBOX_BG_COLOR)

	# Special non-board asset: Go For Launch card
	if space_index == GameController.GO_FOR_LAUNCH_TRADE_ID:
		var special_item_icon := _create_go_for_launch_icon()
		tree_item.set_icon(PROPERTY_COLUMN, special_item_icon)
		tree_item.set_text(PROPERTY_COLUMN, "Go For Launch Card")
		tree_item.set_selectable(PROPERTY_COLUMN, true)
		tree_item.set_metadata(PROPERTY_COLUMN, space_index)
		tree_item.set_text(DETAILS_COLUMN, "")
		tree_item.set_selectable(DETAILS_COLUMN, false)
		tree_item.set_text_alignment(DETAILS_COLUMN, HORIZONTAL_ALIGNMENT_CENTER)
		tree_item.set_custom_bg_color(DETAILS_COLUMN, DETAILS_BG_COLOR, false)
		tree_item.set_custom_color(DETAILS_COLUMN, DETAILS_TEXT_COLOR)
		return

	var info := SpaceData.get_space_info(space_index)
	var item_icon := _get_or_create_color_icon(info, space_index)

	var is_mortgaged := space_index < GameState.board.size() \
		and GameState.board[space_index] is Ownable \
		and (GameState.board[space_index] as Ownable)._is_mortgaged

	var has_upgrades := space_index < GameState.board.size() \
		and GameState.board[space_index] is PropertySpace \
		and (GameState.board[space_index] as PropertySpace)._current_upgrades > 0

	var item_label := _build_space_label(space_index)
	if is_mortgaged:
		item_label += " [MORTGAGED]"
	if has_upgrades:
		item_label += " [HAS UPGRADES]"

	tree_item.set_icon(PROPERTY_COLUMN, item_icon)
	tree_item.set_text(PROPERTY_COLUMN, item_label)
	if is_mortgaged:
		tree_item.set_custom_color(PROPERTY_COLUMN, Color(0.9, 0.2, 0.2, 1))
	if has_upgrades:
		tree_item.set_custom_color(PROPERTY_COLUMN, Color(0.9, 0.6, 0.2, 1))
	tree_item.set_selectable(PROPERTY_COLUMN, not has_upgrades)
	tree_item.set_metadata(PROPERTY_COLUMN, space_index)
	tree_item.set_text(DETAILS_COLUMN, "...")
	tree_item.set_selectable(DETAILS_COLUMN, false)
	tree_item.set_text_alignment(DETAILS_COLUMN, HORIZONTAL_ALIGNMENT_CENTER)
	tree_item.set_custom_bg_color(DETAILS_COLUMN, DETAILS_BG_COLOR, false)
	tree_item.set_custom_color(DETAILS_COLUMN, DETAILS_TEXT_COLOR)



func _build_space_label(space_index: int) -> String:
	var info := SpaceData.get_space_info(space_index)
	var space_name := str(info.get("name", "Space " + str(space_index)))
	return space_name


func _get_or_create_color_icon(space_info: Dictionary, space_index: int) -> Texture2D:
	if _color_icon_cache == null:
		_color_icon_cache = {}

	
	# Colorblind mode support:
	
	if SettingsManager.is_colorblind_enabled():
		var symbol_texture: Texture2D = ColorblindHelpersRef.get_symbol_texture_for_space(space_index)
		if symbol_texture != null:
			return symbol_texture

	
	# Normal mode fallback: use colored square
	
	var color: Color = space_info.get("color", Color(0.7, 0.7, 0.7, 1.0))
	var cache_key := "%0.3f_%0.3f_%0.3f_%0.3f" % [color.r, color.g, color.b, color.a]

	if _color_icon_cache.has(cache_key):
		return _color_icon_cache[cache_key]

	var image := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	image.fill(color)

	var border_color := Color(0.2, 0.2, 0.2, 1.0)
	for x in range(14):
		image.set_pixel(x, 0, border_color)
		image.set_pixel(x, 13, border_color)
	for y in range(14):
		image.set_pixel(0, y, border_color)
		image.set_pixel(13, y, border_color)

	var texture := ImageTexture.create_from_image(image)
	_color_icon_cache[cache_key] = texture
	return texture


func _on_tree_gui_input(event: InputEvent, tree: Tree) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_event := event as InputEventMouseButton
		var clicked_item := tree.get_item_at_position(click_event.position)
		if clicked_item == null:
			return

		var clicked_column := tree.get_column_at_position(click_event.position)

		var asset_id := int(clicked_item.get_metadata(PROPERTY_COLUMN))

		# If clicking details, show popup only for real board properties
		if clicked_column == DETAILS_COLUMN:
			if asset_id != GameController.GO_FOR_LAUNCH_TRADE_ID:
				_show_property_details_popup(asset_id)
			return

		# Otherwise, toggle checkbox (manual toggle to mimic "whole row" selection)
		# However, if we click exactly on the checkbox column, the Tree might handle it automatically.
		# But since we want the WHOLE row to act as a toggle, we can force it here.
		# Note: If the native checkbox logic runs, this might flip it back.
		# To avoid double-toggle on the checkbox column itself, we can skip manual toggle if column is 0.
		# BUT wait, the user says "clicking anywhere".
		# Let's try manually toggling only if it's NOT the checkbox column.
		if clicked_column != CHECKBOX_COLUMN:
			clicked_item.set_checked(CHECKBOX_COLUMN, not clicked_item.is_checked(CHECKBOX_COLUMN))
		_update_review_if_active()


func _show_property_details_popup(space_index: int) -> void:
	if _property_details_popup == null:
		_property_details_popup = PROPERTY_DETAILS_POPUP_SCENE.instantiate()
		_property_details_popup.layer = max(120, int(layer) + 1)
		get_tree().root.add_child(_property_details_popup)
	else:
		_property_details_popup.layer = max(120, int(layer) + 1)

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


func _collect_selected_space_indices(list_node: Tree) -> Array[int]:
	var results: Array[int] = []
	var root := list_node.get_root()
	if root == null:
		return results

	var item := root.get_first_child()
	while item != null:
		if item.is_checked(CHECKBOX_COLUMN):
			results.append(int(item.get_metadata(PROPERTY_COLUMN)))
		item = item.get_next()
	return results


func _build_offer_from_ui() -> Dictionary:
	var target_player := _get_selected_target_player()
	return {
		"offering_player": _offering_player,
		"target_player": target_player,
		"offer_cash": int(offer_cash_spin.value),
		"request_cash": int(request_cash_spin.value),
		"offered_spaces": _collect_selected_space_indices(offered_list),
		"requested_spaces": _collect_selected_space_indices(requested_list),
	}

func _build_ai_offer(offering_player: int, receiving_player: int, offering_cash: int, receiving_cash: int, offering_properties: Array[int], receiving_properties: Array[int]) -> Dictionary:
	return {
		"offering_player": offering_player,
		"target_player": receiving_player,
		"offer_cash": offering_cash,
		"request_cash": receiving_cash,
		"offered_spaces": offering_properties,
		"requested_spaces": receiving_properties,
	}

func _format_space_summary(space_indexes: Array) -> String:
	if space_indexes.is_empty():
		return "None"

	var entries: Array[String] = []

	for space_index_variant in space_indexes:
		var space_index := int(space_index_variant)

		if space_index == GameController.GO_FOR_LAUNCH_TRADE_ID:
			entries.append("[color=#59d9ff]Go For Launch Card[/color]")
			continue

		var info := SpaceData.get_space_info(space_index)
		var space_name := str(info.get("name", "Space " + str(space_index)))
		var is_mortgaged := space_index < GameState.board.size() \
			and GameState.board[space_index] is Ownable \
			and (GameState.board[space_index] as Ownable)._is_mortgaged
		var mortgaged_tag := " [color=#e03333][MORTGAGED][/color]" if is_mortgaged else ""

		if SettingsManager.is_colorblind_enabled():
			var symbol_text := ColorblindHelpersRef.get_symbol_text_for_space(space_index)
			if symbol_text != "":
				entries.append("%s %s%s" % [symbol_text, space_name, mortgaged_tag])
			else:
				entries.append(space_name + mortgaged_tag)
		else:
			var color: Color = info.get("color", Color(0.7, 0.7, 0.7, 1.0))
			var color_hex := color.to_html(false)
			entries.append("[color=#%s]%s[/color]%s" % [color_hex, space_name, mortgaged_tag])

	return ", ".join(entries)


func _summarize_trade_offer(trade_offer: Dictionary) -> String:
	var offering_name := GameState.get_player_display_name(int(trade_offer.get("offering_player", -1)))
	var target_name := GameState.get_player_display_name(int(trade_offer.get("target_player", -1)))
	var target_is_ai := false
	var target_player := int(trade_offer.get("target_player", -1))
	if target_player >= 0 and target_player < GameState.players.size():
		target_is_ai = GameState.players[target_player].player_is_ai
	var offered_spaces: Array = trade_offer.get("offered_spaces", [])
	var requested_spaces: Array = trade_offer.get("requested_spaces", [])
	var lines: Array[String] = []
	
	lines.append("[center]")
	lines.append("Pass offer to %s for review." % target_name)
	lines.append("")
	lines.append("%s offers: $%d" % [
		offering_name,
		int(trade_offer.get("offer_cash", 0))
	])
	lines.append("Properties: %s" % _format_space_summary(offered_spaces))
	lines.append("")
	lines.append("%s requests: $%d" % [
		offering_name,
		int(trade_offer.get("request_cash", 0))
	])
	lines.append("Properties: %s" % _format_space_summary(requested_spaces))
	lines.append("")
	if target_is_ai:
		lines.append("Awaiting AI decision...")
	else:
		lines.append("Accept this trade?")
	lines.append("[/center]")
	return "\n".join(lines)

func _on_ai_submit(offering_player: int, receiving_player: int, offering_cash: int, receiving_cash: int, offering_properties: Array[int], receiving_properties: Array[int]) -> void:
	show_for_current_player(offering_player)
	var trade_offer := _build_ai_offer(offering_player, receiving_player, offering_cash, receiving_cash, offering_properties, receiving_properties)
	_on_submit(trade_offer)

func _on_submit_pressed() -> void:
	var trade_offer := _build_offer_from_ui()
	_on_submit(trade_offer)

	
func _on_submit(trade_offer: Dictionary) -> void:
	var validation := GameController.validate_trade_offer(trade_offer)
	if not bool(validation.get("ok", false)):
		status_label.text = str(validation.get("reason", "Trade is invalid."))
		return

	_pending_offer = trade_offer
	status_label.text = ""

	# Turn log: trade proposed
	var offering_name := GameState.get_player_display_name(int(trade_offer.get("offering_player", -1)))
	var target_name := GameState.get_player_display_name(int(trade_offer.get("target_player", -1)))
	GameController.log_transaction("%s proposed a trade to %s." % [offering_name, target_name])

	_set_review_mode(_summarize_trade_offer(trade_offer))
	if (GameState.players[(int(trade_offer.get("target_player", -1)))].player_is_ai):
		AiManager.ai_trade_decision(trade_offer)

func _on_cancel_pressed() -> void:
	hide_popup()


func _on_back_pressed() -> void:
	_set_compose_mode()


func _on_reject_pressed() -> void:
	if not _pending_offer.is_empty():
		var offering_name := GameState.get_player_display_name(int(_pending_offer.get("offering_player", -1)))
		var target_name := GameState.get_player_display_name(int(_pending_offer.get("target_player", -1)))
		GameController.log_transaction("%s declined the trade offer from %s." % [target_name, offering_name])
		GameController.trade_finished.emit()

	status_label.text = "Trade rejected."
	hide_popup()


func _on_accept_pressed() -> void:
	if _pending_offer.is_empty():
		status_label.text = "No pending offer to accept."
		_set_compose_mode()
		return

	var success := GameController.execute_trade_offer(_pending_offer)
	if success:
		hide_popup()


func _on_trade_failed(reason: String) -> void:
	if not visible:
		return
	status_label.text = reason
	_set_compose_mode()


func _on_trade_completed(trade_offer: Dictionary) -> void:
	# Turn log: accepted trade summary
	GameController.log_transaction(_build_trade_log_summary(trade_offer))

	if not visible:
		return

	status_label.text = "Trade completed successfully."
	

func show_for_player_with_preselected_offer(player_index: int, offered_space_index: int) -> void:
	show_for_current_player(player_index)

	# ensure lists are populated before we try to check anything
	await get_tree().process_frame

	_check_space_in_tree(offered_list, offered_space_index)


func _check_space_in_tree(tree: Tree, space_index: int) -> void:
	var root: TreeItem = tree.get_root()
	if root == null:
		return

	var item: TreeItem = root.get_first_child()
	while item != null:
		var meta: Variant = item.get_metadata(PROPERTY_COLUMN) 
		if typeof(meta) == TYPE_INT and int(meta) == space_index:
			item.set_checked(CHECKBOX_COLUMN, true)
			item.select(PROPERTY_COLUMN) 
			return

		item = item.get_next()
		
func _get_space_names(space_indexes: Array) -> Array[String]:
	var names: Array[String] = []

	for space_index_variant in space_indexes:
		var space_index := int(space_index_variant)

		if space_index == GameController.GO_FOR_LAUNCH_TRADE_ID:
			names.append("Go For Launch Card")
			continue

		var info := SpaceData.get_space_info(space_index)
		var space_name := str(info.get("name", "Space " + str(space_index)))
		names.append(space_name)

	return names


func _join_natural(parts: Array[String]) -> String:
	if parts.is_empty():
		return ""

	if parts.size() == 1:
		return parts[0]

	if parts.size() == 2:
		return parts[0] + " and " + parts[1]

	var all_but_last := parts.slice(0, parts.size() - 1)
	return ", ".join(all_but_last) + ", and " + parts[parts.size() - 1]


func _build_trade_side_summary(cash_amount: int, space_indexes: Array) -> String:
	var parts: Array[String] = []

	if cash_amount > 0:
		parts.append("$" + str(cash_amount))

	var property_names := _get_space_names(space_indexes)
	for property_name in property_names:
		parts.append(property_name)

	if parts.is_empty():
		return "nothing"

	return _join_natural(parts)


func _build_trade_log_summary(trade_offer: Dictionary) -> String:
	var offering_player := int(trade_offer.get("offering_player", -1))
	var target_player := int(trade_offer.get("target_player", -1))

	var offering_name := GameState.get_player_display_name(offering_player)
	var target_name := GameState.get_player_display_name(target_player)

	var offer_cash := int(trade_offer.get("offer_cash", 0))
	var request_cash := int(trade_offer.get("request_cash", 0))
	var offered_spaces: Array = trade_offer.get("offered_spaces", [])
	var requested_spaces: Array = trade_offer.get("requested_spaces", [])

	var offering_gives := _build_trade_side_summary(offer_cash, offered_spaces)
	var target_gives := _build_trade_side_summary(request_cash, requested_spaces)

	return "%s traded %s to %s for %s." % [
		offering_name,
		offering_gives,
		target_name,
		target_gives
	]


func _create_go_for_launch_icon() -> Texture2D:
	var cache_key := "go_for_launch_card_icon"

	if _color_icon_cache.has(cache_key):
		return _color_icon_cache[cache_key]

	var image := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.35, 0.85, 1.0, 1.0))

	var border_color := Color(0.2, 0.2, 0.2, 1.0)
	for x in range(14):
		image.set_pixel(x, 0, border_color)
		image.set_pixel(x, 13, border_color)
	for y in range(14):
		image.set_pixel(0, y, border_color)
		image.set_pixel(13, y, border_color)

	# Simple pixel "G" in white
	var points := [
		Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3),
		Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6), Vector2i(3, 7), Vector2i(3, 8),
		Vector2i(4, 9), Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9),
		Vector2i(8, 7), Vector2i(7, 7), Vector2i(6, 7),
		Vector2i(8, 8)
	]

	for p in points:
		image.set_pixel(p.x, p.y, Color.WHITE)

	var texture := ImageTexture.create_from_image(image)
	_color_icon_cache[cache_key] = texture
	return texture
