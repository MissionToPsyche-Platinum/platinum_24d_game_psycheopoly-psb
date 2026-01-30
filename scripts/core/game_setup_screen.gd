extends Control

# Node references
@onready var total_option: OptionButton = %TotalOption
@onready var human_option: OptionButton = %HumanOption
@onready var ai_value: Label = %AIValue
@onready var summary_label: Label = %SummaryLabel
@onready var humans_list: VBoxContainer = %HumansList
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton




const MIN_PLAYERS := 2
const MAX_PLAYERS := 6

# Some space themed names for players to choose from. Will add more, just something to get started
const NAME_POOL := [
	"Nova", "Atlas", "Orion", "Vega", "Luna", "Helios"
]

#Colors for the player tokens
const COLOR_POOL := [
	{"label":"Red",    "color": Color(0.90, 0.25, 0.25)},
	{"label":"Blue",   "color": Color(0.25, 0.45, 0.90)},
	{"label":"Green",  "color": Color(0.25, 0.80, 0.35)},
	{"label":"Yellow", "color": Color(0.95, 0.85, 0.25)},
	{"label":"Purple", "color": Color(0.70, 0.35, 0.90)},
	{"label":"Orange", "color": Color(0.95, 0.55, 0.20)}
]



var total_players: int = 2
var human_players: int = 1
var human_configs: Array = [] 


func _ready() -> void:
	_build_total_players_dropdown()
	_build_human_players_dropdown()

	# Just default selection
	_set_total_players(2)
	_set_human_players(1)

	# Wire signals
	total_option.item_selected.connect(_on_total_selected)
	human_option.item_selected.connect(_on_human_selected)
	
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)


	_update_summary()
	_rebuild_human_rows()
	_refresh_start_button()



# ---------------------------
# builkding the dropdown
# ---------------------------
func _build_total_players_dropdown() -> void:
	total_option.clear()
	for n in range(MIN_PLAYERS, MAX_PLAYERS + 1):
		total_option.add_item(str(n), n)

func _build_human_players_dropdown() -> void:
	human_option.clear()
	# Humans must be at least 1, and at most total_players
	for n in range(1, total_players + 1):
		human_option.add_item(str(n), n)


# --------------------------------------
# Setters to keep UI and data consistent
# --------------------------------------
func _set_total_players(n: int) -> void:
	total_players = clampi(n, MIN_PLAYERS, MAX_PLAYERS)

	# Update dropdown selection
	var idx := total_option.get_item_index(total_players)
	if idx != -1:
		total_option.select(idx)

	# Rebuild humans dropdown based on new total
	_build_human_players_dropdown()

	# If humans is now > total, clamp it down
	if human_players > total_players:
		human_players = total_players

	# Re-select human dropdown
	_set_human_players(human_players)

func _set_human_players(n: int) -> void:
	human_players = clampi(n, 1, total_players)

	var idx := human_option.get_item_index(human_players)
	if idx != -1:
		human_option.select(idx)

	_update_summary()


# ---------------------------
# UI updates
# ---------------------------
func _update_summary() -> void:
	var ai_players := total_players - human_players
	ai_value.text = str(ai_players)
	summary_label.text = "Humans: %d  •  AI: %d  •  Total: %d" % [human_players, ai_players, total_players]


# ---------------------------
# Signal handlers
# ---------------------------
func _on_total_selected(index: int) -> void:
	var value := total_option.get_item_id(index)
	_set_total_players(value)
	_rebuild_human_rows()
	_apply_setup_to_gamestate()



func _on_human_selected(index: int) -> void:
	var value := human_option.get_item_id(index)
	_set_human_players(value)
	_rebuild_human_rows()
	_apply_setup_to_gamestate()


func _rebuild_human_rows() -> void:
	# Ensure human_configs matches human_players length
	while human_configs.size() < human_players:
		human_configs.append({
			"name": "",
			"color": ""
		})
	while human_configs.size() > human_players:
		human_configs.pop_back()

	# Clear UI rows
	for child in humans_list.get_children():
		child.queue_free()

	# Re-create rows
	for i in range(human_players):
		var row := _create_human_row(i)
		humans_list.add_child(row)

	# After rows exist, enforce uniqueness (no duplicate names/colors)
	_apply_uniqueness_rules()
	_refresh_start_button()


