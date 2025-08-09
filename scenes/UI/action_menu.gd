extends Panel

# 引用UI元素
@onready var attack_button: Button = $HBoxContainer/AttackButton
@onready var defend_button: Button = $HBoxContainer/DefendButton
@onready var skill_button: Button = $HBoxContainer/SkillButton
# @onready var item_button: Button = $HBoxContainer/ItemButton

enum ActionType {
	ATTACK,
	DEFEND,
	SKILL
}

# 信号
signal button_pressed(type: ActionType)

func _ready():
	# 连接按钮信号
	attack_button.pressed.connect(func():
		_action_menu_button_pressed(ActionType.ATTACK)
	)
	defend_button.pressed.connect(func():
		_action_menu_button_pressed(ActionType.DEFEND)
	)
	skill_button.pressed.connect(func():
		_action_menu_button_pressed(ActionType.SKILL)
	)

func _action_menu_button_pressed(type: ActionType):
	button_pressed.emit(type)