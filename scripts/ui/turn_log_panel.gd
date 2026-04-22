extends Control

@onready var toggle_button: Button = $ToggleButton
@onready var main_panel: PanelContainer = $MainPanel

@onready var title_label: Label = $MainPanel/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var clear_button: Button = $MainPanel/MarginContainer/VBoxContainer/Header/ClearButton
@onready var undo_button: Button = $MainPanel/MarginContainer/VBoxContainer/Header/UndoButton
@onready var scroll_container: ScrollContainer = $MainPanel/MarginContainer/VBoxContainer/ScrollContainer
@onready var log_list: RichTextLabel = $MainPanel/MarginContainer/VBoxContainer/ScrollContainer/LogList

@onready var slide_open_sfx: AudioStreamPlayer = $SlideOpenSfx
@onready var slide_close_sfx: AudioStreamPlayer = $SlideCloseSfx

const MAX_ENTRIES := 100

# Panel layout values
const PANEL_WIDTH := 455.0
const PANEL_HEIGHT := 420.0
const TOGGLE_TAB_WIDTH := 20.0
const SLIDE_DURATION := 0.22

var property_name_to_color: Dictionary = {}
var property_name_to_index: Dictionary = {}

var log_entries: Array[String] = []
var last_cleared_entries: Array[String] = []

var is_collapsed: bool = true
var slide_tween: Tween = null

# Positions for left-side slide behavior
var expanded_panel_x: float = 0.0
var collapsed_panel_x: float = -(PANEL_WIDTH + 8.0)

var expanded_button_x: float = PANEL_WIDTH
var collapsed_button_x: float = 0.0

