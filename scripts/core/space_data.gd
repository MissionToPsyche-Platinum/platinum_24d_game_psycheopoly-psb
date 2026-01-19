extends Node

class_name SpaceData

# Space types: "property", "corner", "instrument", "planet", "cost", "card"

const SPACE_INFO = [
	# Space 0 - GO (bottom-right corner)
	{
		"type": "special",
		"name": "GO",
		"description": "Collect a $200 grant as you pass",
		"specialType": "go",
		"color": Color.GRAY
	},
	# Spaces 1-9 (bottom edge, moving left)
	{
		"type": "property",
		"name": "Hebe",
		"description": "SCIENTIFIC DATA - Research Funding $2",
		"price": 60,
		"rent": 2,
		"rent1data": 10,
		"rent2data": 30,
		"rent3data": 90,
		"rent4data": 160,
		"rentDiscovery": 250,
		"dataCost": 50,
		"mortgage": 30,
		"color": Color(1.0, 1.0, 0.0)  # Yellow
	},
	{
		"type": "card",
		"name": "Silicate",
		"description": "Draw a Silicate card",
		"cardType": "Silicate",
		"color": Color.LIGHT_BLUE
	},
	{
		"type": "property",
		"name": "Elektra",
		"description": "SCIENTIFIC DATA - Research Funding $4",
		"price": 60,
		"rent": 4,
		"rent1data": 20,
		"rent2data": 60,
		"rent3data": 180,
		"rent4data": 320,
		"rentDiscovery": 450,
		"dataCost": 50,
		"mortgage": 30,
		"color": Color(1.0, 1.0, 0.0)  # Yellow
	},
	{
		"type": "expense",
		"name": "Consult Subject Matter Expert",
		"description": "Pay $200",
		"expenseType": "pay200",
		"color": Color.GRAY
	},
	{
		"type": "instrument",
		"name": "Multispectral Imager",
		"description": "Research Funding $25",
		"price": 200,
		"rent1instrument": 25,
		"rent2instrument": 50,
		"rent3instrument": 100,
		"rent4instrument": 200,
		"mortgage": 75,	
		"color": Color.GRAY
	},
	{
		"type": "property",
		"name": "Iris",
		"description": "SCIENTIFIC DATA - Research Funding $6",
		"price": 100,
		"rent": 6,
		"rent1data": 30,
		"rent2data": 90,
		"rent3data": 270,
		"rent4data": 400,
		"rentDiscovery": 550,
		"dataCost": 50,
		"mortgage": 50,
		"color": Color(1.0, 0.65, 0.0)  # Orange
	},
	{
		"type": "card",
		"name": "Metal",
		"description": "Draw a Metal card",
		"cardType": "Metal",
		"color": Color.ORANGE
	},
	{
		"type": "property",
		"name": "Egeria",
		"description": "SCIENTIFIC DATA - Research Funding $6",
		"price": 100,
		"rent": 6,
		"rent1data": 30,
		"rent2data": 90,
		"rent3data": 270,
		"rent4data": 400,
		"rentDiscovery": 550,
		"dataCost": 50,
		"mortgage": 50,
		"color": Color(1.0, 0.65, 0.0)  # Orange
	},
	{
		"type": "property",
		"name": "Amphitrite",
		"description": "SCIENTIFIC DATA - Research Funding $8",
		"price": 120,
		"rent": 8,
		"rent1data": 40,
		"rent2data": 100,
		"rent3data": 300,
		"rent4data": 450,
		"rentDiscovery": 600,
		"dataCost": 50,
		"mortgage": 60,
		"color": Color(1.0, 0.65, 0.0)  # Orange
	},
	# Space 10 - Launch Pad (bottom-left corner)
	{
		"type": "special",
		"name": "Launch Pad",
		"description": "Just watching or launching",
		"specialType": "launchPad",
		"color": Color.GRAY
	},
	# Spaces 11-19 (left edge, moving up)
	{
		"type": "property",
		"name": "Themis",
		"description": "SCIENTIFIC DATA - Research Funding $10",
		"price": 140,
		"rent": 10,
		"rent1data": 50,
		"rent2data": 150,
		"rent3data": 450,
		"rent4data": 625,
		"rentDiscovery": 750,
		"dataCost": 100,
		"mortgage": 70,
		"color": Color(1.0, 0.4, 0.0)  # Dark orange
	},
	{
		"type": "planet",
		"name": "Mars",
		"description": "If one Planet is being studied, research funding is 4 times amount shown on dice.",
		"price": 150,
		"mult1Planet": 4,
		"mult2Planet": 10,
		"mortgage": 75,
		"color": Color(0.8, 0.3, 0.2)  # Mars red
	},
	{
		"type": "property",
		"name": "Fortuna",
		"description": "SCIENTIFIC DATA - Research Funding $10",
		"price": 140,
		"rent": 10,
		"rent1data": 50,
		"rent2data": 150,
		"rent3data": 450,
		"rent4data": 625,
		"rentDiscovery": 750,
		"dataCost": 100,
		"mortgage": 70,
		"color": Color(1.0, 0.4, 0.0)  # Dark orange
	},
	{
		"type": "property",
		"name": "Doris",
		"description": "SCIENTIFIC DATA - Research Funding $12",
		"price": 160,
		"rent": 12,
		"rent1data": 60,
		"rent2data": 180,
		"rent3data": 500,
		"rent4data": 700,
		"rentDiscovery": 900,
		"dataCost": 100,
		"mortgage": 80,
		"color": Color(1.0, 0.4, 0.0)  # Dark orange
	},
	{
		"type": "instrument",
		"name": "Gamma-Ray/Neutron Spectrometer",
		"description": "Research Funding $25",
		"price": 200,
		"rent1instrument": 25,
		"rent2instrument": 50,
		"rent3instrument": 100,
		"rent4instrument": 200,
		"mortgage": 75,	
		"color": Color.GRAY
	},
	{
		"type": "property",
		"name": "Thisbe",
		"description": "SCIENTIFIC DATA - Research Funding $14",
		"price": 180,
		"rent": 14,
		"rent1data": 70,
		"rent2data": 200,
		"rent3data": 550,
		"rent4data": 750,
		"rentDiscovery": 950,
		"dataCost": 100,
		"mortgage": 90,
		"color": Color(0.95, 0.5, 0.6)  # Pink
	},
	{
		"type": "card",
		"name": "Silicate",
		"description": "Draw a Silicate card",
		"cardType": "Silicate",
		"color": Color.LIGHT_BLUE
	},
	{
		"type": "property",
		"name": "Psyche",
		"description": "SCIENTIFIC DATA - Research Funding $14",
		"price": 180,
		"rent": 14,
		"rent1data": 70,
		"rent2data": 200,
		"rent3data": 550,
		"rent4data": 750,
		"rentDiscovery": 950,
		"dataCost": 100,
		"mortgage": 90,
		"color": Color(0.95, 0.5, 0.6)  # Pink
	},
	{
		"type": "property",
		"name": "Bamberga",
		"description": "SCIENTIFIC DATA - Research Funding $16",
		"price": 200,
		"rent": 16,
		"rent1data": 80,
		"rent2data": 220,
		"rent3data": 600,
		"rent4data": 800,
		"rentDiscovery": 1000,
		"dataCost": 100,
		"mortgage": 100,
		"color": Color(0.95, 0.5, 0.6)  # Pink
	},
	# Space 20 - Gravity Assist (top-left corner)
	{
		"type": "special",
		"name": "Gravity Assist",
		"description": "Free boost from planetary alignment",
		"specialType": "gravityAssist",
		"color": Color.GRAY
	},
	# Spaces 21-29 (top edge, moving right)
	{
		"type": "property",
		"name": "Juno",
		"description": "SCIENTIFIC DATA - Research Funding $18",
		"price": 220,
		"rent": 18,
		"rent1data": 90,
		"rent2data": 250,
		"rent3data": 700,
		"rent4data": 875,
		"rentDiscovery": 1050,
		"dataCost": 150,
		"mortgage": 110,
		"color": Color(0.8, 0.2, 0.3)  # Dark red
	},
	{
		"type": "card",
		"name": "Metal",
		"description": "Draw a Metal card",
		"cardType": "Metal",
		"color": Color.ORANGE
	},
	{
		"type": "property",
		"name": "Euphrosyne",
		"description": "SCIENTIFIC DATA - Research Funding $18",
		"price": 220,
		"rent": 18,
		"rent1data": 90,
		"rent2data": 250,
		"rent3data": 700,
		"rent4data": 875,
		"rentDiscovery": 1050,
		"dataCost": 150,
		"mortgage": 110,
		"color": Color(0.8, 0.2, 0.3)  # Dark red
	},
	{
		"type": "property",
		"name": "Eunomia",
		"description": "SCIENTIFIC DATA - Research Funding $20",
		"price": 240,
		"rent": 20,
		"rent1data": 100,
		"rent2data": 300,
		"rent3data": 750,
		"rent4data": 925,
		"rentDiscovery": 1100,
		"dataCost": 150,
		"mortgage": 120,
		"color": Color(0.8, 0.2, 0.3)  # Dark red
	},
	{
		"type": "instrument",
		"name": "Magnetometer",
		"description": "Research Funding $25",
		"price": 200,
		"rent1instrument": 25,
		"rent2instrument": 50,
		"rent3instrument": 100,
		"rent4instrument": 200,
		"mortgage": 75,	
		"color": Color.GRAY
	},
	{
		"type": "property",
		"name": "Sylvia",
		"description": "SCIENTIFIC DATA - Research Funding $22",
		"price": 260,
		"rent": 22,
		"rent1data": 110,
		"rent2data": 330,
		"rent3data": 800,
		"rent4data": 975,
		"rentDiscovery": 1150,
		"dataCost": 150,
		"mortgage": 130,
		"color": Color(0.7, 0.3, 0.7)  # Purple
	},
	{
		"type": "planet",
		"name": "Jupiter",
		"description": "If one Planet is being studied, research funding is 4 times amount shown on dice.",
		"price": 150,
		"mult1Planet": 4,
		"mult2Planet": 10,
		"mortgage": 75,
		"color": Color(0.9, 0.6, 0.3)  # Jupiter orange
	},
	{
		"type": "property",
		"name": "Davida",
		"description": "SCIENTIFIC DATA - Research Funding $22",
		"price": 260,
		"rent": 22,
		"rent1data": 110,
		"rent2data": 330,
		"rent3data": 800,
		"rent4data": 975,
		"rentDiscovery": 1150,
		"dataCost": 150,
		"mortgage": 130,
		"color": Color(0.7, 0.3, 0.7)  # Purple
	},
	{
		"type": "property",
		"name": "Europa",
		"description": "SCIENTIFIC DATA - Research Funding $24",
		"price": 280,
		"rent": 24,
		"rent1data": 120,
		"rent2data": 360,
		"rent3data": 850,
		"rent4data": 1025,
		"rentDiscovery": 1200,
		"dataCost": 150,
		"mortgage": 140,
		"color": Color(0.7, 0.3, 0.7)  # Purple
	},
	# Space 30 - Solar Storm (top-right corner)
	{
		"type": "special",
		"name": "Solar Storm",
		"description": "Go directly to Launch Pad",
		"specialType": "solarStorm",
		"color": Color.GRAY
	},
	# Spaces 31-39 (right edge, moving down)
	{
		"type": "property",
		"name": "Interamnia",
		"description": "SCIENTIFIC DATA - Research Funding $26",
		"price": 300,
		"rent": 26,
		"rent1data": 130,
		"rent2data": 390,
		"rent3data": 900,
		"rent4data": 1100,
		"rentDiscovery": 1275,
		"dataCost": 200,
		"mortgage": 150,
		"color": Color(0.5, 0.2, 0.7)  # Dark purple
	},
	{
		"type": "card",
		"name": "Silicate",
		"description": "Draw a Silicate card",
		"cardType": "Silicate",
		"color": Color.LIGHT_BLUE
	},
		{
		"type": "property",
		"name": "Hygiea",
		"description": "SCIENTIFIC DATA - Research Funding $26",
		"price": 300,
		"rent": 26,
		"rent1data": 130,
		"rent2data": 390,
		"rent3data": 900,
		"rent4data": 1100,
		"rentDiscovery": 1275,
		"dataCost": 200,
		"mortgage": 150,
		"color": Color(0.5, 0.2, 0.7)  # Dark purple
	},
	{
		"type": "property",
		"name": "Pallas",
		"description": "SCIENTIFIC DATA - Research Funding $28",
		"price": 320,
		"rent": 28,
		"rent1data": 150,
		"rent2data": 450,
		"rent3data": 1000,
		"rent4data": 1200,
		"rentDiscovery": 1400,
		"dataCost": 200,
		"mortgage": 160,
		"color": Color(0.5, 0.2, 0.7)  # Dark purple
	},
	{
		"type": "instrument",
		"name": "X-Band Radio Telecomms System",
		"description": "Research Funding $25",
		"price": 200,
		"rent1instrument": 25,
		"rent2instrument": 50,
		"rent3instrument": 100,
		"rent4instrument": 200,
		"mortgage": 75,	
		"color": Color.GRAY
	},
	{
		"type": "card",
		"name": "Metal",
		"description": "Draw a Metal card",
		"cardType": "Metal",
		"color": Color.ORANGE
	},
	{
		"type": "property",
		"name": "Vesta",
		"description": "SCIENTIFIC DATA - Research Funding $35",
		"price": 350,
		"rent": 35,
		"rent1data": 175,
		"rent2data": 500,
		"rent3data": 1100,
		"rent4data": 1300,
		"rentDiscovery": 1500,
		"dataCost": 200,
		"mortgage": 175,
		"color": Color(0.7, 0.6, 0.9)  # Light purple
	},
	{
		"type": "expense",
		"name": "Funding Cut",
		"description": "Pay $100 budget reduction",
		"expenseType": "pay100",
		"color": Color.GRAY
	},
	{
		"type": "property",
		"name": "Ceres",
		"description": "SCIENTIFIC DATA - Research Funding $50",
		"price": 400,
		"rent": 50,
		"rent1data": 200,
		"rent2data": 600,
		"rent3data": 1400,
		"rent4data": 1700,
		"rentDiscovery": 2000,
		"dataCost": 200,
		"mortgage": 200,
		"color": Color(0.7, 0.6, 0.9)  # Light purple
	}
]


static func get_space_info(index: int) -> Dictionary:
	if index >= 0 and index < SPACE_INFO.size():
		return SPACE_INFO[index]
	return {}
