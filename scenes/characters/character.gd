extends Node2D
class_name Character

@export var character_data: CharacterData
@export var maximum_hp: int

# 运行时从CharacterData初始化的核心战斗属性
var character_name: String
var current_hp: int
var max_hp: int
var current_mp: int:
	set(value):
		current_mp = value
		mp_bar.value = value
		mp_label.text = "MP: " + str(value) + "/" + str(max_mp)
var max_mp: int:
	set(value):
		max_mp = value
		mp_bar.max_value = value
		mp_label.text = "MP: " + str(current_mp) + "/" + str(value)
var attack: int
var defense: int
var speed: int
var magic_attack: int = 0 # 魔法攻击力
var magic_defense: int = 0 # 魔法防御力

# 引用场景中的节点
@onready var hp_label = %HPLabel
@onready var name_label = $Container/NameLabel
@onready var character_rect = %CharacterRect
@onready var hp_bar = %HPBar
@onready var defense_indicator = %DefenseIndicator
@onready var mp_bar: ProgressBar = %MPBar
@onready var mp_label: Label = %MPLabel

signal hp_changed(new_hp: int, max_hp: int)
signal character_died()

var _is_defending: bool = false


func _ready():
	if character_data:
		initialize_from_data(character_data)
	else:
		push_error("角色 " + name + " 没有分配CharacterData！")
	
	if !hp_changed.is_connected(_on_hp_changed):
		hp_changed.connect(_on_hp_changed)
	
	_on_hp_changed(current_hp, max_hp)

func initialize_from_data(data: CharacterData):
	# 保存数据引用
	self.character_data = data
	
	# 初始化属性
	character_name = data.character_name
	max_hp = data.max_hp
	current_hp = data.current_hp
	max_mp = data.max_mp
	current_mp = data.current_mp
	attack = data.attack
	defense = data.defense
	speed = data.speed
	magic_attack = data.magic_attack
	magic_defense = data.magic_defense
	defense_indicator.hide_indicator()
	update_visual()
	pass

func update_visual():
	if name_label:
		name_label.text = character_name
	if hp_label:
		hp_label.text = "HP: " + str(current_hp) + "/" + str(max_hp)
	# if mp_label:
	# 	mp_label.text = "MP: " + str(current_mp) + "/" + str(max_mp)
	# else:
	# 	pass
	if character_rect and character_data:
		character_rect.color = character_data.color

func _on_hp_changed(_current_hp, _max_hp):
	if not hp_bar:
		return ;
	hp_bar.max_value = _max_hp
	hp_bar.value = current_hp
	
	# 根据血条百分比改变颜色
		# 根据血条百分比改变颜色
	if hp_bar.ratio <= 0.25:
		hp_bar.self_modulate = Color.RED
	elif hp_bar.ratio <= 0.5:
		hp_bar.self_modulate = Color.YELLOW
	else:
		hp_bar.self_modulate = Color.GREEN
	
	hp_label.text = "HP:" + str(_current_hp) + "/" + str(_max_hp)

func take_damage(base_damage: int) -> int:
	var final_damage = base_damage
	if _is_defending:
		final_damage = round(base_damage * 0.5)
		print(character_name + " 正在防御，伤害减半！")
		set_defending(false)
	final_damage = max(1, final_damage)
	current_hp = max(0, current_hp - final_damage)
	
	hp_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		die()
	return final_damage

func heal(amount: int) -> int:
	current_hp = min(max_hp, current_hp + amount)
	update_visual()
	print_rich("[color=cyan][b]{0}[/b][/color] 恢复 [color=green]{1}[/color] 点HP, 剩余HP: [color=lime]{2}[/color]".format([character_name, amount, current_hp]))
	return amount

func set_defending(is_show: bool):
	_is_defending = is_show
	if is_show:
		defense_indicator.show_indicator()
	else:
		defense_indicator.hide_indicator()

func die():
	print_rich("[color=red][b]{0} 已被击败![/b][/color]".format([character_name]))
	# 在完整游戏中会添加死亡动画和事件
	character_died.emit()
	modulate = Color(1, 1, 1, 0.5) # 半透明表示被击败

# 回合开始时重置标记
func reset_turn_flags():
	set_defending(false)

## 是否存活
func is_alive() -> bool:
	return current_hp > 0


func use_mp(amount: int) -> bool:
	if current_mp >= amount:
		current_mp -= amount
		update_visual()
		return true
	return false
