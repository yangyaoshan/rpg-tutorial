extends EffectProcessor
class_name ApplyStatusProcessor
func get_processor_id() -> StringName:
	return &"status"


func can_process_effect(effect_data: SkillEffectData) -> bool:
	return effect_data.effect_type == SkillEffectData.EffectType.STATUS

func process_effect(effect_data: SkillEffectData, source: Character, target: Character) -> Dictionary:
	var results := {"success": false, "applied_status_id": null, "reason": "unknown"}
	
	var status_template_to_apply: SkillStatusData = effect_data.status_to_apply
	if not is_instance_valid(status_template_to_apply):
		results["error"] = "Invalid status_template in effect_data."
		push_error("ApplyStatusEffectProcessor: " + results.error)
		return results

	results["applied_status_id"] = status_template_to_apply.status_id # 记录尝试应用的ID

	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	var chance = effect_data.status_application_chance # 从 SkillEffectData 获取几率
	var applied_by_chance = _check_if_can_apply_status_by_chance(chance)
	
	if not applied_by_chance:
		# 未通过几率判定
		results["reason"] = "chance_roll_failed"
		var resist_message = "[color=teal]%s 抵抗了状态效果 %s (几率判定)[/color]" % [target.character_name, status_template_to_apply.status_name]
		print_rich(resist_message)
		return results
	
	# 将 effect_data 传递给 Character 的方法，以便获取 duration_override 和 stacks_to_apply
	var application_result: Dictionary = target.apply_skill_status(status_template_to_apply, source, effect_data)
	
	results["success"] = application_result.get("applied_successfully", false)
	results["reason"] = application_result.get("reason", "char_apply_failed") # 从Character方法获取原因
	
	var applied_status_instance: SkillStatusData = application_result.get("status_instance")

	if results.success and is_instance_valid(applied_status_instance):
		results["reason"] = application_result.get("reason", "applied") # 更新为成功的reason

		# 状态成功应用/更新后，触发其初始效果
		if not applied_status_instance.initial_effects.is_empty():
			if _battle_manager and _battle_manager.has_method("_apply_skill_effects_to_targets"):
				await _battle_manager._apply_skill_effects_to_targets(
					applied_status_instance.get_initial_effects(),
					applied_status_instance.source_char,
					[target]
				)
			else:
				push_warning("ApplyStatusEffectProcessor: Cannot trigger initial_effects - BattleManager or method missing.")
		
		# 播放状态效果成功应用的动画
		_request_visual_effect(&"status_applied_success", target, {"status_id": applied_status_instance.status_id, "status_name": applied_status_instance.status_name, "is_buff": applied_status_instance.status_type == SkillStatusData.StatusType.BUFF})
		if effect_data.visual_effect != "": # 效果自定义的视觉
			_request_visual_effect(effect_data.visual_effect, target, {"status_name": applied_status_instance.status_name})

		var message = "[color=purple]%s 被施加了 %s 状态 (来源: %s)[/color]" % [target.character_name, applied_status_instance.status_name, source.character_name]
		print_rich(message)
	# else if results.success is false but a status_instance was returned (e.g. for update signals)
	#    pass # Might be just an update, not a new application, but still successful in a way
	elif not results.success: # apply_status_effect 返回失败
		_request_visual_effect(&"status_apply_failed_logic", target, {"status_id": status_template_to_apply.status_id, "reason": results.reason})
		var fail_message = "[color=orange]%s 未能被施加 %s 状态 (原因: %s)[/color]" % [target.character_name, status_template_to_apply.status_name, results.reason]
		print_rich(fail_message)

	return results

## 判断概率是否可以施加状态
func _check_if_can_apply_status_by_chance(chance: float) -> bool:
	return randf() <= chance
