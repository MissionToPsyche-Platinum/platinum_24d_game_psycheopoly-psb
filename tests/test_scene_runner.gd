extends Node

const RollDiceUI := preload("res://scripts/ui/roll_dice_ui.gd")

var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("=== Psyche-opoly Automated Tests START ===")

	test_dice_range()

	print("=== Psyche-opoly Automated Tests END ===")
	print("Passed: %d | Failed: %d" % [tests_passed, tests_failed])


func assert_true(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
		# No print on success to avoid output overflow, was getting errors before
	else:
		tests_failed += 1
		push_error("FAIL: " + message)


func test_dice_range() -> void:
	print("--- Running test_dice_range ---")

	# Using the dice logic from roll_dice_ui.gd
	var dice_ui := RollDiceUI.new()
	dice_ui.rng.randomize() 

	var iterations: int = 500  # Can adjust number of tests here

	for i in range(iterations):
		var r: Dictionary = dice_ui.roll_dice()
		var d1: int = r["d1"]
		var d2: int = r["d2"]
		var total: int = r["total"]

		assert_true(d1 >= 1 and d1 <= 6,
			"Die 1 in range [1,6] (got %d)" % d1)
		assert_true(d2 >= 1 and d2 <= 6,
			"Die 2 in range [1,6] (got %d)" % d2)
		assert_true(total >= 2 and total <= 12,
			"Total in range [2,12] (got %d)" % total)

	print("Dice range test finished for %d rolls." % iterations)
