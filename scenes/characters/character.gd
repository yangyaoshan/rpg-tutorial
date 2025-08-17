extends Node2D
class_name Character

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")
@export var character_data: CharacterData
@onready var combat_component: CharacterCombatComponent = %CharacterCombatComponent
@onready var skill_component: CharacterSkillComponent = %CharacterSkillComponent
@onready var status_component: CharacterStatusComponent = %CharacterStatusComponent

#region --- 常用属性的便捷Getter ---
var current_hp: float:
	get: return status_component.get_attribute_current_value(&"CurrentHealth")
var max_hp: float:
	get: return status_component.get_attribute_current_value(&"MaxHealth")
var current_mp: float:
	get: return status_component.get_attribute_current_value(&"CurrentMana")
var max_mp: float:
	get: return status_component.get_attribute_current_value(&"MaxMana")
var attack_power: float:
	get: return status_component.get_attribute_current_value(&"AttackPower")
var defense_power: float:
	get: return status_component.get_attribute_current_value(&"DefensePower")
var speed: float:
	get: return status_component.get_attribute_current_value(&"Speed")
var magic_attack: float:
	get: return status_component.get_attribute_current_value(&"MagicAttack")
var magic_defense: float:
	get: return status_component.get_attribute_current_value(&"MagicDefense")
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

# 信号 - 这些信号将转发组件的信号
signal character_defeated
signal health_changed(current_hp: float, max_hp: float, character: Character)
signal mana_changed(current_mp: float, max_mp: float, character: Character)
signal status_applied_to_character(character: Character, status_instance: SkillStatusData)
signal status_removed_from_character(character: Character, status_id: StringName, status_instance_data_before_removal: SkillStatusData)
signal status_updated_on_character(character: Character, status_instance: SkillStatusData, old_stacks: int, old_duration: int)

var _is_defending: bool = false
# var status_component: SkillAttributeSet = null ## 运行时角色实际持有的AttributeSet实例 (通过模板duplicate而来)

func _ready():
	if character_data:
		initialize_from_data(character_data)
	else:
		push_error("角色 " + name + " 没有分配CharacterData！")
	
	# 链接AttributeSet到Character
	# status_component.current_value_changed.connect(_on_attribute_current_value_changed)
	# status_component.base_value_changed.connect(_on_attribute_base_value_changed)
	combat_component.initialize()

	# if !hp_changed.is_connected(_on_hp_changed):
	# 	hp_changed.connect(_on_hp_changed)
	
	# _on_hp_changed(current_hp, max_hp)

func initialize_from_data(data: CharacterData):
	# 保存数据引用
	self.character_data = data
	status_component.initialize(character_data.attribute_set_resource.duplicate(true))
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
## 生成伤害数字
func spawn_damage_number(amount: int, color: Color) -> void:
	var damage_number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -50)
	damage_number.show_number(str(amount), color)

func take_damage(base_damage: float) -> float:
	if not combat_component:
		return 0.0
	var result = combat_component.take_damage(base_damage)
	spawn_damage_number(result, Color.RED)
	update_visual()
	return result

func heal(amount: int) -> int:
	status_component.restore_hp(min(max_hp, current_hp + amount))
	update_visual()
	print_rich("[color=cyan][b]{0}[/b][/color] 恢复 [color=green]{1}[/color] 点HP, 剩余HP: [color=lime]{2}[/color]".format([character_name, amount, current_hp]))
	return amount

func set_defending(is_show: bool):
	_is_defending = is_show
	if is_show:
		defense_indicator.show_indicator()
	else:
		defense_indicator.hide_indicator()

# 回合开始时重置标记
func reset_turn_flags():
	set_defending(false)

## 是否存活
func is_alive() -> bool:
	return current_hp > 0

