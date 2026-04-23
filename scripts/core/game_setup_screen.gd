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
	"Nova", "Atlas", "Orion", "Vega", "Luna", "Helios", "Titan",
	"Cosmo", "Phoenix", "Voyager", "Odyssey", "Pathfinder", "Artemis"
]

# Token choices (keeps the same internal index order as the original color system)
# 0 = Red    -> Satellite
# 1 = Blue   -> Rocket
# 2 = Green  -> UFO
# 3 = Yellow -> Sun
# 4 = Orange -> Asteroid
# 5 = Purple -> Crescent Moon
const TOKEN_POOL := [
	{
		"label": "Satellite",
		"color": Color(1.00, 0.10, 0.10),
		"texture": preload("res://assets/images/sprites/satelite_game_piece.png")
	},
	{
		"label": "Rocket",
		"color": Color(0.20, 0.72, 1.00),
		"texture": preload("res://assets/images/sprites/rocket_game_piece.png")
	},
	{
		"label": "UFO",
		"color": Color(0.25, 0.80, 0.35),
		"texture": preload("res://assets/images/sprites/ufo_game_piece.png")
	},
	{
		"label": "Sun",
		"color": Color(0.95, 0.85, 0.25),
		"texture": preload("res://assets/images/sprites/sun_game_piece.png")
	},
	{
		"label": "Asteroid",
		"color": Color(1.00, 0.50, 0.00),
		"texture": preload("res://assets/images/sprites/asteroid_game_piece.png")
	},
	{
		"label": "Crescent Moon",
		"color": Color(0.60, 0.35, 0.85),
		"texture": preload("res://assets/images/sprites/cres_moon_game_piece.png")
	}
]

var total_players: int = 2
var human_players: int = 1
var human_configs: Array = []


