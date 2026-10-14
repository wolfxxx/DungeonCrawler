extends CanvasLayer
## Victory / Game Over Screen

@export var is_victory: bool = false

func _ready():
	if is_victory:
		$Panel/VBox/Title.text = "VICTORY!"
		$Panel/VBox/Title.modulate = Color(0.3, 1.0, 0.45)
		$Panel/VBox/Message.text = "The Abyssal Warden has fallen! You conquered the Catacombs!"
	else:
		$Panel/VBox/Title.text = "YOU FELL IN BATTLE"
		$Panel/VBox/Title.modulate = Color(1.0, 0.3, 0.3)
		$Panel/VBox/Message.text = "The Catacombs claimed another soul..."

	$Background.modulate.a = 0.0
	$Panel.modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Background, "modulate:a", 0.85, 0.45)
	tween.tween_property($Panel, "modulate:a", 1.0, 0.45)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		_on_restart_pressed()
	elif event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed():
	get_tree().quit()
