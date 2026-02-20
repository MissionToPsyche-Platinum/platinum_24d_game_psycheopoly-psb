extends GameSpace

class_name RewardSpace

var _reward_type: String

func _init(data: Dictionary) -> void:
	super(data)
	_reward_type = data.get("rewardType", "")
