extends Ownable

class_name InstrumentSpace

var _initial_price: int
var _default_rent: int
var _two_instrument_rent: int
var _three_instrument_rent: int
var _four_instrument_rent: int
var _mortgage_value: int

func _init(
	space_name: String,
	initial_price: int,
	default_rent: int,
	two_instrument_rent: int,
	three_instrument_rent: int,
	four_instrument_rent: int,
	mortgage_value: int
) -> void:
	_space_name = space_name
	_initial_price = initial_price
	_default_rent = default_rent
	_two_instrument_rent = two_instrument_rent
	_three_instrument_rent = three_instrument_rent
	_four_instrument_rent = four_instrument_rent
	_mortgage_value = mortgage_value