func _create_human_row(player_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "HumanRow_%d" % (player_index + 1)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	# Player label
	var plabel := Label.new()
	plabel.text = "Player %d" % (player_index + 1)
	plabel.custom_minimum_size = Vector2(110, 0)
	row.add_child(plabel)

	# Name dropdown
	var name_opt := OptionButton.new()
	name_opt.name = "NameOption"
	name_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_optionbutton(name_opt, NAME_POOL, "Select Name")
	row.add_child(name_opt)
	
	var swatch := ColorRect.new()
	swatch.name = "ColorSwatch"
	swatch.custom_minimum_size = Vector2(18, 18)
	swatch.color = Color(0.25, 0.25, 0.25) # default dark
	row.add_child(swatch)

	# Color dropdown
	var color_opt := OptionButton.new()
	color_opt.name = "ColorOption"
	color_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_optionbutton(color_opt, COLOR_POOL, "Select Color")
	row.add_child(color_opt)

	# Load existing selections (if any)
	var cfg: Dictionary = human_configs[player_index]
	_select_if_present(name_opt, cfg.get("name", ""))
	_select_if_present(color_opt, cfg.get("color", ""))
	_update_swatch_from_dropdown(swatch, color_opt)

	# Wire changes to save back into human_configs
	name_opt.item_selected.connect(func(idx: int) -> void:
		human_configs[player_index]["name"] = name_opt.get_item_text(idx)
		_apply_uniqueness_rules()
		_apply_setup_to_gamestate()
		_refresh_start_button()

)

	
	
	color_opt.item_selected.connect(func(idx: int) -> void:
		human_configs[player_index]["color"] = color_opt.get_item_text(idx)
		_update_swatch_from_dropdown(swatch, color_opt)
		_apply_uniqueness_rules()
		_apply_setup_to_gamestate()
		_refresh_start_button()

)



	return row


func _fill_optionbutton(opt: OptionButton, values: Array, placeholder: String) -> void:
	opt.clear()
	opt.add_item(placeholder, -1)

	for i in range(values.size()):
		var v = values[i]
		if typeof(v) == TYPE_DICTIONARY:
			opt.add_item(str(v["label"]), i)
		else:
			opt.add_item(str(v), i)




func _select_if_present(opt: OptionButton, value: String) -> void:
	if value == "":
		opt.select(0)
		return
	for i in range(opt.item_count):
		if opt.get_item_text(i) == value:
			opt.select(i)
			return
	opt.select(0)


func _apply_uniqueness_rules() -> void:
	# Collect chosen values
	var used_names: Dictionary = {}
	var used_colors: Dictionary = {}

	for cfg in human_configs:
		var n: String = cfg.get("name", "")
		var c: String = cfg.get("color", "")
		if n != "":
			used_names[n] = true
		if c != "":
			used_colors[c] = true

	# For each row, disable options already chosen by other players
	for row in humans_list.get_children():
		if not (row is HBoxContainer):
			continue

		var name_opt: OptionButton = row.get_node("NameOption")
		var color_opt: OptionButton = row.get_node("ColorOption")

		var current_name := "" if name_opt.selected == 0 else name_opt.get_item_text(name_opt.selected)
		var current_color := "" if color_opt.selected == 0 else color_opt.get_item_text(color_opt.selected)


		# Names
		for i in range(name_opt.item_count):
			var text := name_opt.get_item_text(i)
			if i == 0:
				name_opt.set_item_disabled(i, false)
				continue

			var should_disable := used_names.has(text) and text != current_name
			name_opt.set_item_disabled(i, should_disable)

		# Colors
		for i in range(color_opt.item_count):
			var text := color_opt.get_item_text(i)
			if i == 0:
				color_opt.set_item_disabled(i, false)
				continue

			var should_disable := used_colors.has(text) and text != current_color
			color_opt.set_item_disabled(i, should_disable)
			
func _update_swatch_from_dropdown(swatch: ColorRect, opt: OptionButton) -> void:
	var sel := opt.selected
	if sel <= 0:
		swatch.color = Color(0.25, 0.25, 0.25)
		return

	var id := opt.get_item_id(sel)
	if id < 0 or id >= COLOR_POOL.size():
		swatch.color = Color(0.25, 0.25, 0.25)
		return

	swatch.color = COLOR_POOL[id]["color"]
	
func _color_label_to_index(label: String) -> int:
	for i in range(COLOR_POOL.size()):
		if COLOR_POOL[i]["label"] == label:
			return i
	return 0 # fallback (Red)

func _on_start_pressed() -> void:
	if start_button.disabled:
		return

	_apply_setup_to_gamestate()

	get_tree().change_scene_to_file("res://scenes/GameBoard.tscn")


func _on_back_pressed() -> void:
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")
	
func _is_setup_valid() -> bool:
	# Must have correct number of human configs
	if human_configs.size() != human_players:
		return false

	for cfg in human_configs:
		var n: String = str(cfg.get("name", ""))
		var c: String = str(cfg.get("color", ""))

		# Must not be blank
		if n.strip_edges() == "" or c.strip_edges() == "":
			return false

		# Must not be the placeholder
		if n == "-- Select --" or c == "-- Select --":
			return false

	return true


func _refresh_start_button() -> void:
	var ok := _is_setup_valid()
	start_button.disabled = not ok



func _apply_setup_to_gamestate() -> void:
	var humans_for_game: Array[Dictionary] = []

	for cfg in human_configs:
		humans_for_game.append({
			"name": cfg["name"],
			"color_index": _color_label_to_index(cfg["color"])
		})

	GameState.apply_setup(total_players, humans_for_game)
