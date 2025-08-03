extends Node2D
# UI引用
@onready var attack_button: Button = %AttackButton
@onready var defend_button: Button = %DefendButton
@onready var action_panel: Panel = %ActionPanel
@onready var info_label: RichTextLabel = %InfoLabel
@onready var battle_manager: Node = %BattleManager

func _ready():
	attack_button.pressed.connect(battle_manager.player_attack)
	defend_button.pressed.connect(battle_manager.player_defend)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.battle_info_logged.connect(update_battle_info)
	find_characters()
	battle_manager.start_battle()


func show_action_ui(flag: bool):
	if action_panel:
		action_panel.visible = flag

func update_label(text: String):
	if info_label:
		info_label.text += "\n" + text

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
