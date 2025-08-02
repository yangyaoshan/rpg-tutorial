extends Node2D
class_name DefenseIndicator

@onready var label : Label = $Label


func show_indicator():
	visible = true
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func hide_indicator():
	visible = true
	scale = Vector2.ONE
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
