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
				space = PropertySpace.new(
					data.get("name", ""),
					data.get("description",""),
					data.get("price", 0),
					data.get("rent", 0),
					data.get("rent1data", 0),
					data.get("rent2data", 0),
					data.get("rent3data", 0),
					data.get("rent4data", 0),
					data.get("rentDiscovery", 0),
					data.get("dataCost", 0),
					data.get("mortgage", 0),
					data.get("color", Color.BLACK)
					)
			"instrument":
				space = InstrumentSpace.new(
					data.get("name"),
					data.get("description",""),
					data.get("price", 0),
					data.get("rent1instrument", 0),
					data.get("rent2instrument", 0),
					data.get("rent3instrument", 0),
					data.get("rent4instrument", 0),
					data.get("mortgage", 0),
					data.get("color", Color.BLACK)
					)
			"planet":
				space = PlanetSpace.new(
					data.get("name"),
					data.get("description",""),
					data.get("price", 0),
					data.get("mult1Planet", 0),
					data.get("mult2Planet", 0),
					data.get("mortgage", 0),
					data.get("color", Color.BLACK)
				)
			"card":
				space = CardSpace.new(
					data.get("name"),
					data.get("description", ""),
					data.get("cardType", ""),
					data.get("color", Color.BLACK)
				)
			"cost":
				space = ExpenseSpace.new(
					data.get("name"),
					data.get("description", ""),
					data.get("expenseType", ""),
					data.get("color", Color.BLACK)
				)
			"corner":
				space = SpecialSpace.new(
					data.get("name"),
					data.get("description", ""),
					data.get("specialType", ""),
					data.get("color", Color.BLACK)
				)
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
