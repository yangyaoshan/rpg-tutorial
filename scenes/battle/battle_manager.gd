extends Node
class_name BattleManager

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/UI/damage_number.tscn")

const BattleStateManager = preload("res://scenes/battle/battle_state_manager.gd")
var state_manager = BattleStateManager.new()

# 信号
signal turn_changed(character: Character)
signal battle_ended(is_victory: bool)
signal battle_info_logged(text: String)

@export var heal_min_range: float = 0.95
@export var heal_max_range: float = 1.05
@export var heal_magic_coef: float = 1.0
@export var magic_attack_coef: float = 0.8
@export var magic_defend_coef: float = 0.5
@export var magic_min_range: float = 0.9
@export var magic_max_range: float = 1.1


# 战斗参与者
var player_characters: Array[Character] = []
var enemy_characters: Array[Character] = []

# 回合顺序管理
var turn_queue: Array[Character] = []
var current_turn_character: Character = null

var data = typeof(state_manager.BattleState)

func _ready():
	state_manager.init()
	state_manager.state_changed.connect(_on_state_changed)
	

# 简单的战斗标记
# 当前是否是玩家回合
var is_player_turn: bool = false:
	get:
		return state_manager.current_state == BattleStateManager.BattleState.PLAYER_TURN
var battle_finished: bool = false # 战斗是否结束
var is_victory: bool = false # 战斗结果是否为胜利


func build_turn_queue():
	# 清空当前队列
	turn_queue.clear()
	for character in player_characters:
		if character.current_hp > 0:
			turn_queue.append(character)
			
	for character in enemy_characters:
		if character.current_hp > 0:
			turn_queue.append(character)
			
	turn_queue.sort_custom(func(a, b): return a.speed > b.speed)
	
	log_battle_info("[color=yellow][战斗系统][/color] 回合队列已建立: [color=green][b]{0}[/b][/color] 个角色".format([turn_queue.size()]))


func add_player_character(character: Character):
	if not player_characters.has(character):
		player_characters.append(character)
		log_battle_info("[color=blue][玩家注册][/color] 添加角色: [color=cyan][b]{0}[/b][/color]".format([character.character_name]))

func add_enemy_character(character: Character):
	if not enemy_characters.has(character):
		enemy_characters.append(character)
		log_battle_info("[color=red][敌人注册][/color] 添加角色: [color=orange][b]{0}[/b][/color]".format([character.character_name]))
	
# 战斗相关
func start_battle():
	log_battle_info("[color=yellow][b]===== 战斗开始! =====[/b][/color]")
	if player_characters.is_empty() || enemy_characters.is_empty():
		push_error("缺少玩家或敌人角色")
		return
	
	# 初始化回合队列
	build_turn_queue()
	
	# 开始第一个角色的回合
	state_manager.change_state(BattleStateManager.BattleState.START)
	
func player_attack():
	# 玩家回合且战斗未结束
	if is_player_turn and not battle_finished:
		var target = null
		for enemy in enemy_characters:
			if enemy.current_hp > 0:
				target = enemy;
				break
		if target:
			player_select_action("attack", target)
			
func player_defend():
	if is_player_turn and not battle_finished:
		player_select_action("defend", current_turn_character)

func player_skill(skill_data: SkillData = null, targets: Array[Character] = []):
	if is_player_turn and not battle_finished:
		var target = null
		for enemy in enemy_characters:
			if enemy.current_hp > 0:
				target = enemy;
				break
		if target:
			player_select_action("skill", target, skill_data, targets)
		

# 处理玩家行动
func player_select_action(action_type: String, target: Character = null, skill_data: SkillData = null, targets: Array[Character] = []):
	if not is_player_turn or battle_finished:
		return
	print("玩家选择行动：", action_type)
	# 执行选择的行动
	match action_type:
		"attack":
			if target and target is Character:
				execute_attack(current_turn_character, target)
			else:
				# 默认选择第一个敌人作为目标
				var default_target = null
				for enemy in enemy_characters:
					if enemy.current_hp > 0:
						default_target = enemy
						break
				if default_target:
					execute_attack(current_turn_character, default_target)
				else:
					push_error("错误：没有可用目标")
					return
		"defend":
			if target and target is Character:
				execute_defend(current_turn_character)
		"skill":
			var skill_targets: Array[Character] = targets
			if skill_targets.is_empty():
				skill_targets.append(target)
			_execute_skill(current_turn_character, skill_targets, skill_data)
		_:
			push_error("未知行动类型: ", action_type)
			return
	
		# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
	
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

func _execute_skill(caster: Character, targets: Array[Character], skill_data: SkillData) -> void:
	print(caster.character_name + "使用技能：" + skill_data.skill_name)
	print(targets.size())
		# 技能的"前奏"——检查MP并消耗
	if !check_and_consume_mp(caster, skill_data):
		print("错误：MP不足，无法释放技能！")
		return
	match skill_data.effect_type:
		SkillData.EffectType.DAMAGE:
			_execute_damage_skill(caster, targets, skill_data)
		SkillData.EffectType.HEAL:
			_execute_heal_skill(caster, targets, skill_data)
		_:
			print("未处理的技能效果类型： ", skill_data.effect_type)
	

