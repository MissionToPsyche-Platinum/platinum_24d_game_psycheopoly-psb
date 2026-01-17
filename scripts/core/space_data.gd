extends Node

class_name SpaceData

# Space types: "property", "corner", "instrument", "planet", "cost", "card"

const SPACE_INFO = [
	# Space 0 - GO (bottom-right corner)
	{
		"name": "GO",
		"type": "corner",
		"description": "Collect a $200 grant as you pass",
		"color": Color.GRAY
	},
	# Spaces 1-9 (bottom edge, moving left)
	{
		"name": "Hebe",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $2",
		"price": 60,
		"color": Color(1.0, 1.0, 0.0)  # Yellow
	},
	{
		"name": "Silicate",
		"type": "card",
		"description": "Draw a Silicate card",
		"color": Color.LIGHT_BLUE
	},
	{
		"name": "Elektra",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $4",
		"price": 60,
		"color": Color(1.0, 1.0, 0.0)  # Yellow
	},
	{
		"name": "Consult Subject Matter Expert",
		"type": "cost",
		"description": "Pay $200",
		"amount": 200,
		"color": Color.GRAY
	},
	{
		"name": "Multispectral Imager",
		"type": "instrument",
		"description": "Research Funding $25",
		"price": 200,
		"color": Color.GRAY
	},
	{
		"name": "Iris",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $6",
		"price": 100,
		"color": Color(1.0, 0.65, 0.0)  # Orange
	},
	{
		"name": "Metal",
		"type": "card",
		"description": "Draw a Metal card",
		"color": Color.ORANGE
	},
	{
		"name": "Egeria",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $6",
		"price": 100,
		"color": Color(1.0, 0.65, 0.0)  # Orange
	},
	{
		"name": "Amphitrite",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $8",
		"price": 120,
		"color": Color(1.0, 0.65, 0.0)  # Orange
	},
	# Space 10 - Launch Pad (bottom-left corner)
	{
		"name": "Launch Pad",
		"type": "corner",
		"description": "Just watching or launching",
		"color": Color.GRAY
	},
	# Spaces 11-19 (left edge, moving up)
	{
		"name": "Themis",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $10",
		"price": 140,
		"color": Color(1.0, 0.4, 0.0)  # Dark orange
	},
	{
		"name": "Mars",
		"type": "planet",
		"description": "If one Planet is being studied, research funding is 4 times amount shown on dice.",
		"price": 150,
		"color": Color(0.8, 0.3, 0.2)  # Mars red
	},
	{
		"name": "Fortuna",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $10",
		"price": 140,
		"color": Color(1.0, 0.4, 0.0)  # Dark orange
	},
	{
		"name": "Doris",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $12",
		"price": 160,
		"color": Color(1.0, 0.4, 0.0)  # Dark orange
	},
	{
		"name": "Gamma-Ray/Neutron Spectrometer",
		"type": "instrument",
		"description": "Research Funding $25",
		"price": 200,
		"color": Color.GRAY
	},
	{
		"name": "Thisbe",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $14",
		"price": 180,
		"color": Color(0.95, 0.5, 0.6)  # Pink
	},
	{
		"name": "Silicate",
		"type": "card",
		"description": "Draw a Silicate card",
		"color": Color.LIGHT_BLUE
	},
	{
		"name": "Psyche",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $14",
		"price": 180,
		"color": Color(0.95, 0.5, 0.6)  # Pink
	},
	{
		"name": "Bamberga",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $16",
		"price": 200,
		"color": Color(0.95, 0.5, 0.6)  # Pink
	},
	# Space 20 - Gravity Assist (top-left corner)
	{
		"name": "Gravity Assist",
		"type": "corner",
		"description": "Free boost from planetary alignment",
		"color": Color.GRAY
	},
	# Spaces 21-29 (top edge, moving right)
	{
		"name": "Juno",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $18",
		"price": 220,
		"color": Color(0.8, 0.2, 0.3)  # Dark red
	},
	{
		"name": "Metal",
		"type": "card",
		"description": "Draw a Metal card",
		"color": Color.ORANGE
	},
	{
		"name": "Euphrosyne",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $18",
		"price": 220,
		"color": Color(0.8, 0.2, 0.3)  # Dark red
	},
	{
		"name": "Eunomia",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $20",
		"price": 240,
		"color": Color(0.8, 0.2, 0.3)  # Dark red
	},
	{
		"name": "Magnetometer",
		"type": "instrument",
		"description": "Research Funding $25",
		"price": 200,
		"color": Color.GRAY
	},
	{
		"name": "Sylvia",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $22",
		"price": 260,
		"color": Color(0.7, 0.3, 0.7)  # Purple
	},
	{
		"name": "Jupiter",
		"type": "planet",
		"description": "If one Planet is being studied, research funding is 4 times amount shown on dice.",
		"price": 150,
		"color": Color(0.9, 0.6, 0.3)  # Jupiter orange
	},
	{
		"name": "Europa",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $24",
		"price": 280,
		"color": Color(0.7, 0.3, 0.7)  # Purple
	},
	{
		"name": "Sylvia",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $22",
		"price": 260,
		"color": Color(0.7, 0.3, 0.7)  # Purple
	},
	# Space 30 - Solar Storm (top-right corner)
	{
		"name": "Solar Storm",
		"type": "corner",
		"description": "Go directly to Launch Pad",
		"color": Color.GRAY
	},
	# Spaces 31-39 (right edge, moving down)
	{
		"name": "Interamnia",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $26",
		"price": 300,
		"color": Color(0.5, 0.2, 0.7)  # Dark purple
	},
	{
		"name": "Silicate",
		"type": "card",
		"description": "Draw a Silicate card",
		"color": Color.LIGHT_BLUE
	},
		{
		"name": "Hygiea",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $26",
		"price": 300,
		"color": Color(0.5, 0.2, 0.7)  # Dark purple
	},
	{
		"name": "Pallas",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $28",
		"price": 320,
		"color": Color(0.5, 0.2, 0.7)  # Dark purple
	},
	{
		"name": "X-Band Radio Telecomms System",
		"type": "instrument",
		"description": "Research Funding $25",
		"price": 200,
		"color": Color.GRAY
	},
	{
		"name": "Metal",
		"type": "card",
		"description": "Draw a Metal card",
		"color": Color.ORANGE
	},
	{
		"name": "Vesta",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $35",
		"price": 350,
		"color": Color(0.7, 0.6, 0.9)  # Light purple
	},
	{
		"name": "Funding Cut",
		"type": "cost",
		"description": "Pay $100 budget reduction",
		"amount": 100,
		"color": Color.GRAY
	},
	{
		"name": "Ceres",
		"type": "property",
		"description": "SCIENTIFIC DATA - Research Funding $50",
		"price": 400,
		"color": Color(0.7, 0.6, 0.9)  # Light purple
	}
]


static func get_space_info(index: int) -> Dictionary:
	if index >= 0 and index < SPACE_INFO.size():
		return SPACE_INFO[index]
	return {}

