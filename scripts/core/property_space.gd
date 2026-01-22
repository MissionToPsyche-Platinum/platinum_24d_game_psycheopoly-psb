extends Ownable

class_name PropertySpace

var _initial_price: int
var _default_rent: int
var _one_data_rent: int
var _two_data_rent: int
var _three_data_rent: int
var _four_data_rent: int
var _discovery_rent: int
var _upgrade_cost: int
var _mortgage_value: int

var _current_upgrades: int

func _init(data: Dictionary) -> void:
	super(data)
	_initial_price = data.get("price", 0)
	_default_rent = data.get("rent", 0)
	_one_data_rent = data.get("rent1data", 0)
	_two_data_rent = data.get("rent2data", 0)
	_three_data_rent = data.get("rent3data", 0)
	_four_data_rent = data.get("rent4data", 0)
	_discovery_rent = data.get("rentDiscovery", 0)
	_upgrade_cost = data.get("dataCost", 0)
	_mortgage_value = data.get("mortgage", 0)

	_current_upgrades = 0
