extends Node
class_name BattleManager

## 主要用于回合流程的管理

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/UI/damage_number.tscn")

const BattleStateManager = preload("res://scenes/battle/battle_state_manager.gd")
var state_manager = BattleStateManager.new()

# 信号
signal turn_changed(character: Character)
signal battle_ended(is_victory: bool)
signal battle_info_logged(text: String)
# signal effect_applied(effect_type: String, source: Character, target: Character, result: Dictionary)
# signal skill_executed(caster: Character, targets: Array[Character], skill_data: SkillData, results: Dictionary)

@export var heal_min_range: float = 0.95
@export var heal_max_range: float = 1.05
@export var heal_magic_coef: float = 1.0


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
	SkillSystem.battle_manager = self
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
			_log_battle_info("[color=yellow][战斗系统][/color] 新的回合开始")
			if check_battle_end_condition():
				# 战斗已结束，状态已在check_battle_end_condition中切换
				return
				
			_build_turn_queue()
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
			_log_battle_info("[color=cyan][回合][/color] [color=orange][b]{0}[/b][/color] 的回合开始".format([current_turn_character.character_name]))
			current_turn_character.on_turn_start(self)
			# 根据角色类型决定下一个状态
			var next_state = BattleStateManager.BattleState.PLAYER_TURN if player_characters.has(current_turn_character) else BattleStateManager.BattleState.ENEMY_TURN
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
			current_turn_character.on_turn_end(self)
			# 进入下一个角色的回合
			state_manager.change_state(BattleStateManager.BattleState.TURN_START)
			
		BattleStateManager.BattleState.ROUND_END:
			# 大回合结束，进入新的回合
			_log_battle_info("[color=yellow][战斗系统][/color] 回合结束")
			state_manager.change_state(BattleStateManager.BattleState.ROUND_START)
		BattleStateManager.BattleState.VICTORY:
			_log_battle_info("[color=green][b]===== 战斗胜利! =====[/b][/color]")
			battle_ended.emit(true)
		BattleStateManager.BattleState.DEFEAT:
			_log_battle_info("[color=red][b]===== 战斗失败... =====[/b][/color]")
			battle_ended.emit(false)

## 构建回合队列
func _build_turn_queue() -> void:
	# 清空当前队列
	turn_queue.clear()
	
	# 将所有存活的角色添加到队列中
	for character in player_characters:
		if character.current_hp > 0:
			turn_queue.append(character)
			
	for character in enemy_characters:
		if character.current_hp > 0:
			turn_queue.append(character)
	
	# 根据速度属性排序
	turn_queue.sort_custom(func(a, b): return a.speed > b.speed)
	
	_log_battle_info("[color=yellow][战斗系统][/color] 回合队列已建立: [color=green][b]{0}[/b][/color] 个角色".format([turn_queue.size()]))


# 获取有效的友方目标列表
# include_self: 是否包括施法者自己
func get_valid_ally_targets(include_self: bool = false, caster: Character = null) -> Array[Character]:
	if caster == null:
		caster = current_turn_character
	var valid_targets: Array[Character] = []
	
	for ally in player_characters:
		if ally.is_alive() && (include_self || ally != caster):
			valid_targets.append(ally)
	
	return valid_targets

# 获取有效的敌方目标列表（过滤掉已倒下的角色）
func get_valid_enemy_targets(caster: Character = null) -> Array[Character]:
	if caster == null:
		caster = current_turn_character
	var valid_targets: Array[Character] = []
	
	var enemies = enemy_characters if caster not in enemy_characters else player_characters
	for enemy in enemies:
		if enemy.is_alive and enemy != caster:
			valid_targets.append(enemy)
	
	return valid_targets

# 玩家选择行动 - 由BattleScene调用
func player_select_action(action_type: CharacterCombatComponent.ActionType, target: Character = null, params: Dictionary = {}) -> void:
	if not state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		return
		
	print_rich("[color=cyan]玩家选择行动: %s[/color]" % action_type)
	
	params.merge({"skill_context": SkillSystem.SkillExecutionContext.new(self)}, true)
	current_turn_character.execute_action(action_type, target, params)

	# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

# 在初始化方法中注册新的效果处理器
func _init_effect_processors():
	# 注册处理器
	register_effect_processor(DamageEffectProcessor.new(self))
	register_effect_processor(HealingEffectProcessor.new(self))
	register_effect_processor(ApplyStatusProcessor.new(self))

## 注册效果处理器
func register_effect_processor(processor: EffectProcessor):
	var processor_id = processor.get_processor_id()
	effect_processors[processor_id] = processor
	print("注册效果处理器: %s" % processor_id)

# 检查战斗结束条件
func check_battle_end_condition() -> bool:
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
		state_manager.change_state(BattleStateManager.BattleState.DEFEAT)
		return true
	if all_enemies_defeated:
		# 敌人全部阵亡，战斗胜利
		state_manager.change_state(BattleStateManager.BattleState.VICTORY)
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
		_log_battle_info("[color=orange][b]{0}[/b][/color] 选择攻击 [color=blue][b]{1}[/b][/color]".format([current_turn_character.character_name, target.character_name]))
		current_turn_character.execute_action(CharacterCombatComponent.ActionType.ATTACK, target)
	else:
		_log_battle_info("[color=red][错误][/color] 敌人找不到可攻击的目标")
		
	# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
	
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

## 战斗日志
func _log_battle_info(text: String) -> void:
	print_rich(text)
	battle_info_logged.emit(text)

## 开始战斗
func start_battle() -> void:
	_log_battle_info("[color=yellow][b]===== 战斗开始! =====[/b][/color]")
	
	if player_characters.is_empty() or enemy_characters.is_empty():
		push_error("无法开始战斗：缺少玩家或敌人!")
		return
	state_manager.change_state(BattleStateManager.BattleState.START)
