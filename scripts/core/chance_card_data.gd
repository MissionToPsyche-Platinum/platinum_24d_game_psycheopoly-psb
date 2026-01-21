extends Node


class_name ChanceCards



const CHANCE_CARD_INFO = [
	#Cards 1-18 are Metal Cards, causing earning or paying money
	{
		"card number": 1,
		"type": "Metal",
		"description": "We've got Taters!
						Successfully demonstrate high-bandwidth
						communications in deep space for
						the first time!",
		"effect": "earn $",
		"value": 50
	},
	{
		"card number": 2,
		"type": "Metal",
		"description": "Submit your article to a journal.
						For each Data Point pay $25. 
						For each discovery pay $100. ",
		"effect": "pay $",
		"value": "" #(25 * NumDataPoints)+(100 * NumDiscoveries)
	},
	{
		"card number": 3,
		"type": "Metal",
		"description": "Instrument malfunction. 
						Pay $15 for the software engineers
						to resolve the issue.",
		"effect": "pay $",
		"value": 15
	},
	{
		"card number": 4,
		"type": "Metal",
		"description": "Unresolved software issues cause a 
						launch delay. Pay each player $50 to
						reschedule their travel plans.",
		"effect": "pay $",
		"value": "" #50 * NumPlayers
	},
	{
		"card number": 5,
		"type": "Metal",
		"description": "Successfully detect Psyche's remnant
						magnetic field with the Magnetometer! ",
		"effect": "earn $",
		"value": 150
	},
	{
		"card number": 6,
		"type": "Metal",
		"description": "Successfully determine that
						Psyche is a planet core!",
		"effect": "earn $",
		"value": 100
	},
	{
		"card number": 7,
		"type": "Metal",
		"description": "Successful mission launch! ",
		"effect": "earn $",
		"value": 200
	},
	{
		"card number": 8,
		"type": "Metal",
		"description": "Space weather disrupts satellite operations.
						Pay $50 to enter safe mode. ",
		"effect": "pay $",
		"value": 50
	},
	{
		"card number": 9,
		"type": "Metal",
		"description": "Successful slingshot maneuver!",
		"effect": "earn $",
		"value": 50
	},
	{
		"card number": 10,
		"type": "Metal",
		"description": "Successful arrival at the Psyche asteroid!",
		"effect": "earn $",
		"value": 100
	},
	{
		"card number": 11,
		"type": "Metal",
		"description": "Successfully measure Psyche's gravity field
						with the X-band radio 
						telecommunications system!",
		"effect": "earn $",
		"value": 25
	},
	{
		"card number": 12,
		"type": "Metal",
		"description": "Successfully characterize Psyche's topography!
						Collect $10 from every player 
						to share your findings.",
		"effect": "earn $",
		"value": "" #10 * NumPlayers , reduce money of other players
	},
	{
		"card number": 13,
		"type": "Metal",
		"description": "Successfully determine the 
						conditions Psyche formed under!",
		"effect": "earn $",
		"value": 100
	},
	{
		"card number": 14,
		"type": "Metal",
		"description": "Incomplete verification and validation
						of spacecraft's systems. 
						Pay $100 for the systems engineers 
						to complete the work.",
		"effect": "pay $",
		"value": 100
	},
	{
		"card number": 15,
		"type": "Metal",
		"description": "Collision with space debris damages
						the Multispectral Imager.
						Pay $50 to activate the secondary camera.",
		"effect": "pay $",
		"value": 50
	},
	{
		"card number": 16,
		"type": "Metal",
		"description": "Successfully determine the light elements
						that small metal bodies incorporate!",
		"effect": "earn $",
		"value": 25
	},
	{
		"card number": 17,
		"type": "Metal",
		"description": "Pay research assistants 
						to clean up your data.
						For each Data Point pay $45.
						For each discovery pay $120.",
		"effect": "pay $",
		"value": "" #(45 * NumDataPoints)+(120 * NumDiscoveries)
	},
	{
		"card number": 18,
		"type": "Metal",
		"description": "Successfully determine the relative
						ages of regions of Psyche's surface!",
		"effect": "earn $",
		"value": 10
	},
	#Cards 19-36 are Silicate Cards, involving movement and spaces
	{
		"card number": 19,
		"type": "Silicate",
		"description": "Advance to Ceres. 
						If you pass Go, collect $200",
		"effect": "move to ",
		"value": "Ceres"
	},
	{
		"card number": 20,
		"type": "Silicate",
		"description": "Advance to Eunomia. 
						If you pass Go, collect $200",
		"effect": "move to ",
		"value": "Eunomia"
	},
	{
		"card number": 21,
		"type": "Silicate",
		"description": "Advance to Themis. 
						If you pass Go, collect $200",
		"effect": "move to ",
		"value": "Themis"
	},
	{
		"card number": 22,
		"type": "Silicate",
		"description": "Advance to Themis. 
						If you pass Go, collect $200",
		"effect": "move to ",
		"value": "Themis"
	},
	{
		"card number": 23,
		"type": "Silicate",
		"description": "Advance to Elektra. 
						If you pass Go, collect $200",
		"effect": "move to ",
		"value": "Elektra"
	},
	{
		"card number": 24,
		"type": "Silicate",
		"description": "Advance to Hygiea. 
						If you pass Go, collect $200",
		"effect": "move to ",
		"value": "Hygiea"
	},
	{
		"card number": 25,
		"type": "Silicate",
		"description": "Advance to Iris. 
						If you pass Go, collect $200",
		"effect": "move to ",
		"value": "Iris"
	},
	{
		"card number": 26,
		"type": "Silicate",
		"description": "Advance to Psyche. 
						If you pass Go, collect $200",
		"effect": "move to ",
		"value": "Psyche"
	},
	{
		"card number": 27,
		"type": "Silicate",
		"description": "Advance to Go. 
						(Collect $200)",
		"effect": "move to ",
		"value": "Go"
	},
	{
		"card number": 28,
		"type": "Silicate",
		"description": "Advance to Go. 
						(Collect $200)",
		"effect": "move to ",
		"value": "Go"
	},
	{
		"card number": 29,
		"type": "Silicate",
		"description": "Advance to the nearest Scientific Instrument. 
						If unstudied, you may buy the scientific data. 
						If it has already been studied, 
						pay the scientist twice the research funding
						to which they are otherwise entitled.",
		"effect": "move to ",
		"value": "the nearest Scientific Instrument"
	},
	{
		"card number": 30,
		"type": "Silicate",
		"description": "Advance to the nearest Scientific Instrument. 
						If unstudied, you may buy the scientific data. 
						If it has already been studied, 
						pay the scientist twice the research funding
						to which they are otherwise entitled.",
		"effect": "move to ",
		"value": "the nearest Scientific Instrument"
	},
	{
		"card number": 31,
		"type": "Silicate",
		"description": "Advance to the nearest Planet. 
						If unstudied, you may buy the scientific data. 
						If it has already been studied, 
						roll the dice and pay the scientist a total 
						ten times the amount rolled.",
		"effect": "move to ",
		"value": "the nearest Planet"
	},
	{
		"card number": 32,
		"type": "Silicate",
		"description": "Go back 3 spaces",
		"effect": "move back ",
		"value": "3 spaces"
	},
	{
		"card number": 33,
		"type": "Silicate",
		"description": "Go to the Launch Pad. 
						Go directly to the Launch Pad, 
						do not pass Go, do not collect $200",
		"effect": "move to ",
		"value": "the Launch Pad"
	},
	{
		"card number": 34,
		"type": "Silicate",
		"description": "Go to the Launch Pad. 
						Go directly to the Launch Pad, 
						do not pass Go, do not collect $200",
		"effect": "move to ",
		"value": "the Launch Pad"
	},
	{
		"card number": 35,
		"type": "Silicate",
		"description": "Go for launch! 
						Get off the Launch Pad for free. 
						Keep this card for later use. 
						This card may be traded.",
		"effect": "be able to escape ",
		"value": "the Launch Pad"
	},
	{
		"card number": 36,
		"type": "Silicate",
		"description": "Go for launch! 
						Get off the Launch Pad for free. 
						Keep this card for later use. 
						This card may be traded.",
		"effect": "be able to escape ",
		"value": "the Launch Pad"
	}
]


## Returns information for a chance card at the given index.
## @param index Zero-based index into the CHANCE_CARD_INFO array.
## @return A Dictionary containing the card's data, or an empty Dictionary if the index is out of range.
static func get_card_info(index: int) -> Dictionary:
	if index >= 0 and index < CHANCE_CARD_INFO.size():
		return CHANCE_CARD_INFO[index]
	return {}
