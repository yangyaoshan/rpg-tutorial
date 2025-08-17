extends Resource
class_name SkillStatusData

## 状态数据资源，用于定义状态效果的模板配置和运行时实例。
## 通过 SkillStatusData，我们可以为不同的状态效果设置不同的属性和行为。
## 这些配置将被用于在战斗中创建和管理状态效果实例。

## 叠加行为类型
enum StackBehavior {
	NO_STACK, ## 不可叠加
	REFRESH_DURATION, ## 刷新持续时间
	ADD_DURATION, ## 增加持续时间
	ADD_STACKS_REFRESH_DURATION, ## 增加叠加层数并刷新持续时间
	ADD_STACKS_INDEPENDENT_DURATION ## 增加叠加层数并独立持续时间 (简化实现时可能等同于刷新)
}

## 持续时间类型
enum DurationType {
	TURNS, ## 回合数
	INFINITE, ## 无限 (直到被驱散或战斗结束)
	COMBAT_LONG ## 持续到战斗结束 (通常不可驱散)
}

## 状态类型，用于视觉或某些逻辑判断
enum StatusType {
	BUFF, ## 增益
	DEBUFF, ## 减益
	NEUTRAL ## 中性
}

# --- 模板配置属性 (@export) ---
@export var status_id: StringName = &"" ## 唯一ID
@export var status_name: String = "状态效果" ## 显示名称
@export_multiline var description: String = "" ## 详细描述
@export var icon: Texture2D ## UI图标

@export var status_type: StatusType = StatusType.NEUTRAL ## 状态类型
@export var duration: int = 3 ## 默认持续回合数 (对TURNS类型有效)
@export var duration_type: DurationType = DurationType.TURNS ## 持续时间类型
@export var max_stacks: int = 1 ## 最大叠加层数
@export var stack_behavior: StackBehavior = StackBehavior.REFRESH_DURATION ## 叠加行为

# 核心影响机制 (数组内为 SkillEffectData 或 SkillAttributeModifier 模板资源)
@export var attribute_modifiers: Array[SkillAttributeModifier] = [] ## 属性修改器
@export var initial_effects: Array[SkillEffectData] = [] ## 初始效果
@export var ongoing_effects: Array[SkillEffectData] = [] ## 持续效果
@export var end_effects: Array[SkillEffectData] = [] ## 结束效果

# 状态间交互
@export var overrides_states: Array[StringName] = [] ## 此状态应用时会移除的目标状态ID列表
@export var resisted_by_states: Array[StringName] = [] ## 如果目标拥有这些状态之一，则此状态无法应用

# 行动限制
@export_group("行动限制")
## 角色拥有此状态时，无法执行哪些类别的行动。
## 数组元素为StringName，对应 SkillData.action_categories 中的类别。
## 例如: [&"any_action"] (眩晕), [&"magic_skill"] (沉默)
@export var restricted_action_categories: Array[StringName] = []

# --- 运行时变量 (在 duplicate(true) 后由 character.gd 设置和管理) ---
var source_character: Character ## 施加此状态的角色
var target_character: Character ## 拥有此状态的角色 (方便状态效果内部逻辑访问目标)
var stacks: int = 1 ## 当前叠加层数
var remaining_duration: int ## 剩余持续时间
var is_permanent: bool:
	get:
		return duration_type == DurationType.INFINITE or duration_type == DurationType.COMBAT_LONG

#region --- 方法 ---
func _init():
	source_character = null
	target_character = null
	stacks = 1

func get_full_description() -> String:
	var desc = "%s: %s\n" % [status_name, description]
	if duration_type == DurationType.TURNS:
		desc += "基础持续 %d 回合. " % duration
	elif duration_type == DurationType.INFINITE:
		desc += "持续无限 (或直到被驱散). "
	elif duration_type == DurationType.COMBAT_LONG:
		desc += "持续至战斗结束. "
		
	if max_stacks > 1:
		desc += "最多叠加 %d 层. " % max_stacks
	if not initial_effects.is_empty(): desc += "应用时触发效果.\n"
	if not ongoing_effects.is_empty(): desc += "每回合触发效果.\n"
	if not end_effects.is_empty(): desc += "结束时触发效果.\n"
	return desc.strip_edges()

# 判断状态是否存在于抵抗列表中
func is_countered_by(other_status_id: StringName) -> bool:
	return resisted_by_states.has(other_status_id)

func overrides_other_status(other_status_id: StringName) -> bool:
	return overrides_states.has(other_status_id)


#endregion