func _ready() -> void:
	# Ensure the panel fully clears the left edge of the viewport
	# even when this Control has a non-zero left offset.
	collapsed_panel_x = -(PANEL_WIDTH + position.x + 8.0)

	# Build dynamic property lookup tables from actual board data
	_build_property_maps()

	# Block clicks inside the turn log so board tiles underneath
	# the panel area cannot still be hovered/clicked.
	mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	clear_button.mouse_filter = Control.MOUSE_FILTER_STOP
	undo_button.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	log_list.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_button.focus_mode = Control.FOCUS_NONE
	clear_button.focus_mode = Control.FOCUS_NONE
	undo_button.focus_mode = Control.FOCUS_NONE

	# RichTextLabel setup 
	log_list.bbcode_enabled = true
	log_list.scroll_active = false

	# Connect buttons
	toggle_button.pressed.connect(_on_toggle_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	undo_button.pressed.connect(_on_undo_pressed)

	# Initial button states
	clear_button.disabled = true
	undo_button.disabled = true

	# Force exact sizes/positions (important)
	main_panel.position = Vector2(expanded_panel_x, 0)
	main_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	main_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	toggle_button.position = Vector2(expanded_button_x, 0)
	toggle_button.size = Vector2(TOGGLE_TAB_WIDTH, PANEL_HEIGHT)
	toggle_button.custom_minimum_size = Vector2(TOGGLE_TAB_WIDTH, PANEL_HEIGHT)

	# Start collapsed
	collapse_panel(true)

func _build_property_maps() -> void:
	property_name_to_color.clear()
	property_name_to_index.clear()

	for i in range(SpaceData.SPACE_INFO.size()):
		var info: Dictionary = SpaceData.SPACE_INFO[i]

		if not info.has("type") or not info.has("name"):
			continue

		# Only true purchasable property spaces get special formatting
		if str(info["type"]) != "property":
			continue

		var space_name := str(info["name"]).strip_edges()
		if space_name == "":
			continue

		# Use actual space color from board data
		var color_hex := "#FFFFFF"
		if info.has("color") and info["color"] is Color:
			color_hex = _color_to_hex(info["color"])

		property_name_to_color[space_name] = color_hex
		property_name_to_index[space_name] = i

func add_log_entry(text: String) -> void:
	log_entries.append(text)

	# Keep only the most recent MAX_ENTRIES in memory
	while log_entries.size() > MAX_ENTRIES:
		log_entries.remove_at(0)

	_rebuild_visible_log()

	clear_button.disabled = log_entries.is_empty()
	undo_button.disabled = last_cleared_entries.is_empty()

	call_deferred("_scroll_to_bottom")

func add_turn_header(player_index: int, player_name: String, turn_number: int, is_new_round: bool) -> void:
	var display_round: int = maxi(1, turn_number)
	var player_color: String = _get_player_header_color_from_game_state(player_index)


	var round_color := "#D9A441"

	
	if is_new_round:
		if not log_entries.is_empty():
			add_log_entry("")

		var round_header := "[b][color=%s]=== ROUND %d BEGIN ===[/color][/b]" % [
			round_color,
			display_round
		]
		add_log_entry(round_header)

		# Blank line between round header and player turn header
		add_log_entry("")
	else:
		# Blank line between players inside the same round
		add_log_entry("")

	var player_header := "[b][color=%s]--- %s'S TURN ---[/color][/b]" % [
		player_color,
		player_name.to_upper()
	]

	add_log_entry(player_header)
	
	
func _get_player_header_color_from_game_state(player_index: int) -> String:
	if player_index < 0 or player_index >= GameState.players.size():
		return "#B794F4"

	var player = GameState.players[player_index]
	if player == null:
		return "#B794F4"

	return _color_to_hex(player.player_color)
	
func _color_to_hex(color: Color) -> String:
	var r := int(round(color.r * 255.0))
	var g := int(round(color.g * 255.0))
	var b := int(round(color.b * 255.0))
	return "#%02X%02X%02X" % [r, g, b]

func clear_log() -> void:
	if log_entries.is_empty():
		return

	last_cleared_entries = log_entries.duplicate()
	log_entries.clear()

	log_list.clear()
	log_list.custom_minimum_size.y = 0

	clear_button.disabled = true
	undo_button.disabled = last_cleared_entries.is_empty()

func restore_last_cleared_log() -> void:
	if last_cleared_entries.is_empty():
		return

	log_entries = last_cleared_entries.duplicate()
	last_cleared_entries.clear()

	_rebuild_visible_log()

	clear_button.disabled = log_entries.is_empty()
	undo_button.disabled = true

	call_deferred("_scroll_to_bottom")

func _rebuild_visible_log() -> void:
	log_list.clear()

	for entry_text in log_entries:
		var formatted := _format_log_entry(entry_text)
		log_list.append_text(formatted + "\n")

	log_list.custom_minimum_size.y = log_list.get_content_height()

func collapse_panel(instant: bool = false) -> void:
	is_collapsed = true
	toggle_button.text = ">"

	if slide_tween:
		slide_tween.kill()

	main_panel.visible = true

	if instant:
		main_panel.position.x = collapsed_panel_x
		toggle_button.position.x = collapsed_button_x
		return

	if slide_close_sfx and slide_close_sfx.stream:
		slide_close_sfx.play()

	slide_tween = create_tween()
	slide_tween.set_parallel(true)
	slide_tween.set_trans(Tween.TRANS_QUART)
	slide_tween.set_ease(Tween.EASE_OUT)

	slide_tween.tween_property(main_panel, "position:x", collapsed_panel_x, SLIDE_DURATION)
	slide_tween.tween_property(toggle_button, "position:x", collapsed_button_x, SLIDE_DURATION)

func expand_panel() -> void:
	is_collapsed = false
	toggle_button.text = "<"

	if slide_tween:
		slide_tween.kill()

	main_panel.visible = true

	if slide_open_sfx and slide_open_sfx.stream:
		slide_open_sfx.play()

	slide_tween = create_tween()
	slide_tween.set_parallel(true)
	slide_tween.set_trans(Tween.TRANS_QUART)
	slide_tween.set_ease(Tween.EASE_OUT)

	slide_tween.tween_property(main_panel, "position:x", expanded_panel_x, SLIDE_DURATION)
	slide_tween.tween_property(toggle_button, "position:x", expanded_button_x, SLIDE_DURATION)

func toggle_panel() -> void:
	if is_collapsed:
		expand_panel()
	else:
		collapse_panel()

func _on_toggle_pressed() -> void:
	toggle_panel()

func _on_clear_pressed() -> void:
	clear_log()

func _on_undo_pressed() -> void:
	restore_last_cleared_log()

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func is_mouse_over_ui() -> bool:
	var mouse_pos := get_viewport().get_mouse_position()

	var tab_rect := Rect2(
		global_position + toggle_button.position,
		toggle_button.size
	)

	var panel_rect := Rect2(
		global_position + main_panel.position,
		main_panel.size
	)

	return tab_rect.has_point(mouse_pos) or panel_rect.has_point(mouse_pos)
	
func _format_log_entry(text: String) -> String:
	if text.contains("[color=") or text.contains("[b]"):
		return text

	var formatted := text

	formatted = _normalize_money_signs(formatted)

	
	formatted = _apply_player_name_colors(formatted)
	formatted = _apply_space_name_colors(formatted)
	formatted = _apply_money_colors(formatted)
	formatted = _apply_action_highlights(formatted)

	return formatted

func _normalize_money_signs(text: String) -> String:
	var result := text
	var regex := RegEx.new()
	regex.compile("\\$\\d+")

	var matches := regex.search_all(result)

	for i in range(matches.size() - 1, -1, -1):
		var match = matches[i]
		var amount_text := match.get_string()
		var start_idx := match.get_start()

		# If already prefixed with + or -, leave it alone
		if start_idx > 0:
			var prev_char := result.substr(start_idx - 1, 1)
			if prev_char == "+" or prev_char == "-":
				continue

		var sign := _infer_money_sign(result, start_idx)
		if sign != "":
			var replacement := sign + amount_text
			result = result.substr(0, start_idx) + replacement + result.substr(match.get_end())

	return result

func _infer_money_sign(full_text: String, amount_start_idx: int) -> String:
	var context := full_text.to_lower()

	var traded_idx := context.find(" traded ")
	if traded_idx != -1:
		var to_idx := context.find(" to ", traded_idx)
		var for_idx := context.find(" for ", traded_idx)

		if to_idx != -1 and for_idx != -1 and to_idx < for_idx:
			# Money appears before " to " => gave money
			if amount_start_idx > traded_idx and amount_start_idx < to_idx:
				return "-"

			# Money appears after " for " => received money
			if amount_start_idx > for_idx:
				return "+"

	# Situations where money gained to trigger correct color UI
	var positive_keywords := [
		"collected",
		"received",
		"credited",
		"gained",
		"earned",
		"reward",
		"refund"
	]

	# Situations where money would be spent to trigger correct color UI
	var negative_keywords := [
		"paid",
		"purchased",
		"bought",
		"spent",
		"cost",
		"for $",
		"rent to",
		"upgrade",
		"upgraded",
		"unmortgaged"
	]

	var nearest_positive := -1
	var nearest_negative := -1

	for keyword in positive_keywords:
		var idx := context.rfind(keyword, amount_start_idx)
		if idx > nearest_positive:
			nearest_positive = idx

	for keyword in negative_keywords:
		var idx := context.rfind(keyword, amount_start_idx)
		if idx > nearest_negative:
			nearest_negative = idx

	if nearest_positive == -1 and nearest_negative == -1:
		return ""

	if nearest_positive > nearest_negative:
		return "+"

	if nearest_negative > nearest_positive:
		return "-"

	return ""
	
func _apply_player_name_colors(text: String) -> String:
	var result := text

	for i in range(GameState.players.size()):
		var player = GameState.players[i]
		if player == null:
			continue

		var player_name := ""
		if GameState.has_method("get_player_display_name"):
			player_name = str(GameState.get_player_display_name(i)).strip_edges()
		else:
			player_name = str(player.player_name).strip_edges()

		if player_name == "":
			continue

		var player_color := _get_player_header_color_from_game_state(i)

		result = result.replace(
			player_name,
			"[color=%s][b]%s[/b][/color]" % [player_color, player_name]
		)

	return result
	
func _apply_space_name_colors(text: String) -> String:
	var result := text

	for space_name in property_name_to_color.keys():
		var color: String = str(property_name_to_color[space_name])

		var replacement := ""

		if SettingsManager.is_colorblind_enabled():
			# In colorblind mode: plain bold name + more readable symbol only
			replacement = "[b]%s[/b]" % space_name

			var space_index := int(property_name_to_index.get(space_name, -1))
			if space_index != -1:
				var symbol_text := ColorblindHelpers.get_symbol_text_for_space(space_index)

				if symbol_text != "":
					replacement += " [b][color=#FFFFFF][ %s ][/color][/b]" % symbol_text
		else:
			# Normal mode: keep color-coded property names
			replacement = "[color=%s][b]%s[/b][/color]" % [color, space_name]

		result = result.replace(space_name, replacement)

	return result
	
func _apply_money_colors(text: String) -> String:
	var result := text
	var regex := RegEx.new()
	regex.compile("[+-]?\\$\\d+")

	var matches := regex.search_all(result)

	for i in range(matches.size() - 1, -1, -1):
		var match = matches[i]
		var amount_text := match.get_string()

		var amount_color := "#7CFC98" # default green

		if amount_text.begins_with("-"):
			amount_color = "#FF8A8A" # soft red for money spent
		elif amount_text.begins_with("+"):
			amount_color = "#7CFC98" # green for money gained

		var colored := "[color=%s][b]%s[/b][/color]" % [amount_color, amount_text]

		result = result.substr(0, match.get_start()) + colored + result.substr(match.get_end())

	return result
	
func _apply_action_highlights(text: String) -> String:
	var result := text

	var action_phrases := [
		"rolled doubles three times",
		"was sent to the Launch Pad",
		"escaped the Launch Pad",
		"declared bankruptcy",
		"wins the game",
		"ended their turn",
		"drew a card",
		"landed on",
		"purchased",
		"auctioned",
		"collected",
		"paid",
		"rolled"
	]

	for phrase in action_phrases:
		result = result.replace(
			phrase,
			"[b]%s[/b]" % phrase
		)

	return result
