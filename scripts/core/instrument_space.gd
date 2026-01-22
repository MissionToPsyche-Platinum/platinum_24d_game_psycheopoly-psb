extends Ownable

class_name InstrumentSpace

var _initial_price: int
var _default_rent: int
var _two_instrument_rent: int
var _three_instrument_rent: int
var _four_instrument_rent: int
var _mortgage_value: int

func _init(data: Dictionary) -> void:
	super(data)
	_initial_price = data.get("price", 0)
	_default_rent = data.get("rent1instrument", 0)
	_two_instrument_rent = data.get("rent2instrument", 0)
	_three_instrument_rent = data.get("rent3instrument", 0)
	_four_instrument_rent = data.get("rent4instrument", 0)
	_mortgage_value = data.get("mortgage", 0)
