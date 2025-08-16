extends Resource
class_name SkillAttributeModifier
# 本脚本定义了属性修改器的数据结构

enum ModifierOperation {
	ADD_ABSOLUTE, ## 直接加/减一个固定值 (例如: +10 攻击力)
	OVERRIDE, ## 直接覆盖属性的最终值 (例如: 速度强制设为0)
	ADD_PERCENTAGE ## 基于属性的基础值计算百分比 (例如: +20% 基础生命)
}

## 修改的属性ID
@export var attribute_id: StringName = &""
## 修改的幅度 (例如: 10, -5, 0.2, 1.5)
@export var magnitude: float = 0.0
## 修改的操作类型
@export var operation: ModifierOperation = ModifierOperation.ADD_ABSOLUTE
## (可选) 此Modifier的来源标识 (例如Buff的ID, 装备的UUID等)
## 用于调试或由外部系统决定是否移除特定来源的Modifier
var source_id: int = 0

# & 的作用
# StringName 类型：
# &"" 表示创建一个空的 StringName 对象。
# StringName 是 Godot 4 引入的一种特殊字符串类型，它比普通 String 更高效，尤其是在频繁比较或作为字典键时。
# 为什么使用 &：
# 在参数默认值 p_attribute_id: StringName = &"" 中，&"" 确保默认值是一个 StringName 而不是普通 String。
# 如果直接写 ""，Godot 会将其视为 String 类型，可能导致隐式转换。
# 性能考虑：
# StringName 在内部使用唯一标识符（类似哈希），比较速度比 String 快。
# 常用于节点路径、信号名、动画名等需要高效查找的场景。
func _init(
		p_attribute_id: StringName = &"",
		p_magnitude: float = 0.0,
		p_operation: ModifierOperation = ModifierOperation.ADD_ABSOLUTE,
		p_source_id: int = 0) -> void:
	attribute_id = p_attribute_id
	magnitude = p_magnitude
	operation = p_operation
	source_id = p_source_id

func set_source(p_source_id: int) -> void:
	source_id = p_source_id