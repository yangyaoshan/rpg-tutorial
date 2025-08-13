extends Node
class_name BattleManager

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/UI/damage_number.tscn")

const BattleStateManager = preload("res://scenes/battle/battle_state_manager.gd")
var state_manager = BattleStateManager.new()

# 信号
signal turn_changed(character: Character)
signal battle_ended(is_victory: bool)
signal battle_info_logged(text: String)
signal effect_applied(effect_type: String, source: Character, target: Character, result: Dictionary)
signal skill_executed(caster: Character, targets: Array[Character], skill_data: SkillData, results: Dictionary)

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
var effect_processors = {} ## 效果处理器

# 简单的战斗标记
# 当前是否是玩家回合
var is_player_turn: bool = false:
	get:
		return state_manager.current_state == BattleStateManager.BattleState.PLAYER_TURN
var battle_finished: bool = false # 战斗是否结束
var is_victory: bool = false # 战斗结果是否为胜利

func _ready():
	_init_effect_processors()
	state_manager.init()
	state_manager.state_changed.connect(_on_state_changed)
	

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

func _get_targets_for_skill(skill: SkillData) -> Array[Character]:
	var targets: Array[Character] = []
	
	match skill.target_type:
		SkillData.TargetType.NONE:
			# 无目标技能
			pass
			
		SkillData.TargetType.SELF:
			# 自身为目标
			targets = [current_turn_character]
			
		SkillData.TargetType.ENEMY_SINGLE:
			# 选择单个敌人（在实际游戏中应由玩家交互选择）
			# 此处简化为自动选择第一个活着的敌人
			var valid_targets = get_valid_enemy_targets()
			if !valid_targets.is_empty():
				targets = [valid_targets[0]]
				
		SkillData.TargetType.ENEMY_ALL:
			# 所有活着的敌人
			targets = get_valid_enemy_targets()
			
		SkillData.TargetType.ALLY_SINGLE:
			# 选择单个友方（不包括自己）
			# 简化为自动选择第一个活着的友方
			var valid_targets = get_valid_ally_targets(false)
			if !valid_targets.is_empty():
				targets = [valid_targets[0]]
				
		SkillData.TargetType.ALLY_ALL:
			# 所有活着的友方（不包括自己）
			targets = get_valid_ally_targets(false)
			
		SkillData.TargetType.ALLY_SINGLE_INC_SELF:
			# 选择单个友方（包括自己）
			# 简化为选择自己
			targets = [current_turn_character]
			
		SkillData.TargetType.ALLY_ALL_INC_SELF:
			# 所有活着的友方（包括自己）
			targets = get_valid_ally_targets(true)
	
	return targets

## 执行技能 - 由BattleScene调用
func _execute_skill(caster: Character, custom_targets: Array[Character], skill_data: SkillData) -> Dictionary:
	if not is_instance_valid(caster) or not skill_data:
		push_error("SkillSystem: 无效的施法者或技能")
		return {}
	
	# 检查MP消耗
	if not skill_data.can_cast(caster.current_mp):
		push_error("SkillSystem: MP不足，无法施放技能")
		return {"error": "mp_not_enough"}
	
	# 扣除MP
	if skill_data.mp_cost > 0:
		caster.use_mp(skill_data.mp_cost)
	
	# 获取目标
	var targets = custom_targets if !custom_targets.is_empty() else _get_targets_for_skill(skill_data)
	
	if targets.is_empty():
		push_warning("SkillSystem: 没有有效目标")
		return {"error": "no_valid_targets"}
	
	# 播放施法动画
	# if skill_data.cast_animation != "":
	# 	_play_cast_animation(caster)
	
	# 等待短暂时间（供动画播放）
	# if Engine.get_main_loop():
	# 	await Engine.get_main_loop().process_frame

	# 处理直接效果
	var effect_results = {}
	if not skill_data.effects.is_empty():
		effect_results = await _apply_effects(skill_data.effects, caster, targets)

	# 合并结果
	var final_results = {}
	for target in targets:
		final_results[target] = {}
		
		if effect_results.has(target):
			for key in effect_results[target]:
				final_results[target][key] = effect_results[target][key]
	
	# 发送技能执行信号
	skill_executed.emit(caster, targets, skill_data, final_results)
	return final_results

# 应用多个效果
func _apply_effects(effects: Array, source: Character, targets: Array) -> Dictionary:
	var all_results = {}

	for target in targets:
		if !is_instance_valid(target) or target.current_hp <= 0:
			continue
		
		all_results[target] = {}
		
		for effect in effects:
			var result = await _apply_effect(effect, source, target)
			for key in result:
				all_results[target][key] = result[key]
	
	return all_results

# 应用单个效果
func _apply_effect(effect: SkillEffectData, source: Character, target: Character) -> Dictionary:
	# 检查参数有效性
	if !is_instance_valid(source) or !is_instance_valid(target):
		push_error("SkillSystem: 无效的角色引用")
		return {}
	
	if not effect:
		push_error("SkillSystem: 无效的效果引用")
		return {}
	
	# 获取对应的处理器
	var processor_id = _get_processor_id_for_effect(effect)
	var processor = effect_processors.get(processor_id)
	
	if processor and processor.can_process_effect(effect):
		# 使用处理器处理效果
		var result = await processor.process_effect(effect, source, target)
		
		# 发出信号
		effect_applied.emit(effect.effect_type, source, target, result)
		return result
	else:
		push_error("SkillSystem: 无效的效果处理器")
		return {}

## 根据效果类型获取处理器ID
func _get_processor_id_for_effect(effect: SkillEffectData) -> String:
	match effect.effect_type:
		SkillEffectData.EffectType.DAMAGE:
			return "damage"
		SkillEffectData.EffectType.HEAL:
			return "heal"
		SkillEffectData.EffectType.ATTRIBUTE_MODIFY:
			return "attribute"
		SkillEffectData.EffectType.STATUS:
			return "status"
		SkillEffectData.EffectType.DISPEL:
			return "dispel"
		SkillEffectData.EffectType.SPECIAL:
			return "special"
		_:
			return "unknown"

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
	print('attacker.attack_power', attacker.attack_power)
	print('target.defense_power', target.defense_power)
	var final_damage = target.take_damage(attacker.attack_power - target.defense_power)
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


# 在初始化方法中注册新的效果处理器
func _init_effect_processors():
	# 注册处理器
	register_effect_processor(DamageEffectProcessor.new(self))
	register_effect_processor(HealingEffectProcessor.new(self))

## 注册效果处理器
func register_effect_processor(processor: EffectProcessor):
	var processor_id = processor.get_processor_id()
	effect_processors[processor_id] = processor
	print("注册效果处理器: %s" % processor_id)