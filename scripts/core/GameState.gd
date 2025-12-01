extends Node

var board: Array[GameSpace] = [] # contains all of the properties and game spaces on the board
var spaces_list := BoardSpaceList.new() # fetches all of the game spaces from the resource

var PLAYER_COUNT = 4 # temporary, eventually we want to be able to set this before a game starts
var players: Array[PlayerState] = []


# places all of the properties onto the board
func _setUpBoard() -> void:
	board = spaces_list.board

func _setUpPlayers() -> void:
	for i in range(PLAYER_COUNT):
		players.append(PlayerState.new())
		add_child(players[i])
		players[i].balance = 1500 # temporary, change to constant (or however we choose to initialize values) in future


# changes the ownership of an ownable property
func _transferProperty(property:Ownable, player:int) -> void:
	if (property._is_owned == false):
		property._is_owned = true
	property._player_owner = player

# adjusts balances of the player in the purchase and transfers ownership of a property. Used for when the player purchases an unowned property
func _purchaseUnownedProperty(property:Ownable, player:int, purchase_price:int) -> void:
	players[player].balance -= purchase_price
	_transferProperty(property, player)

# adjusts balances of the player in the purchase and transfers ownership of a property. Used for any transaction where the player purchases an already owned property
func _purchaseOwnedProperty(property:Ownable, buyer:int, seller:int, purchase_price:int) -> void:
	players[buyer].balance -= purchase_price
	players[seller].balance += purchase_price
	_transferProperty(property, buyer)	




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setUpBoard()
	_setUpPlayers()
	
	# temporarily test the purchasing of properties
	#print(board[0]._player_owner) 
	#print(players[1].balance) 

	#_purchaseUnownedProperty(board[0], 1, board[0]._initial_price)
	#print(board[0]._player_owner) 
	#print(players[1].balance) 


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