# MP检查和消耗
func check_and_consume_mp(caster: Character, skill: SkillData) -> bool:
	if caster.current_mp < skill.mp_cost:
		print_rich("[color=red]魔力不足，法术施放失败！[/color]")
		return false
	
	caster.use_mp(skill.mp_cost)
	return true

# 伤害类技能
func _execute_damage_skill(caster: Character, targets: Array[Character], skill: SkillData):
	for target in targets:
		if target.current_hp <= 0:
			continue
		
		# 计算基础伤害
		var base_damage = _calculate_skill_damage(caster, target, skill)
		
		# 应用伤害
		var damage_dealt = target.take_damage(base_damage)
		
		# 显示伤害数字
		spawn_damage_number(target.global_position, damage_dealt, Color.RED)

		print(target.character_name + " 受到 " + str(damage_dealt) + " 点伤害")

func _calculate_skill_damage(caster: Character, target: Character, skill: SkillData) -> int:
	# 基础伤害计算
	var base_damage = skill.power + (caster.magic_attack * magic_attack_coef)
	
	# 考虑目标防御
	var damage_after_defense = base_damage - (target.magic_defense * magic_defend_coef)
	
	# 加入随机浮动因素 (±10%)
	var random_factor = randf_range(magic_min_range, magic_max_range)
	var final_damage = damage_after_defense * random_factor
	
	# 确保伤害至少为1
	return max(1, round(final_damage))

# 治疗类技能
func _execute_heal_skill(caster: Character, targets: Array[Character], skill: SkillData) -> void:
	# 播放施法者的施法动画（可以与伤害技能不同，更温和）
	_play_heal_cast_animation(caster)

	# 等待短暂时间
	await get_tree().create_timer(0.3).timeout

	for target in targets:
		if target.current_hp <= 0: # 不能治疗已死亡的角色
			print("%s 已倒下，无法接受治疗。" % target.character_name)
			continue
		
		# 计算治疗量
		var healing = _calculate_skill_healing(caster, target, skill)
		
		# 播放治疗效果动画
		_play_heal_effect(target)

		# 应用治疗
		var actual_healed = target.heal(healing)
		
		# 显示治疗数字
		spawn_damage_number(target.global_position, actual_healed, Color.GREEN)

		print_rich("[color=green]%s 恢复了 %d 点生命值！[/color]" % [target.character_name, actual_healed])

## 播放施法动画
func _play_heal_cast_animation(caster: Character) -> void:
	_play_cast_animation(caster)

## 播放施法动画
func _play_cast_animation(caster: Character) -> void:
	var tween = create_tween()
	# 角色短暂发光效果
	tween.tween_property(caster, "modulate", Color(1.5, 1.5, 1.5), 0.2)
	tween.tween_property(caster, "modulate", Color(1, 1, 1), 0.2)
	
	# 这里可以播放施法音效
	# AudioManager.play_sfx("spell_cast")

func _calculate_skill_healing(caster: Character, _target: Character, skill: SkillData) -> int:
	# 治疗量通常更依赖施法者的魔法攻击力
	var base_healing = skill.power + (caster.magic_attack * heal_magic_coef)
	
	# 随机浮动 (±5%)
	var random_factor = randf_range(heal_min_range, heal_max_range)
	var final_healing = base_healing * random_factor
	
	return max(1, round(final_healing))

# 治疗效果视觉反馈
func _play_heal_effect(target: Character):
	var tween = create_tween()
	
	# 目标变绿效果（表示恢复）
	tween.tween_property(target, "modulate", Color(0.7, 1.5, 0.7), 0.2)
	
	# 上升的小动画，暗示"提升"
	var original_pos = target.position
	tween.tween_property(target, "position", original_pos - Vector2(0, 5), 0.2)
	tween.tween_property(target, "position", original_pos, 0.1)
	
	# 恢复正常颜色
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.2)

# 执行攻击
func execute_attack(attacker: Character, target: Character):
	log_battle_info("[color=purple][战斗行动][/color] [color=orange][b]{0}[/b][/color] 攻击 [color=cyan][b]{1}[/b][/color]".format([attacker.character_name, target.character_name]))
	var final_damage = target.take_damage(attacker.attack - target.defense)
	#显示伤害数字
	spawn_damage_number(target.global_position, final_damage, Color.RED)
	
	# 检查战斗是否结束
	check_battle_end_condition()
	
# 执行防御
func execute_defend(character: Character):
	if character == null:
		return
		
	log_battle_info("[color=purple][战斗行动][/color] [color=cyan][b]{0}[/b][/color] 选择[color=teal][防御][/color]，受到的伤害将减少".format([character.character_name]))
	character.set_defending(true)