func _ready() -> void:
	randomize()
	AudioManager.play_music("menu", 12.0, 0.15) # won't restart if already playing
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
# building the dropdown
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
			"color_id": -1,
			"token": ""
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

	# After rows exist, enforce uniqueness (no duplicate names/tokens)
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
	plabel.custom_minimum_size = Vector2(90, 0)
	row.add_child(plabel)

	# Name dropdown
	var name_opt := OptionButton.new()
	name_opt.name = "NameOption"
	name_opt.custom_minimum_size = Vector2(150, 0)
	name_opt.size_flags_horizontal = Control.SIZE_FILL
	_fill_optionbutton(name_opt, NAME_POOL, "Select Name")
	row.add_child(name_opt)

	# Token preview frame
	var preview_panel := PanelContainer.new()
	preview_panel.name = "TokenPreviewPanel"
	preview_panel.custom_minimum_size = Vector2(48, 48)
	row.add_child(preview_panel)

	var preview_texture := TextureRect.new()
	preview_texture.name = "TokenPreview"
	preview_texture.custom_minimum_size = Vector2(40, 40)
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_panel.add_child(preview_texture)

	# Token dropdown
	var token_opt := OptionButton.new()
	token_opt.name = "TokenOption"
	token_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_optionbutton(token_opt, TOKEN_POOL, "Select Token")
	row.add_child(token_opt)

	# Load existing selections (if any)
	var cfg: Dictionary = human_configs[player_index]
	_select_if_present(name_opt, cfg.get("name", ""))

	var saved_color_id: int = int(cfg.get("color_id", -1))
	var saved_token: String = str(cfg.get("token", "")).strip_edges()

	var selected_token_index := 0

	if saved_token != "":
		for i in range(1, token_opt.item_count):
			if token_opt.get_item_text(i) == saved_token:
				selected_token_index = i
				break
	elif saved_color_id >= 0:
		for i in range(1, token_opt.item_count):
			if token_opt.get_item_id(i) == saved_color_id:
				selected_token_index = i
				break

	token_opt.select(selected_token_index)

	_update_token_preview_from_dropdown(preview_texture, token_opt)

	# Wire changes to save back into human_configs
	name_opt.item_selected.connect(func(idx: int) -> void:
		if idx <= 0:
			human_configs[player_index]["name"] = ""
		else:
			human_configs[player_index]["name"] = name_opt.get_item_text(idx)

		_apply_uniqueness_rules()
		_apply_setup_to_gamestate()
		_refresh_start_button()
	)

	token_opt.item_selected.connect(func(idx: int) -> void:
		var selected_id := token_opt.get_item_id(idx)

		if idx <= 0 or selected_id < 0:
			human_configs[player_index]["color_id"] = -1
			human_configs[player_index]["token"] = ""
		else:
			human_configs[player_index]["color_id"] = selected_id
			human_configs[player_index]["token"] = token_opt.get_item_text(idx).strip_edges()

		_update_token_preview_from_dropdown(preview_texture, token_opt)
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
	var used_color_ids: Dictionary = {}

	for cfg in human_configs:
		var n: String = str(cfg.get("name", "")).strip_edges()
		var cid: int = int(cfg.get("color_id", -1))

		if n != "":
			used_names[n] = true
		if cid >= 0:
			used_color_ids[cid] = true

	# For each row, disable options already chosen by other players
	for row in humans_list.get_children():
		if not (row is HBoxContainer):
			continue

		var name_opt: OptionButton = row.get_node("NameOption")
		var token_opt: OptionButton = row.get_node("TokenOption")

		var current_name := ""
		if name_opt.selected > 0:
			current_name = name_opt.get_item_text(name_opt.selected).strip_edges()

		var current_color_id := -1
		if token_opt.selected > 0:
			current_color_id = token_opt.get_item_id(token_opt.selected)

		# Names
		for i in range(name_opt.item_count):
			if i == 0:
				name_opt.set_item_disabled(i, false)
				continue

			var text := name_opt.get_item_text(i).strip_edges()
			var should_disable := used_names.has(text) and text != current_name
			name_opt.set_item_disabled(i, should_disable)

		# Tokens (still uses internal color_id indexes, since Jay colored the tokens nicely)
		for i in range(token_opt.item_count):
			if i == 0:
				token_opt.set_item_disabled(i, false)
				continue

			var id := token_opt.get_item_id(i)
			var should_disable := used_color_ids.has(id) and id != current_color_id
			token_opt.set_item_disabled(i, should_disable)


func _update_token_preview_from_dropdown(preview: TextureRect, opt: OptionButton) -> void:
	var sel := opt.selected
	if sel <= 0:
		preview.texture = null
		return

	var id := opt.get_item_id(sel)
	if id < 0 or id >= TOKEN_POOL.size():
		preview.texture = null
		return

	preview.texture = TOKEN_POOL[id]["texture"]


func _color_label_to_index(label: String) -> int:
	for i in range(TOKEN_POOL.size()):
		if TOKEN_POOL[i]["label"] == label:
			return i
	return 0 # fallback


func _on_start_pressed() -> void:
	if start_button.disabled:
		return

	_apply_setup_to_gamestate()

	get_tree().change_scene_to_file("res://scenes/GameBoard.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")


func _is_setup_valid() -> bool:
	# Must have correct number of human configs
	if human_configs.size() != human_players:
		return false

	for cfg in human_configs:
		var n: String = str(cfg.get("name", "")).strip_edges()
		var color_id: int = int(cfg.get("color_id", -1))

		# Name must be selected
		if n == "":
			return false

		# Token must be selected (still stored as color_id internally)
		if color_id < 0:
			return false

	return true


func _refresh_start_button() -> void:
	var ok := _is_setup_valid()
	start_button.disabled = not ok


func _apply_setup_to_gamestate() -> void:
	var humans_for_game: Array[Dictionary] = []

	for cfg in human_configs:
		humans_for_game.append({
			"name": str(cfg.get("name", "")).strip_edges(),
			"color_index": int(cfg.get("color_id", -1)),
			"token": str(cfg.get("token", "")).strip_edges()
		})

	var ai_names: Array[String] = []
	var used_names := _collect_used_human_names()
	var ai_count := total_players - human_players

	for i in range(ai_count):
		var ai_name := _get_random_ai_name(used_names)
		ai_names.append(ai_name)
		used_names.append(ai_name)

	GameState.apply_setup(total_players, humans_for_game, ai_names)
	print("APPLY SETUP -> total:", total_players, " humans_for_game:", humans_for_game, " ai_names:", ai_names)


func _collect_used_human_names() -> Array[String]:
	var used_names: Array[String] = []

	for cfg in human_configs:
		var chosen_name := str(cfg.get("name", "")).strip_edges()
		if chosen_name != "" and not used_names.has(chosen_name):
			used_names.append(chosen_name)

	return used_names


func _get_random_ai_name(used_names: Array[String]) -> String:
	var available_names: Array[String] = []

	for base_name in NAME_POOL:
		var ai_display_name := "%s (AI)" % base_name
		if not used_names.has(base_name) and not used_names.has(ai_display_name):
			available_names.append(base_name)

	if available_names.is_empty():
		var counter := 1
		while true:
			var fallback_base := "CPU %d" % counter
			var fallback_display := "%s (AI)" % fallback_base
			if not used_names.has(fallback_base) and not used_names.has(fallback_display):
				return fallback_display
			counter += 1

	var chosen_base := available_names[randi() % available_names.size()]
	return "%s (AI)" % chosen_base
