extends Resource

class_name BoardSpaceList

var board: Array[GameSpace] = []


func _init() -> void:
	board = _create_board()


static func _create_board() -> Array[GameSpace]:
	var result: Array[GameSpace] = []
	for i in range(SpaceData.SPACE_INFO.size()):
		var data: Dictionary = SpaceData.SPACE_INFO[i]
		var space: GameSpace
		match data.get("type", ""):
			"property":
				space = PropertySpace.new(data)
			"instrument":
				space = InstrumentSpace.new(data)
			"planet":
				space = PlanetSpace.new(data)
			"card":
				space = CardSpace.new(data)
			"cost":
				space = ExpenseSpace.new(data)
			"corner":
				space = SpecialSpace.new(data)
			_:
				space = GameSpace.new()
		result.append(space)
	return result


static func get_space_info(space_num: int) -> Dictionary:
	if space_num >= 0 and space_num < SpaceData.SPACE_INFO.size():
		return SpaceData.SPACE_INFO[space_num]
	return {}


static func is_purchasable(space_num: int) -> bool:
	var info = get_space_info(space_num)
	return info.has("type") and (info.type == "property" or info.type == "instrument" or info.type == "planet")