# 检查战斗结束条件
func check_battle_end_condition() -> bool:
	# 如果战斗已结束，直接返回
	if battle_finished:
		return true
		
	# 检查玩家是否全部阵亡
	var all_players_defeated = true
	for player in player_characters:
		if player.current_hp > 0:
			all_players_defeated = false
			break
			
	# 检查敌人是否全部阵亡
	var all_enemies_defeated = true
	for enemy in enemy_characters:
		if enemy.current_hp > 0:
			all_enemies_defeated = false
			break
			
	# 判断战斗结果
	if all_players_defeated:
		# 玩家全部阵亡，战斗失败
		end_battle(false)
		return true
		
	if all_enemies_defeated:
		# 敌人全部阵亡，战斗胜利
		end_battle(true)
		return true
		
	return false
# 执行敌人AI
func execute_enemy_ai() -> void:
	# 简单的AI逻辑：总是攻击第一个存活的玩家角色
	var target = null
	for player in player_characters:
		if player.current_hp > 0:
			target = player
			break
			
	if target:
		log_battle_info("[color=orange][b]{0}[/b][/color] 选择攻击 [color=blue][b]{1}[/b][/color]".format([current_turn_character.character_name, target.character_name]))
		execute_attack(current_turn_character, target)
		is_player_turn = true
	else:
		log_battle_info("[color=red][错误][/color] 敌人找不到可攻击的目标")
		
	# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
	
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

# 结束战斗
func end_battle(is_win: bool):
	battle_finished = true
	is_victory = is_win
	# 发出战斗结束信号
	emit_signal("battle_ended", is_win)

func spawn_damage_number(position: Vector2, amount: int, color: Color):
	var damage_number = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = position + Vector2(0, -50)
	damage_number.show_number(str(amount), color)

## 战斗日志
func log_battle_info(text: String) -> void:
	print_rich(text)
	emit_signal("battle_info_logged", text)

## 状态改变处理函数
func _on_state_changed(_previous_state: BattleStateManager.BattleState, new_state: BattleStateManager.BattleState) -> void:
	# 所有状态下的动作逻辑都在这里
	match new_state:
		BattleStateManager.BattleState.START:
			state_manager.change_state(BattleStateManager.BattleState.ROUND_START)
		BattleStateManager.BattleState.ROUND_START:
			# 大回合开始，构建回合队列
			log_battle_info("[color=yellow][战斗系统][/color] 新的回合开始")
			if check_battle_end_condition():
				# 战斗已结束，状态已在check_battle_end_condition中切换
				return
				
			build_turn_queue()
			if turn_queue.is_empty():
				state_manager.change_state(BattleStateManager.BattleState.DEFEAT)
			else:
				state_manager.change_state(BattleStateManager.BattleState.TURN_START)
				
		BattleStateManager.BattleState.TURN_START:
			# 小回合开始，确定当前行动角色
			if turn_queue.is_empty():
				# 所有角色都行动完毕，回合结束
				state_manager.change_state(BattleStateManager.BattleState.ROUND_END)
				return
				
			current_turn_character = turn_queue.pop_front()
			log_battle_info("[color=cyan][回合][/color] [color=orange][b]{0}[/b][/color] 的回合开始".format([current_turn_character.character_name]))
			current_turn_character.reset_turn_flags()
			# 根据角色类型决定下一个状态
			var next_state = BattleStateManager.BattleState.PLAYER_TURN
			if player_characters.has(current_turn_character):
				next_state = BattleStateManager.BattleState.PLAYER_TURN
			else:
				next_state = BattleStateManager.BattleState.ENEMY_TURN
			state_manager.change_state(next_state)
			turn_changed.emit(current_turn_character) # 通知UI
			
		BattleStateManager.BattleState.PLAYER_TURN:
			pass
						
		BattleStateManager.BattleState.ENEMY_TURN:
			await get_tree().create_timer(1.0).timeout
			execute_enemy_ai()
			
		BattleStateManager.BattleState.TURN_END:
			# 小回合结束，检查战斗状态
			if check_battle_end_condition():
				# 战斗已结束，状态已在check_battle_end_condition中切换
				return
			
			# 进入下一个角色的回合
			state_manager.change_state(BattleStateManager.BattleState.TURN_START)
			
		BattleStateManager.BattleState.ROUND_END:
			# 大回合结束，进入新的回合
			log_battle_info("[color=yellow][战斗系统][/color] 回合结束")
			state_manager.change_state(BattleStateManager.BattleState.ROUND_START)
		BattleStateManager.BattleState.VICTORY:
			log_battle_info("[color=green][b]===== 战斗胜利! =====[/b][/color]")
			battle_ended.emit(true)
		BattleStateManager.BattleState.DEFEAT:
			log_battle_info("[color=red][b]===== 战斗失败... =====[/b][/color]")
			battle_ended.emit(false)

# 获取有效的友方目标列表
# include_self: 是否包括施法者自己
func get_valid_ally_targets(include_self: bool = false) -> Array[Character]:
	var valid_targets: Array[Character] = []
	
	for ally in player_characters:
		if ally.is_alive() && (include_self || ally != current_turn_character):
			valid_targets.append(ally)
	
	return valid_targets

# 获取有效的敌方目标列表（过滤掉已倒下的角色）
func get_valid_enemy_targets() -> Array[Character]:
	var valid_targets: Array[Character] = []
	
	for enemy in enemy_characters:
		if enemy.is_alive():
			valid_targets.append(enemy)
	
	return valid_targets
