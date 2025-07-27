extends Node2D

# 战斗状态枚举
enum BattleState {
	IDLE,           # 战斗开始或已结束的空闲状态
	BATTLE_START,   # 战斗初始化阶段
	ROUND_START,    # 回合开始，处理回合初效果，决定行动者
	PLAYER_TURN,    # 等待玩家输入并执行玩家行动
	ENEMY_TURN,     # AI 决定并执行敌人行动
	ACTION_EXECUTION, # 正在执行某个角色的具体行动
	ROUND_END,      # 回合结束，处理回合末效果，检查胜负
	VICTORY,        # 战斗胜利
	DEFEAT          # 战斗失败
}

var isPlayerTurn: bool = true
