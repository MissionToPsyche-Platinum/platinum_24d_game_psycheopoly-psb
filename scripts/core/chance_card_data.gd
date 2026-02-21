extends Node


class_name ChanceCards



const CHANCE_CARD_INFO = [
	#Cards 1-18 are Metal Cards, causing earning or paying money
	{
		"card number": 0,
		"type": "Metal",
		"description": "Successful mission launch! ",
		"effect": "You will earn $",
		"value": 200,
		"functionalValue": 200,
		"movementValue": -1
	},
	{
		"card number": 1,
		"type": "Metal",
		"description": "Successfully detect Psyche's remnant
						magnetic field with the Magnetometer! ",
		"effect": "You will earn $",
		"value": 150,
		"functionalValue": 150,
		"movementValue": -1
	},
	{
		"card number": 2,
		"type": "Metal",
		"description": "Successfully determine the 
						conditions Psyche formed under!",
		"effect": "You will earn $",
		"value": 100,
		"functionalValue": 100,
		"movementValue": -1
	},
	{
		"card number": 3,
		"type": "Metal",
		"description": "Successfully determine that
						Psyche is a planet core!",
		"effect": "You will earn $",
		"value": 100,
		"functionalValue": 100,
		"movementValue": -1
	},
	{
		"card number": 4,
		"type": "Metal",
		"description": "Successful arrival at the Psyche asteroid!",
		"effect": "You will earn $",
		"value": 100,
		"functionalValue": 100,
		"movementValue": -1
	},
	{
		"card number": 5,
		"type": "Metal",
		"description": "We've got Taters!
						Successfully demonstrate high-bandwidth
						communications in deep space for
						the first time!",
		"effect": "You will earn $",
		"value": 50,
		"functionalValue": 50,
		"movementValue": -1
	},
	{
		"card number": 6,
		"type": "Metal",
		"description": "Successful slingshot maneuver!",
		"effect": "You will earn $",
		"value": 50,
		"functionalValue": 50,
		"movementValue": -1
	},
	{
		"card number": 7,
		"type": "Metal",
		"description": "Successfully measure Psyche's gravity field
						with the X-band radio 
						telecommunications system!",
		"effect": "You will earn $",
		"value": 25,
		"functionalValue": 25,
		"movementValue": -1
	},
	{
		"card number": 8,
		"type": "Metal",
		"description": "Successfully determine the light elements
						that small metal bodies incorporate!",
		"effect": "You will earn $",
		"value": 25,
		"functionalValue": 25,
		"movementValue": -1
	},
	{
		"card number": 9,
		"type": "Metal",
		"description": "Successfully determine the relative
						ages of regions of Psyche's surface!",
		"effect": "You will earn $",
		"value": 10,
		"functionalValue": 10,
		"movementValue": -1
	},
	{
		"card number": 10,
		"type": "Metal",
		"description": "Incomplete verification and validation
						of spacecraft's systems. 
						Pay $100 for the systems engineers 
						to complete the work.",
		"effect": "You will pay $",
		"value": 100,
		"functionalValue": 100,
		"movementValue": -1
	},
	{
		"card number": 11,
		"type": "Metal",
		"description": "Space weather disrupts satellite operations.
						Pay $50 to enter safe mode. ",
		"effect": "You will pay $",
		"value": 50,
		"functionalValue": 50,
		"movementValue": -1
	},
	{
		"card number": 12,
		"type": "Metal",
		"description": "Collision with space debris damages
						the Multispectral Imager.
						Pay $50 to activate the secondary camera.",
		"effect": "You will pay $",
		"value": 50,
		"functionalValue": 50,
		"movementValue": -1
	},
	{
		"card number": 13,
		"type": "Metal",
		"description": "Instrument malfunction. 
						Pay $15 for the software engineers
						to resolve the issue.",
		"effect": "You will pay $",
		"value": 15,
		"functionalValue": 15,
		"movementValue": -1
	},
	{
		"card number": 14,
		"type": "Metal",
		"description": "Unresolved software issues cause a 
						launch delay. Pay each player $50 to
						reschedule their travel plans.",
		"effect": "You will pay $",
		"value": "", #50 * NumPlayers , increase money of other players
		"functionalValue": 0,
		"movementValue": -1
	},
	{
		"card number": 15,
		"type": "Metal",
		"description": "Successfully characterize Psyche's topography!
						Collect $10 from every player 
						to share your findings.",
		"effect": "You will earn $",
		"value": "", #10 * NumPlayers , reduce money of other players
		"functionalValue": 0,
		"movementValue": -1
	},
	{
		"card number": 16,
		"type": "Metal",
		"description": "Pay research assistants 
						to clean up your data.
						For each Data Point pay $45.
						For each discovery pay $120.",
		"effect": "You will pay $",
		"value": "", #(45 * NumDataPoints)+(120 * NumDiscoveries)
		"functionalValue": 0,
		"movementValue": -1
	},
	{
		"card number": 17,
		"type": "Metal",
		"description": "Submit your article to a journal.
						For each Data Point pay $25. 
						For each discovery pay $100. ",
		"effect": "You will pay $",
		"value": "", #(25 * NumDataPoints)+(100 * NumDiscoveries)
		"functionalValue": 0,
		"movementValue": -1
	},
	
	
	#Cards 19-36 are Silicate Cards, involving movement and spaces
	{
		"card number": 18,
		"type": "Silicate",
		"description": "Advance to Ceres. 
						If you pass Go, collect $200",
		"effect": "You will move to ",
		"value": "Ceres",
		"functionalValue": 0,
		"movementValue": 39
	},
	{
		"card number": 19,
		"type": "Silicate",
		"description": "Advance to Eunomia. 
						If you pass Go, collect $200",
		"effect": "You will move to ",
		"value": "Eunomia",
		"functionalValue": 0,
		"movementValue": 24
	},
	{
		"card number": 20,
		"type": "Silicate",
		"description": "Advance to Themis. 
						If you pass Go, collect $200",
		"effect": "You will move to ",
		"value": "Themis",
		"functionalValue": 0,
		"movementValue": 11
	},
	{
		"card number": 21,
		"type": "Silicate",
		"description": "Advance to Amphitrite. 
						If you pass Go, collect $200",
		"effect": "You will move to ",
		"value": "Amphitrite",
		"functionalValue": 0,
		"movementValue": 9
	},
	{
		"card number": 22,
		"type": "Silicate",
		"description": "Advance to Elektra. 
						If you pass Go, collect $200",
		"effect": "You will move to ",
		"value": "Elektra",
		"functionalValue": 0,
		"movementValue": 3
	},
	{
		"card number": 23,
		"type": "Silicate",
		"description": "Advance to Hygiea. 
						If you pass Go, collect $200",
		"effect": "You will move to ",
		"value": "Hygiea",
		"functionalValue": 0,
		"movementValue": 33
	},
	{
		"card number": 24,
		"type": "Silicate",
		"description": "Advance to Iris. 
						If you pass Go, collect $200",
		"effect": "You will move to ",
		"value": "Iris",
		"functionalValue": 0,
		"movementValue": 6
	},
	{
		"card number": 25,
		"type": "Silicate",
		"description": "Advance to Psyche. 
						If you pass Go, collect $200",
		"effect": "You will move to ",
		"value": "Psyche",
		"functionalValue": 0,
		"movementValue": 18
	},
	{
		"card number": 26,
		"type": "Silicate",
		"description": "Advance to Go. 
						(Collect $200)",
		"effect": "You will move to ",
		"value": "Go",
		"functionalValue": 0,
		"movementValue": 0
	},
	{
		"card number": 27,
		"type": "Silicate",
		"description": "Advance to Go. 
						(Collect $200)",
		"effect": "You will move to ",
		"value": "Go",
		"functionalValue": 0,
		"movementValue": 0
	},
	{
		"card number": 28,
		"type": "Silicate",
		"description": "Advance to the nearest Scientific Instrument. 
						If unstudied, you may buy the scientific data. 
						
						If it has already been studied, 
						pay the scientist twice the research funding
						to which they are otherwise entitled.",
		"effect": 	"You will move to the 
					nearest Scientific Instrument",
		"value": "",
		"functionalValue": 0,
		"movementValue": -1
	},
	{
		"card number": 29,
		"type": "Silicate",
		"description": "Advance to the nearest Scientific Instrument. 
						If unstudied, you may buy the scientific data. 
						
						If it has already been studied, 
						pay the scientist twice the research funding
						to which they are otherwise entitled.",
		"effect": 	"You will move to the
					nearest Scientific Instrument",
		"value": "",
		"functionalValue": 0,
		"movementValue": -1
	},
	{
		"card number": 30,
		"type": "Silicate",
		"description": "Advance to the nearest Planet. 
						If unstudied, you may buy the scientific data. 
						
						If it has already been studied, 
						roll the dice and pay the scientist a total 
						ten times the amount rolled.",
		"effect": "You will move to ",
		"value": "the nearest Planet",
		"functionalValue": 0,
		"movementValue": -1
	},
	{
		"card number": 31,
		"type": "Silicate",
		"description": "Go back 3 spaces",
		"effect": "You will move back ",
		"value": "3 spaces",
		"functionalValue": 0,
		"movementValue": -3
	},
	{
		"card number": 32,
		"type": "Silicate",
		"description": "Go to the Launch Pad. 
						
						Go directly to the Launch Pad, 
						do not pass Go, do not collect $200",
		"effect": "You will move to ",
		"value": "the Launch Pad",
		"functionalValue": 0,
		"movementValue": 10
	},
	{
		"card number": 33,
		"type": "Silicate",
		"description": "Go to the Launch Pad. 
						
						Go directly to the Launch Pad, 
						do not pass Go, do not collect $200",
		"effect": "You will move to ",
		"value": "the Launch Pad",
		"functionalValue": 0,
		"movementValue": 10
	},
	{
		"card number": 34,
		"type": "Silicate",
		"description": "Go for launch! 
						Get off the Launch Pad for free. 
						
						Keep this card for later use. 
						This card may be traded.",
		"effect": "You will be able to escape ",
		"value": "the Launch Pad",
		"functionalValue": 0,
		"movementValue": -1
	},
	{
		"card number": 35,
		"type": "Silicate",
		"description": "Go for launch! 
						Get off the Launch Pad for free. 
						
						Keep this card for later use. 
						This card may be traded.",
		"effect": "You will be able to escape ",
		"value": "the Launch Pad",
		"functionalValue": 0,
		"movementValue": -1
	}
]


## Returns information for a chance card at the given index.
## @param index Zero-based index into the CHANCE_CARD_INFO array.
## @return A Dictionary containing the card's data, or an empty Dictionary if the index is out of range.
static func get_card_info(index: int) -> Dictionary:
	if index >= 0 and index < CHANCE_CARD_INFO.size():
		return CHANCE_CARD_INFO[index]
	return {}
