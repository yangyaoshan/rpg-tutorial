extends Node2D
class_name Character

@export var character_data: CharacterData
@export var maximum_hp: int


#region --- 常用属性的便捷Getter ---
var current_hp: float:
	get: return active_attribute_set.get_current_value(&"CurrentHealth") if active_attribute_set else 0.0
var max_hp: float:
	get: return active_attribute_set.get_current_value(&"MaxHealth") if active_attribute_set else 0.0
var current_mp: float:
	get: return active_attribute_set.get_current_value(&"CurrentMana") if active_attribute_set else 0.0
var max_mp: float:
	get: return active_attribute_set.get_current_value(&"MaxMana") if active_attribute_set else 0.0
var attack_power: float:
	get: return active_attribute_set.get_current_value(&"AttackPower") if active_attribute_set else 0.0
var defense_power: float:
	get: return active_attribute_set.get_current_value(&"DefensePower") if active_attribute_set else 0.0
var speed: float:
	get: return active_attribute_set.get_current_value(&"Speed") if active_attribute_set else 0.0
var magic_attack: float:
	get: return active_attribute_set.get_current_value(&"MagicAttack") if active_attribute_set else 0.0
var magic_defense: float:
	get: return active_attribute_set.get_current_value(&"MagicDefense") if active_attribute_set else 0.0
var character_name: StringName:
	get: return character_data.character_name if character_data else ""
#endregion

# 引用场景中的节点
@onready var hp_label = %HPLabel
@onready var name_label = $Container/NameLabel
@onready var character_rect = %CharacterRect
@onready var hp_bar = %HPBar
@onready var defense_indicator = %DefenseIndicator
@onready var mp_bar: ProgressBar = %MPBar
@onready var mp_label: Label = %MPLabel

signal character_died()
signal hp_changed(current_hp: float, max_hp: float, character: Character)
signal mp_changed(current_mp: float, max_mp: float, character: Character)

var _is_defending: bool = false
var active_attribute_set: SkillAttributeSet = null ## 运行时角色实际持有的AttributeSet实例 (通过模板duplicate而来)

func _ready():
	if character_data:
		initialize_from_data(character_data)
	else:
		push_error("角色 " + name + " 没有分配CharacterData！")
	
		# 链接AttributeSet到Character
	active_attribute_set.current_value_changed.connect(_on_attribute_current_value_changed)
	active_attribute_set.base_value_changed.connect(_on_attribute_base_value_changed)

	# if !hp_changed.is_connected(_on_hp_changed):
	# 	hp_changed.connect(_on_hp_changed)
	
	# _on_hp_changed(current_hp, max_hp)

func initialize_from_data(data: CharacterData):
	# 保存数据引用
	self.character_data = data
	
	# 初始化属性
	active_attribute_set = character_data.attribute_set_resource.duplicate(true)
	if not active_attribute_set:
		push_error("无法创建SkillAttributeSet实例")
		return
	active_attribute_set.initialize_set()

	defense_indicator.hide_indicator()
	update_visual()
	pass

func update_visual():
	if name_label:
		name_label.text = character_name

	_update_health_display()
	_update_mana_display()
	if character_rect and character_data:
		character_rect.color = character_data.color

# func _on_hp_changed(_current_hp, _max_hp):
	
# 	_update_health_display()

func take_damage(base_damage: float) -> int:
	var final_damage = base_damage
	if _is_defending:
		final_damage = round(base_damage * 0.5)
		print(character_name + " 正在防御，伤害减半！")
		set_defending(false)
	final_damage = max(1, final_damage)
	active_attribute_set.modify_base_value(&"CurrentHealth", max(0, current_hp - final_damage))
	
	if current_hp == 0:
		_die()
	return final_damage

func heal(amount: int) -> int:
	active_attribute_set.modify_base_value(&"CurrentHealth", min(max_hp, current_hp + amount))
	update_visual()
	print_rich("[color=cyan][b]{0}[/b][/color] 恢复 [color=green]{1}[/color] 点HP, 剩余HP: [color=lime]{2}[/color]".format([character_name, amount, current_hp]))
	return amount

func set_defending(is_show: bool):
	_is_defending = is_show
	if is_show:
		defense_indicator.show_indicator()
	else:
		defense_indicator.hide_indicator()

func _die():
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

func _update_health_display() -> void:
	if hp_bar and active_attribute_set: # 确保active_attribute_set已初始化
		var current_val = active_attribute_set.get_current_value(&"CurrentHealth")
		var max_val = active_attribute_set.get_current_value(&"MaxHealth")
		hp_bar.max_value = max_val
		hp_bar.value = current_val
		hp_label.text = "%d/%d" % [roundi(current_val), roundi(max_val)]
		# 根据血条百分比改变颜色
			# 根据血条百分比改变颜色
		if hp_bar.ratio <= 0.25:
			hp_bar.self_modulate = Color.RED
		elif hp_bar.ratio <= 0.5:
			hp_bar.self_modulate = Color.YELLOW
		else:
			hp_bar.self_modulate = Color.GREEN

func _update_mana_display() -> void:
	if mp_bar and active_attribute_set: # 确保active_attribute_set已初始化
		var current_val = active_attribute_set.get_current_value(&"CurrentMana")
		var max_val = active_attribute_set.get_current_value(&"MaxMana")
		mp_bar.max_value = max_val
		mp_bar.value = current_val
		mp_label.text = "%d/%d" % [roundi(current_val), roundi(max_val)]

## 当AttributeSet中的属性当前值变化时调用
func _on_attribute_current_value_changed(attribute_instance: SkillAttribute, old_value: float, new_value: float):
	if attribute_instance.attribute_name == &"CurrentHealth":
		hp_changed.emit(new_value, max_hp, self)
		_update_health_display()
		if new_value <= 0.0 and old_value > 0.0: # 从存活到死亡
			_die()
	elif attribute_instance.attribute_name == &"MaxHealth":
		# MaxHealth变化也需要通知UI更新，并可能影响CurrentHealth的钳制（已在AttributeSet钩子中处理）
		hp_changed.emit(current_hp, new_value, self)
		_update_health_display()
	elif attribute_instance.attribute_name == &"CurrentMana":
		mp_changed.emit(new_value, max_mp, self)
		_update_mana_display()
	elif attribute_instance.attribute_name == &"MaxMana":
		mp_changed.emit(current_mp, new_value, self)
		_update_mana_display()

## 当AttributeSet中的属性基础值变化时调用
## 这个方法上面已经实现了，可以删除，这里写了只是为了演示
func _on_attribute_base_value_changed(attribute_instance: SkillAttribute, _old_value: float, _new_value: float):
	# 通常基础值变化也会导致当前值变化，相关信号已在_on_attribute_current_value_changed处理
	# 但如果UI需要特别区分显示基础值和当前值，可以在这里做处理
	if attribute_instance.attribute_name == &"MaxHealth": # 例如基础MaxHealth变化
		_update_health_display() # 确保UI同步
