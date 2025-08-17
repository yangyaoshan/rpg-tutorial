extends Node
class_name CharacterSkillComponent

@export var characterStatusComponent: CharacterStatusComponent = null

## 可用的技能
var _skills: Array[SkillData] = []

## 初始化组件
func initialize(skills: Array[SkillData]):
	# 这是因为AttributeSet本身是一个Resource, 直接使用会导致所有实例共享数据
	if !characterStatusComponent:
		push_error("没有引入characterStatusComponent组件")
		return
	# 初始化技能列表
	_skills = skills

#region --- 技能管理 ---

## 是否有足够的MP释放技能
func has_enough_mp_for_any_skill() -> bool:
	var current_mp = characterStatusComponent.get_attribute_current_value(&"CurrentMana")
	for skill in _skills:
		if current_mp >= skill.mp_cost:
			return true
	return false

## 检查是否有足够的MP使用指定技能
func has_enough_mp_for_skill(skill: SkillData) -> bool:
	var current_mp = characterStatusComponent.get_attribute_current_value(&"CurrentMana")
	return current_mp >= skill.mp_cost

## 获取所有技能
## [return] 技能数据数组
func get_skills() -> Array[SkillData]:
	return _skills

## 添加技能
func add_skill(skill: SkillData) -> void:
	_skills.append(skill)

## 移除技能
func remove_skill(skill: SkillData) -> void:
	_skills.erase(skill)

## 获取技能
## [param skill_id] 技能ID
## [return] 技能数据
func get_skill(skill_id: StringName) -> SkillData:
	for skill in _skills:
		if skill.skill_id == skill_id:
			return skill
	return null

## 检查是否有指定技能
## [param skill_id] 技能ID
## [return] 是否有指定技能
func has_skill(skill_id: StringName) -> bool:
	return get_skill(skill_id) != null

## 获取技能数量
## [return] 技能数量
func get_skill_count() -> int:
	return _skills.size()
#endregion
