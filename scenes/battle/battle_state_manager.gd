extends Node

# 将BattleState枚举定义在这里，作为这个模块的内部定义
enum BattleState {
	IDLE,
	START,
	ROUND_START,
	ROUND_END,
	TURN_START,
	TURN_END,
	PLAYER_TURN,
	ENEMY_TURN,
	VICTORY,
	DEFEAT
}

var current_state: BattleState = BattleState.IDLE
var previous_state: BattleState = BattleState.IDLE

signal state_changed(previous_state: BattleState, new_state: BattleState)

func init(initial_state: BattleState = BattleState.IDLE):
	current_state = initial_state
	previous_state = initial_state
	print_rich("[color=purple][状态机][/color] 已初始化，初始状态为: %s" % BattleState.keys()[current_state])

func change_state(new_state: BattleState):
	if current_state == new_state:
		return
	previous_state = current_state
	current_state = new_state
	
	# 打印日志并发出信号
	state_changed.emit(previous_state, current_state)
