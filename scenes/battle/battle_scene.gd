extends Node2D

const TargetSelectionMenu = preload("res://scenes/UI/target_selection_menu.gd")
const SkillSelectMenu = preload("res://scenes/UI/skill_select_menu.gd")
const ActionMenu = preload("res://scenes/UI/action_menu.gd")

# UI引用
@onready var info_label: RichTextLabel = %InfoLabel
@onready var battle_manager: BattleManager = %BattleManager
@onready var target_selection_menu: TargetSelectionMenu = $BattleUI/TargetSelectionMenu
@onready var skill_select_menu: SkillSelectMenu = $BattleUI/SkillSelectMenu
@onready var action_menu: ActionMenu = %ActionMenu

var current_selected_skill: SkillData = null
var skill_target: Character = null

func _ready():
	action_menu.attack_button.pressed.connect(battle_manager.player_attack)
	action_menu.defend_button.pressed.connect(battle_manager.player_defend)
	action_menu.skill_button.pressed.connect(func():
		skill_select_menu.show_menu(
			battle_manager.current_turn_character.character_data.skills,
			battle_manager.current_turn_character.character_data.current_mp
		)
		
		# battle_manager.player_skill()
	)
	battle_manager.battle_info_logged.connect(_on_battle_info_logged)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.battle_info_logged.connect(update_battle_info)

	# 连接技能选择菜单信号
	skill_select_menu.skill_selected.connect(_on_skill_selected)
	skill_select_menu.skill_selection_cancelled.connect(_on_skill_selection_cancelled)
	skill_select_menu.hide()

# 连接目标选择菜单信号
	target_selection_menu.target_selected.connect(_on_target_selected)
	target_selection_menu.target_selection_cancelled.connect(_on_target_selection_cancelled)
	# target_selection_menu.hide()

	find_characters()
	battle_manager.start_battle()


func show_action_ui(flag: bool):
	if action_menu:
		action_menu.visible = flag

func update_label(text: String):
	if info_label:
		info_label.text += "\n" + text

func _on_battle_info_logged(text: String) -> void:
	update_battle_info(text)

# 更新战斗信息
func update_battle_info(text: String):
	print_rich(text)
	update_label(text)

func _on_battle_ended(is_win: bool):
	if is_win:
		update_battle_info("[color=green][b]===== 战斗胜利! =====[/b][/color]")
	else:
		update_battle_info("[color=red][b]===== 战斗失败... =====[/b][/color]")
		
	# 隐藏行动UI
	show_action_ui(false)

func _on_turn_changed(character: Character):
	var is_player_turn = battle_manager.is_player_turn
	show_action_ui(is_player_turn)
	update_battle_info("{0} 的回合".format([character.character_data.character_name]))

# 找到角色
func find_characters():
	var player_area = get_node_or_null("PlayerTeamArea")
	var enemy_area = get_node_or_null("EnemyTeamArea")
	
	if player_area:
		for child in player_area.get_children():
			if child is Character:
				battle_manager.add_player_character(child)
	if enemy_area:
		for child in enemy_area.get_children():
			if child is Character:
				battle_manager.add_enemy_character(child)

func _on_skill_selected(skill: SkillData):
	current_selected_skill = skill
	match skill.target_type:
		SkillData.TargetType.SELF:
			# 自身技能无需选择目标
			battle_manager.player_select_action('skill', battle_manager.current_turn_character, skill)
		SkillData.TargetType.ENEMY_SINGLE:
			# 显示敌人目标选择菜单
			var valid_targets = battle_manager.get_valid_enemy_targets()
			if !valid_targets.is_empty():
				target_selection_menu.show_targets(valid_targets)
			else:
				update_battle_info("没有可选择的敌方目标！")
				_on_skill_selection_cancelled()
		SkillData.TargetType.ENEMY_ALL:
			# 群体敌人技能无需选择目标
			var valid_targets = battle_manager.get_valid_enemy_targets()
			if !valid_targets.is_empty():
				battle_manager.player_select_action("skill", null, skill, valid_targets)
			else:
				update_battle_info("没有可选择的敌方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.ALLY_SINGLE:
			# 显示我方(不含自己)目标选择菜单
			var valid_targets = battle_manager.get_valid_ally_targets(false)
			if !valid_targets.is_empty():
				target_selection_menu.show_targets(valid_targets)
			else:
				update_battle_info("没有可选择的友方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.ALLY_SINGLE_INC_SELF:
			# 显示我方(含自己)目标选择菜单
			var valid_targets = battle_manager.get_valid_ally_targets(true)
			if !valid_targets.is_empty():
				target_selection_menu.show_targets(valid_targets)
			else:
				update_battle_info("没有可选择的友方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.ALLY_ALL:
			# 群体我方(不含自己)技能
			var valid_targets = battle_manager.get_valid_ally_targets(false)
			if !valid_targets.is_empty():
				battle_manager.player_select_action("skill", null, skill, valid_targets)
			else:
				update_battle_info("没有可选择的友方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.ALLY_ALL_INC_SELF:
			# 群体我方(含自己)技能
			var valid_targets = battle_manager.get_valid_ally_targets(true)
			if !valid_targets.is_empty():
				battle_manager.player_select_action("skill", null, skill, valid_targets)
			else:
				update_battle_info("没有可选择的友方目标！")
				_on_skill_selection_cancelled()
		
		_:
			update_battle_info("未处理的目标类型: " + str(skill.target_type))
			_on_skill_selection_cancelled()

	target_selection_menu.show_targets(battle_manager.enemy_characters)

func _on_skill_selection_cancelled():
	current_selected_skill = null

func _on_target_selected(target: Character):
	# 确保有选中的技能
	if current_selected_skill == null:
		push_error("选择了目标但没有当前技能")
		# _show_action_menu()
		return
	
	# 单体技能处理
	if current_selected_skill.target_type == SkillData.TargetType.ENEMY_SINGLE || \
		current_selected_skill.target_type == SkillData.TargetType.ALLY_SINGLE || \
		current_selected_skill.target_type == SkillData.TargetType.ALLY_SINGLE_INC_SELF:
		battle_manager.player_select_action("skill", target, current_selected_skill)
	else:
		push_error("非单体技能不应该调用单体目标选择")
		# _show_action_menu()

func _on_target_selection_cancelled():
	skill_target = null
	skill_select_menu.show_menu(
			battle_manager.current_turn_character.character_data.skills,
			battle_manager.current_turn_character.character_data.current_mp)

func _hide_all_menus():
	pass
