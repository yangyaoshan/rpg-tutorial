extends Resource
class_name CharacterData

@export var character_name: String = "角色"
@export_multiline var description: String = "角色描述"

@export_group("核心属性")
# @export var max_hp: int = 100
# @export var current_hp: int = 100
# @export var max_mp: int = 50
# @export var current_mp: int = 50
# @export var attack: int = 10
# @export var defense: int = 5
# @export var speed: int = 7
@export var attribute_set_resource: SkillAttributeSet = null

@export var magic_attack: int = 10 # 魔法攻击力
@export var magic_defense: int = 10 # 魔法防御力

@export_group("技能列表")
@export var skills: Array[SkillData] = []

@export_group("视觉表现")
@export var color: Color = Color.BLUE # 为原型阶段设置的角色颜色

func get_skill_by_id(id: StringName) -> SkillData:
	for skill in skills:
		if skill and skill.skill_id == id:
			return skill
	return null

func get_skill_by_name(name: String) -> SkillData:
	for skill in skills:
		if skill and skill.skill_name == name:
			return skill
	return null