func _update_health_display() -> void:
	if hp_bar and status_component: # 确保active_attribute_set已初始化
		var current_val = status_component.get_attribute_current_value(&"CurrentHealth")
		var max_val = status_component.get_attribute_current_value(&"MaxHealth")
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
	if mp_bar and status_component: # 确保active_attribute_set已初始化
		var current_val = status_component.get_attribute_current_value(&"CurrentMana")
		var max_val = status_component.get_attribute_current_value(&"MaxMana")
		mp_bar.max_value = max_val
		mp_bar.value = current_val
		mp_label.text = "%d/%d" % [roundi(current_val), roundi(max_val)]


## 初始化组件
func _init_components() -> void:
	if not combat_component:
		push_error("战斗组件未初始化！")
		return
	if not skill_component:
		push_error("技能组件未初始化！")
		return
	
	combat_component.initialize()

	# 连接组件信号
	combat_component.defending_changed.connect(_on_defending_changed)
	combat_component.character_defeated.connect(_on_character_defeated)

	status_component.status_applied.connect(func(character, status_instance):
		status_applied_to_character.emit(character, status_instance))
		
	status_component.status_removed.connect(func(character, status_id, status_instance):
		status_removed_from_character.emit(character, status_id, status_instance))
		
	status_component.status_updated.connect(func(character, status_instance, old_stacks, old_duration):
		status_updated_on_character.emit(character, status_instance, old_stacks, old_duration))

	status_component.attribute_base_value_changed.connect(_on_attribute_base_value_changed)
	status_component.attribute_current_value_changed.connect(_on_attribute_current_value_changed)


## 玩家选择行动
func execute_action(action_type: CharacterCombatComponent.ActionType, target: Character = null, params: Dictionary = {}) -> void:
	if not combat_component:
		return
	combat_component.execute_action(action_type, target, params)

## 播放动画
func play_animation(animation_name: String) -> void:
	print("假装播放了动画：", animation_name)

func on_turn_start(battle_manager: BattleManager) -> void:
	if combat_component:
		combat_component.on_turn_start(battle_manager)

func on_turn_end(battle_manager: BattleManager) -> void:
	if combat_component:
		combat_component.on_turn_end(battle_manager)

func apply_skill_status(status_instance: SkillStatusData, source_character: Character, effect_data_from_skill: SkillEffectData) -> Dictionary:
	if status_component:
		return status_component.apply_status(status_instance, source_character, effect_data_from_skill)
	return {"applied_successfully": false, "reason": "invalid_status_template"}

#region --- 信号处理 ---
## 当AttributeSet中的属性当前值变化时调用
func _on_attribute_current_value_changed(
		attribute_instance: SkillAttribute, _old_value: float, new_value: float) -> void:
	if attribute_instance.attribute_name == &"CurrentHealth":
		health_changed.emit(new_value, max_hp, self)
		_update_health_display()
	elif attribute_instance.attribute_name == &"MaxHealth":
		# MaxHealth变化也需要通知UI更新，并可能影响CurrentHealth的钳制（已在AttributeSet钩子中处理）
		health_changed.emit(current_hp, new_value, self)
		_update_health_display()
	elif attribute_instance.attribute_name == &"CurrentMana":
		mana_changed.emit(new_value, max_mp, self)
		_update_mana_display()
	elif attribute_instance.attribute_name == &"MaxMana":
		mana_changed.emit(current_mp, new_value, self)
		_update_mana_display()

## 当AttributeSet中的属性基础值变化时调用
func _on_attribute_base_value_changed(attribute_instance: SkillAttribute, _old_value: float, _new_value: float):
	# 通常基础值变化也会导致当前值变化，相关信号已在_on_attribute_current_value_changed处理
	# 但如果UI需要特别区分显示基础值和当前值，可以在这里做处理
	if attribute_instance.attribute_name == &"MaxHealth": # 例如基础MaxHealth变化
		_update_health_display() # 确保UI同步
	
func _on_defending_changed(value: bool):
	if not defense_indicator:
		return
	if value:
		defense_indicator.show_indicator()
	else:
		defense_indicator.hide_indicator()

func _on_character_defeated():
	if defense_indicator:
		defense_indicator.hide_indicator()
	modulate = Color(0.5, 0.5, 0.5, 0.5) # 变灰示例
	character_defeated.emit()

#endregion
