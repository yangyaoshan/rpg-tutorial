extends Node
class_name BattleManager

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/UI/damage_number.tscn")

const BattleStateManager = preload("res://scenes/battle/battle_state_manager.gd")
var state_manager = BattleStateManager.new()

# 信号
signal turn_changed(character: Character)
signal battle_ended(is_victory: bool)
signal battle_info_logged(text: String)

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
		if character.character_data.current_hp > 0:
			turn_queue.append(character)
			
	for character in enemy_characters:
		if character.character_data.current_hp > 0:
			turn_queue.append(character)
			
	turn_queue.sort_custom(func(a, b): return a.character_data.speed > b.character_data.speed)
	
	log_battle_info("[color=yellow][战斗系统][/color] 回合队列已建立: [color=green][b]{0}[/b][/color] 个角色".format([turn_queue.size()]))


func add_player_character(character: Character):
	if not player_characters.has(character):
		player_characters.append(character)
		log_battle_info("[color=blue][玩家注册][/color] 添加角色: [color=cyan][b]{0}[/b][/color]".format([character.character_data.character_name]))

func add_enemy_character(character: Character):
	if not enemy_characters.has(character):
		enemy_characters.append(character)
		log_battle_info("[color=red][敌人注册][/color] 添加角色: [color=orange][b]{0}[/b][/color]".format([character.character_data.character_name]))
	
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
			if enemy.character_data.current_hp > 0:
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
			if enemy.character_data.current_hp > 0:
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
	print(caster.character_data.character_name + "使用技能：" + skill_data.skill_name)
	print(targets.size())

# 执行攻击
func execute_attack(attacker: Character, target: Character):
	log_battle_info("[color=purple][战斗行动][/color] [color=orange][b]{0}[/b][/color] 攻击 [color=cyan][b]{1}[/b][/color]".format([attacker.character_data.character_name, target.character_data.character_name]))
	var final_damage = target.take_damage(attacker.character_data.attack - target.character_data.defense)
	#显示伤害数字
	spawn_damage_number(target.global_position, final_damage, Color.RED)
	
	# 检查战斗是否结束
	check_battle_end_condition()
	
# 执行防御
func execute_defend(character: Character):
	if character == null:
		return
		
	log_battle_info("[color=purple][战斗行动][/color] [color=cyan][b]{0}[/b][/color] 选择[color=teal][防御][/color]，受到的伤害将减少".format([character.character_data.character_name]))
	character.set_defending(true)

# 检查战斗结束条件
func check_battle_end_condition() -> bool:
	# 如果战斗已结束，直接返回
	if battle_finished:
		return true
		
	# 检查玩家是否全部阵亡
	var all_players_defeated = true
	for player in player_characters:
		if player.character_data.current_hp > 0:
			all_players_defeated = false
			break
			
	# 检查敌人是否全部阵亡
	var all_enemies_defeated = true
	for enemy in enemy_characters:
		if enemy.character_data.current_hp > 0:
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
		if player.character_data.current_hp > 0:
			target = player
			break
			
	if target:
		log_battle_info("[color=orange][b]{0}[/b][/color] 选择攻击 [color=blue][b]{1}[/b][/color]".format([current_turn_character.character_data.character_name, target.character_data.character_name]))
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
			log_battle_info("[color=cyan][回合][/color] [color=orange][b]{0}[/b][/color] 的回合开始".format([current_turn_character.character_data.character_name]))
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