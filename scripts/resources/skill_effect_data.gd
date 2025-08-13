extends Resource
class_name SkillEffectData

# 效果类型枚举
enum EffectType {
	DAMAGE, ## 伤害
	HEAL, ## 治疗
	ATTRIBUTE_MODIFY, ## 属性修改
	STATUS, ## 控制
	DISPEL, ## 驱散
	SPECIAL ## 特殊效果
}

# 基本属性
@export var effect_type: EffectType = EffectType.DAMAGE
@export var visual_effect: String = "" ## 视觉效果标识符
@export var sound_effect: String = "" ## 音效标识符

# 伤害效果参数
@export_group("伤害效果参数", "damage_")
@export var damage_amount: int = 10 ## 基础伤害值
# @export var damage_element: int = 0     		## 元素类型
@export var damage_power_scale: float = 1.0 ## 攻击力加成系数

# 治疗效果参数
@export_group("治疗效果参数", "heal_")
@export var heal_amount: int = 10 ## 基础治疗值
@export var heal_power_scale: float = 0.5 ## 魔法攻击力加成系数

## 获取效果描述
func get_description() -> String:
	match effect_type:
		EffectType.DAMAGE:
			return _get_damage_description()
		EffectType.HEAL:
			return _get_heal_description()
		_:
			return "未知效果"

## 获取伤害效果描述
func _get_damage_description() -> String:
	var amount = damage_amount
	return "造成 %d 点伤害" % [amount]

## 获取治疗效果描述
func _get_heal_description() -> String:
	var amount = heal_amount
	return "恢复 %d 点生命值" % [amount]
