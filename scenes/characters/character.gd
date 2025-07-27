extends Node2D
class_name Character

@export var character_data: CharacterData

# 运行时从CharacterData初始化的核心战斗属性
#var character_name: String
#var current_hp: int
#var max_hp: int
#var current_mp: int
#var max_mp: int
#var attack: int
#var defense: int
#var speed: int

# 引用场景中的节点
@onready var hp_label = $Container/HPLabel
@onready var name_label = $Container/NameLabel
@onready var character_rect = $Container/CharacterRect

func _ready(): 
	if character_data:
		initialize_from_data()
	else:
		push_error("角色 " + name + " 没有分配CharacterData！")

func initialize_from_data():
	update_visual()
	pass

func update_visual():
	if name_label: 
		name_label.text = character_data.character_name
	if hp_label: 
		hp_label.text = "HP: " + str(character_data.current_hp) + "/" + str(character_data.max_hp)
	if hp_label: 
		character_rect.color = character_data.color
		
