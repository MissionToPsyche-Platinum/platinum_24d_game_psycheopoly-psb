extends Resource

class_name BoardSpaceList

var board: Array[GameSpace] = []


func _init() -> void:
	board = _create_board()


func _create_board() -> Array[GameSpace]:
	var result: Array[GameSpace] = []
	for i in range(SpaceData.SPACE_INFO.size()):
		var data: Dictionary = SpaceData.SPACE_INFO[i]
		var space: GameSpace
		match data.get("type", ""):
			"property":
				space = PropertySpace.new(
					data.get("name", ""),
					data.get("description",""),
					data.get("price", 0),
					0, 0, 0, 0, 0, 0, 0  # rent tiers not in SpaceData yet
				)
			"instrument", "planet":
				space = Ownable.new()
			_:
				space = GameSpace.new()
		result.append(space)
	return result


func get_space_info(space_num: int) -> Dictionary:
	if space_num >= 0 and space_num < board.size():
		return SpaceData.SPACE_INFO[space_num]
	return {}


func is_purchasable(space_num: int) -> bool:
	var info = get_space_info(space_num)
	return info.has("type") and (info.type == "property" or info.type == "instrument")
