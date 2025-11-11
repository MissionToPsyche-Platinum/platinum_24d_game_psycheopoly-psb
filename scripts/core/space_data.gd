extends Node

# Space data for all 40 spaces on the board
# Space types: "property", "corner", "railroad", "utility", "tax", "card"

const SPACE_INFO = [
	# Space 0 - GO (top-right corner)
	{
		"name": "GO",
		"type": "corner",
		"description": "Collect $200 when you pass GO",
		"color": Color.WHITE
	},
	# Spaces 1-9 (right edge)
	{
		"name": "Ceres",
		"type": "property",
		"description": "Largest asteroid in the asteroid belt",
		"price": 60,
		"rent": 2,
		"color": Color(0.6, 0.4, 0.2)  # Brown
	},
	{
		"name": "Community Chest",
		"type": "card",
		"description": "Draw a Community Chest card",
		"color": Color.LIGHT_BLUE
	},
	{
		"name": "Pallas",
		"type": "property",
		"description": "Second-largest asteroid",
		"price": 60,
		"rent": 4,
		"color": Color(0.6, 0.4, 0.2)  # Brown
	},
	{
		"name": "Mission Tax",
		"type": "tax",
		"description": "Pay $200 mission tax",
		"amount": 200,
		"color": Color.WHITE
	},
	{
		"name": "Solar Panel Array",
		"type": "railroad",
		"description": "Power generation system",
		"price": 200,
		"color": Color.GRAY
	},
	{
		"name": "Vesta",
		"type": "property",
		"description": "Third-largest asteroid",
		"price": 100,
		"rent": 6,
		"color": Color(0.4, 0.7, 1.0)  # Light blue
	},
	{
		"name": "Chance",
		"type": "card",
		"description": "Draw a Chance card",
		"color": Color.ORANGE
	},
	{
		"name": "Juno",
		"type": "property",
		"description": "Fourth asteroid discovered",
		"price": 100,
		"rent": 6,
		"color": Color(0.4, 0.7, 1.0)  # Light blue
	},
	{
		"name": "Hygiea",
		"type": "property",
		"description": "Fourth-largest asteroid",
		"price": 120,
		"rent": 8,
		"color": Color(0.4, 0.7, 1.0)  # Light blue
	},
	# Space 10 - Jail/Just Visiting (bottom-right corner)
	{
		"name": "Orbital Quarantine",
		"type": "corner",
		"description": "Just visiting or in quarantine",
		"color": Color.WHITE
	},
	# Spaces 11-19 (bottom edge)
	{
		"name": "Europa",
		"type": "property",
		"description": "Jupiter's icy moon",
		"price": 140,
		"rent": 10,
		"color": Color(0.8, 0.2, 0.8)  # Magenta
	},
	{
		"name": "Ion Thruster",
		"type": "utility",
		"description": "Spacecraft propulsion system",
		"price": 150,
		"color": Color.WHITE
	},
	{
		"name": "Titan",
		"type": "property",
		"description": "Saturn's largest moon",
		"price": 140,
		"rent": 10,
		"color": Color(0.8, 0.2, 0.8)  # Magenta
	},
	{
		"name": "Enceladus",
		"type": "property",
		"description": "Saturn's geyser moon",
		"price": 160,
		"rent": 12,
		"color": Color(0.8, 0.2, 0.8)  # Magenta
	},
	{
		"name": "Deep Space Network",
		"type": "railroad",
		"description": "Communication system",
		"price": 200,
		"color": Color.GRAY
	},
	{
		"name": "16 Psyche",
		"type": "property",
		"description": "Metal-rich asteroid - NASA mission target!",
		"price": 180,
		"rent": 14,
		"color": Color(1.0, 0.6, 0.0)  # Orange
	},
	{
		"name": "Community Chest",
		"type": "card",
		"description": "Draw a Community Chest card",
		"color": Color.LIGHT_BLUE
	},
	{
		"name": "Bennu",
		"type": "property",
		"description": "Carbon-rich asteroid visited by OSIRIS-REx",
		"price": 180,
		"rent": 14,
		"color": Color(1.0, 0.6, 0.0)  # Orange
	},
	{
		"name": "Ryugu",
		"type": "property",
		"description": "Asteroid visited by Hayabusa2",
		"price": 200,
		"rent": 16,
		"color": Color(1.0, 0.6, 0.0)  # Orange
	},
	# Space 20 - Free Parking (bottom-left corner)
	{
		"name": "Lagrange Point",
		"type": "corner",
		"description": "Stable orbital position - free parking",
		"color": Color.WHITE
	},
	# Spaces 21-29 (left edge)
	{
		"name": "Phobos",
		"type": "property",
		"description": "Mars' largest moon",
		"price": 220,
		"rent": 18,
		"color": Color(1.0, 0.0, 0.0)  # Red
	},
	{
		"name": "Chance",
		"type": "card",
		"description": "Draw a Chance card",
		"color": Color.ORANGE
	},
	{
		"name": "Deimos",
		"type": "property",
		"description": "Mars' smaller moon",
		"price": 220,
		"rent": 18,
		"color": Color(1.0, 0.0, 0.0)  # Red
	},
	{
		"name": "Ida",
		"type": "property",
		"description": "Asteroid with moon Dactyl",
		"price": 240,
		"rent": 20,
		"color": Color(1.0, 0.0, 0.0)  # Red
	},
	{
		"name": "Hubble Telescope",
		"type": "railroad",
		"description": "Observation system",
		"price": 200,
		"color": Color.GRAY
	},
	{
		"name": "Eros",
		"type": "property",
		"description": "Near-Earth asteroid visited by NEAR Shoemaker",
		"price": 260,
		"rent": 22,
		"color": Color(1.0, 1.0, 0.0)  # Yellow
	},
	{
		"name": "Itokawa",
		"type": "property",
		"description": "Asteroid visited by Hayabusa",
		"price": 260,
		"rent": 22,
		"color": Color(1.0, 1.0, 0.0)  # Yellow
	},
	{
		"name": "Spectrometer",
		"type": "utility",
		"description": "Scientific analysis instrument",
		"price": 150,
		"color": Color.WHITE
	},
	{
		"name": "Apophis",
		"type": "property",
		"description": "Near-Earth asteroid",
		"price": 280,
		"rent": 24,
		"color": Color(1.0, 1.0, 0.0)  # Yellow
	},
	# Space 30 - Go to Jail (top-left corner)
	{
		"name": "Solar Storm",
		"type": "corner",
		"description": "Go directly to Orbital Quarantine",
		"color": Color.WHITE
	},
	# Spaces 31-39 (top edge)
	{
		"name": "Ganymede",
		"type": "property",
		"description": "Jupiter's largest moon",
		"price": 300,
		"rent": 26,
		"color": Color(0.0, 0.8, 0.2)  # Green
	},
	{
		"name": "Callisto",
		"type": "property",
		"description": "Jupiter's ancient moon",
		"price": 300,
		"rent": 26,
		"color": Color(0.0, 0.8, 0.2)  # Green
	},
	{
		"name": "Community Chest",
		"type": "card",
		"description": "Draw a Community Chest card",
		"color": Color.LIGHT_BLUE
	},
	{
		"name": "Io",
		"type": "property",
		"description": "Jupiter's volcanic moon",
		"price": 320,
		"rent": 28,
		"color": Color(0.0, 0.8, 0.2)  # Green
	},
	{
		"name": "James Webb Telescope",
		"type": "railroad",
		"description": "Advanced observation system",
		"price": 200,
		"color": Color.GRAY
	},
	{
		"name": "Chance",
		"type": "card",
		"description": "Draw a Chance card",
		"color": Color.ORANGE
	},
	{
		"name": "Pluto",
		"type": "property",
		"description": "Dwarf planet in the Kuiper Belt",
		"price": 350,
		"rent": 35,
		"color": Color(0.0, 0.2, 0.6)  # Dark blue
	},
	{
		"name": "Funding Cut",
		"type": "tax",
		"description": "Pay $100 budget reduction",
		"amount": 100,
		"color": Color.WHITE
	},
	{
		"name": "Arrokoth",
		"type": "property",
		"description": "Most distant object visited by spacecraft",
		"price": 400,
		"rent": 50,
		"color": Color(0.0, 0.2, 0.6)  # Dark blue
	}
]


# Get space information by space number
static func get_space_info(space_num: int) -> Dictionary:
	if space_num >= 0 and space_num < SPACE_INFO.size():
		return SPACE_INFO[space_num]
	return {}


# Check if a space is purchasable
static func is_purchasable(space_num: int) -> bool:
	var info = get_space_info(space_num)
	return info.has("type") and (info.type == "property" or info.type == "railroad" or info.type == "utility")
