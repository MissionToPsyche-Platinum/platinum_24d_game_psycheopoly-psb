extends CanvasLayer

signal closed

@onready var close_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/CloseButton
@onready var rules_text: RichTextLabel = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/RulesScroll/RulesText

@onready var overview_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/OverviewButton
@onready var setup_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/SetupButton
@onready var turn_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/TurnButton
@onready var properties_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/PropertiesButton
@onready var rent_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/RentButton
@onready var auction_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/AuctionButton
@onready var trade_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/TradeButton
@onready var special_spaces_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/SpecialSpacesButton
@onready var cards_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/CardsButton
@onready var launch_pad_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/LaunchPadButton
@onready var bankruptcy_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/BankruptcyButton
@onready var winning_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/ContentHBox/SectionButtons/WinningButton

var rules_sections := {
	"overview": "[center][b]Overview[/b][/center]\n\n[b][color=#ffd166]Acquiring Asteroids[/color][/b] is a turn-based board game inspired by Monopoly and themed around NASA's Psyche mission.\n\nPlayers move around the board, [b][color=#ffd166]purchase properties[/color][/b], [b][color=#ffd166]collect rent[/color][/b], manage assets, and try to outlast the other players. The goal is to build wealth and remain in the game after all other players have gone [b][color=#ffd166]bankrupt[/color][/b].",

	"setup": "[center][b]Setup[/b][/center]\n\nBefore the game begins, players configure the match from the [b][color=#ffd166]Game Setup[/color][/b] screen.\n\nFirst, the total number of players is selected. [b][color=#ffd166]Acquiring Asteroids[/color][/b] supports between [b][color=#ffd166]2 and 6 total players[/color][/b].\n\nNext, the number of [b][color=#ffd166]human players[/color][/b] and [b][color=#ffd166]AI players[/color][/b] is chosen. The combined total of human and AI players cannot be more than [b][color=#ffd166]6[/color][/b].\n\nEach human player selects a [b][color=#ffd166]name[/color][/b] and [b][color=#ffd166]token[/color][/b]. Once setup is complete, all players are placed on the starting space with their starting money, and the game begins in [b][color=#ffd166]turn order[/color][/b].",

	"turn": "[center][b]Taking a Turn[/b][/center]\n\nOn your turn, [b][color=#ffd166]roll the dice[/color][/b] and move forward by the total rolled.\n\nAfter moving, the game resolves the effect of the space you landed on. Depending on the space, you may be able to [b][color=#ffd166]buy a property[/color][/b], [b][color=#ffd166]pay rent[/color][/b], [b][color=#ffd166]draw a card[/color][/b], pay a fee, or trigger another game event.\n\nOnce your actions are complete, your turn ends and play passes to the next player.",
	
	"properties": "[center][b]Buying Properties[/b][/center]\n\nWhen a player lands on an [b][color=#ffd166]unowned property[/color][/b] in [b][color=#ffd166]Acquiring Asteroids[/color][/b], they may choose to [b][color=#ffd166]buy it[/color][/b] for the listed cost.\n\nIf the property is purchased, ownership is assigned to that player and the cost is deducted from their balance.\n\nOwning properties allows players to [b][color=#ffd166]collect rent[/color][/b] from other players who later land on those spaces. Properties may also become more valuable through [b][color=#ffd166]upgrades[/color][/b], depending on the game rules.",

	"rent": "[center][b]Rent[/b][/center]\n\nIf a player lands on a property owned by another player, they must [b][color=#ffd166]pay rent[/color][/b].\n\nThe amount of rent depends on the property and its current [b][color=#ffd166]upgrade level[/color][/b] or ownership status. The required amount is automatically deducted from the landing player's balance and transferred to the owner.\n\nPaying rent is one of the main ways players lose money, so controlling valuable properties is an important part of the game.",

	"auction": "[center][b]Auctions[/b][/center]\n\nIf a player lands on an [b][color=#ffd166]unowned property[/color][/b] and decides not to buy it, that property may go to [b][color=#ffd166]auction[/color][/b].\n\nDuring an auction, eligible players take turns [b][color=#ffd166]bidding[/color][/b]. Each new bid must be higher than the current highest bid. Players may also choose to [b][color=#ffd166]pass[/color][/b].\n\nOnce a player passes, they are out of that auction and cannot bid again. The auction continues until only one player remains. That player wins the property and pays the final bid amount.",
	
	"trade": "[center][b]Trading[/b][/center]\n\nPlayers may [b][color=#ffd166]trade[/color][/b] with one another during the game. Trades can include properties, money, and other eligible assets.\n\nA trade is only completed if both sides [b][color=#ffd166]agree to the offer[/color][/b]. Trading can be used to complete property sets, gain needed cash, or improve a player's overall position on the board.\n\nBecause trades can greatly change the balance of the game, players should think carefully before accepting an offer.",

	"special_spaces": "[center][b]Special Spaces[/b][/center]\n\nSome spaces in [b][color=#ffd166]Acquiring Asteroids[/color][/b] have [b][color=#ffd166]special effects[/color][/b] instead of being owned like normal properties.\n\nWhen a player lands on one of these spaces, the game will immediately resolve its effect. Depending on the space, this may award money, charge a fee, draw a card, move the player, or trigger another event.\n\nSpecial spaces help keep the game unpredictable and can quickly change a player's position or finances.",

	"cards": "[center][b]Cards[/b][/center]\n\nWhen a player lands on a [b][color=#ffd166]card space[/color][/b], they [b][color=#ffd166]draw a card[/color][/b] and its effect is applied.\n\nCard effects may reward the player, charge them money, move them to a different space, or create another special situation. Some cards can help a player, while others can create setbacks.\n\nCards add randomness to the game and can change the flow of a match very quickly.",
	
	"launch_pad": "[center][b]Launch Pad[/b][/center]\n\nCertain spaces or cards can send a player to [b][color=#ffd166]Launch Pad[/color][/b].\n\nWhile in Launch Pad, a player is restricted until they meet the release condition allowed by the game. Depending on the situation, this may involve [b][color=#ffd166]paying for release[/color][/b], [b][color=#ffd166]rolling doubles[/color][/b] for release, or using a special card ([b][color=#ffd166]Go For Launch[/color][/b]) if available.\n\nOnce released, the player returns to normal play and continues taking turns as usual.",

	"bankruptcy": "[center][b]Bankruptcy[/b][/center]\n\nIf a player owes more money than they can pay, they may need to [b][color=#ffd166]sell[/color][/b] or [b][color=#ffd166]trade assets[/color][/b] in an attempt to recover enough funds.\n\nIf they still cannot pay what they owe, they must declare [b][color=#ffd166]bankruptcy[/color][/b] and be removed from the game. Any remaining assets or required payments are resolved and given to the creditor (owner of property that triggered someone's bankruptcy status).\n\nIf a card effect triggered a player's bankruptcy, then no player will receive the bankrupt player's asset(s).\n\nBankruptcy is how players are eliminated, so managing money carefully is a major part of [b][color=#ffd166]Acquiring Asteroids[/color][/b].",

	"winning": "[center][b]Winning the Game[/b][/center]\n\nThe game continues until only [b][color=#ffd166]one player remains active[/color][/b].\n\nOnce all other players have gone [b][color=#ffd166]bankrupt[/color][/b], the last remaining player is declared the winner of [b][color=#ffd166]Acquiring Asteroids[/color][/b].\n\nWinning usually requires a mix of strong property ownership, careful money management, and smart decision-making throughout the match."
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	
	close_button.pressed.connect(hide_popup)
	
	overview_button.pressed.connect(func(): _show_section("overview"))
	setup_button.pressed.connect(func(): _show_section("setup"))
	turn_button.pressed.connect(func(): _show_section("turn"))
	properties_button.pressed.connect(func(): _show_section("properties"))
	rent_button.pressed.connect(func(): _show_section("rent"))
	auction_button.pressed.connect(func(): _show_section("auction"))
	trade_button.pressed.connect(func(): _show_section("trade"))
	special_spaces_button.pressed.connect(func(): _show_section("special_spaces"))
	cards_button.pressed.connect(func(): _show_section("cards"))
	launch_pad_button.pressed.connect(func(): _show_section("launch_pad"))
	bankruptcy_button.pressed.connect(func(): _show_section("bankruptcy"))
	winning_button.pressed.connect(func(): _show_section("winning"))
	
	_show_section("overview")

func show_popup() -> void:
	visible = true
	_show_section("overview")

func hide_popup() -> void:
	visible = false
	closed.emit()
	
func _show_section(section_key: String) -> void:
	print("showing section: ", section_key)

	if not rules_sections.has(section_key):
		rules_text.text = "[center][b]Missing Section[/b][/center]\n\nNo content found."
		return
	
	rules_text.text = rules_sections[section_key]
	rules_text.scroll_to_line(0)
