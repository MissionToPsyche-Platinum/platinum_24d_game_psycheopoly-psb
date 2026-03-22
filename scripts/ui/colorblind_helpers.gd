extends RefCounted
class_name ColorblindHelpers

static var SYMBOL_TEXTURES := {
	"Yellow": preload("res://assets/images/circle.png"),        # circle
	"Orange": preload("res://assets/images/star.png"),          # star
	"Dark Orange": preload("res://assets/images/diamond.png"),  # diamond
	"Pink": preload("res://assets/images/pentagon.png"),        # pentagon
	"Dark Red": preload("res://assets/images/triangle.png"),    # triangle
	"Purple": preload("res://assets/images/square.png"),        # square
	"Dark Purple": preload("res://assets/images/cross.png"),    # cross
	"Light Purple": preload("res://assets/images/hex.png")      # hex
}

static var COLORBLIND_SYMBOL_SPACES := {
	1: "Light Purple",
	3: "Light Purple",

	6: "Dark Red",
	8: "Dark Red",
	9: "Dark Red",

	11: "Purple",
	13: "Purple",
	14: "Purple",

	16: "Orange",
	18: "Orange",
	19: "Orange",

	21: "Pink",
	23: "Pink",
	24: "Pink",

	26: "Dark Purple",
	28: "Dark Purple",
	29: "Dark Purple",

	31: "Yellow",
	33: "Yellow",
	34: "Yellow",

	37: "Dark Orange",
	39: "Dark Orange"
}

static func get_symbol_texture_for_set(set_name: String) -> Texture2D:
	if not SettingsManager.is_colorblind_enabled():
		return null

	if SYMBOL_TEXTURES.has(set_name):
		return SYMBOL_TEXTURES[set_name]

	return null

static func get_symbol_texture_for_space(space_index: int) -> Texture2D:
	if not SettingsManager.is_colorblind_enabled():
		return null

	if not COLORBLIND_SYMBOL_SPACES.has(space_index):
		return null

	var symbol_group := str(COLORBLIND_SYMBOL_SPACES[space_index])

	if SYMBOL_TEXTURES.has(symbol_group):
		return SYMBOL_TEXTURES[symbol_group]

	return null

static func get_symbol_group_for_space(space_index: int) -> String:
	return COLORBLIND_SYMBOL_SPACES.get(space_index, "")

static func get_symbol_text_for_space(space_index: int) -> String:
	var group := get_symbol_group_for_space(space_index)

	match group:
		"Yellow":
			return "○"   # circle
		"Orange":
			return "✶"   # star
		"Dark Orange":
			return "◆"   # diamond
		"Pink":
			return "⬟"   # pentagon
		"Dark Red":
			return "▲"   # triangle
		"Purple":
			return "■"   # square
		"Dark Purple":
			return "✚"   # cross
		"Light Purple":
			return "⬢"   # hexagon
		_:
			return ""
