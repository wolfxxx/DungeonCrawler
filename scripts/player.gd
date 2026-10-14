extends CharacterBody3D
## 3D Paladin Knight Controller
## Handles movement, 3-hit sword combo, dash with i-frames, Whirlwind Nova, and relic upgrades

@export var speed: float = 7.8
@export var acceleration: float = 42.0
@export var friction: float = 36.0

@export var max_health: int = 120
@export var current_health: int = 120
@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0
@export var stamina_regen: float = 18.0
@export var attack_damage: int = 20

var gold: int = 0
var kills: int = 0
var relics: Array[String] = []
var lifesteal: int = 0

var is_attacking: bool = false
var is_dashing: bool = false
var is_invulnerable: bool = false
var is_dead: bool = false
var combo_step: int = 0
var combo_reset_timer: float = 0.0
var walk_cycle: float = 0.0
var shake_trauma: float = 0.0
var base_cam_pos: Vector3 = Vector3(0, 12.2, 9.2)

@onready var pivot: Node3D = $Pivot
@onready var model: Node3D = $Pivot/Model
@onready var cam: Camera3D = $CameraRig/Camera3D

# Rig parts inside hero_knight.glb for procedural animation
var part_body: Node3D
var part_head: Node3D
var part_arm_r: Node3D
var part_arm_l: Node3D
var part_leg_l: Node3D
var part_leg_r: Node3D

func _ready():
	add_to_group("player")
	current_health = max_health
	current_stamina = max_stamina
	base_cam_pos = cam.position

	_cache_rig_parts()

	await get_tree().process_frame
	_sync_ui()
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_vo"):
		audio.play_vo("VoEnter")

func _cache_rig_parts():
	if not model:
		return
	part_body = model.find_child("Body", true, false) as Node3D
	part_head = model.find_child("Head", true, false) as Node3D
	part_arm_r = model.find_child("ArmR", true, false) as Node3D
	part_arm_l = model.find_child("ArmL", true, false) as Node3D
	part_leg_l = model.find_child("LegL", true, false) as Node3D
	part_leg_r = model.find_child("LegR", true, false) as Node3D

func _unhandled_input(event: InputEvent):
	if is_dead:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not is_attacking:
			_aim_toward_mouse()
			perform_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not is_dashing:
			perform_dash()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SHIFT and not is_dashing:
			perform_dash()
		elif (event.physical_keycode == KEY_Q or event.physical_keycode == KEY_E) and not is_attacking:
			perform_special_nova()

func _physics_process(delta: float):
	if is_dead:
		return

	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_step = 0

	if current_stamina < max_stamina:
		current_stamina = minf(max_stamina, current_stamina + stamina_regen * delta)
		var ui = get_tree().get_first_node_in_group("ui")
		if ui and ui.has_method("update_stamina"):
			ui.update_stamina(current_stamina, max_stamina)

	handle_movement(delta)
	handle_combat()
	move_and_slide()
	global_position.y = 0.0
	_animate_character(delta)
	_update_camera_shake(delta)

func handle_movement(delta: float):
	if is_dashing:
		return

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	if move_dir != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, move_dir.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * speed, acceleration * delta)
		if not is_attacking:
			var target_angle = atan2(-move_dir.x, -move_dir.z)
			pivot.rotation.y = lerp_angle(pivot.rotation.y, target_angle, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

func _aim_toward_mouse():
	if not cam:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_dir = cam.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, 0.8)
	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		var dir = (hit - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			pivot.rotation.y = atan2(-dir.x, -dir.z)

func handle_combat():
	if Input.is_action_just_pressed("attack") and not is_attacking:
		perform_attack()

func perform_attack():
	if current_stamina < 8.0:
		spawn_floating_text("NO STAMINA!", Color(1.0, 0.55, 0.2))
		return
	current_stamina -= 8.0
	is_attacking = true
	combo_step = (combo_step % 3) + 1
	combo_reset_timer = 0.85

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		audio.play_attack()

	# Forward lunge on combo
	var forward = -pivot.global_transform.basis.z.normalized()
	velocity += forward * (2.6 if combo_step < 3 else 4.8)

	# Animate sword arm slash (in Model's local space where +Z is forward and +X is left)
	if part_arm_r:
		var swing = create_tween()
		if combo_step == 2:
			swing.tween_property(part_arm_r, "rotation_degrees", Vector3(-60, 45, -20), 0.06)
			swing.tween_property(part_arm_r, "rotation_degrees", Vector3(65, -55, 15), 0.12)
		else:
			swing.tween_property(part_arm_r, "rotation_degrees", Vector3(-65, -45, 20), 0.06)
			swing.tween_property(part_arm_r, "rotation_degrees", Vector3(70, 50, -15), 0.12)
		swing.tween_property(part_arm_r, "rotation_degrees", Vector3.ZERO, 0.10)

	var attack_scene = preload("res://scenes/attack_area.tscn")
	var attack = attack_scene.instantiate()
	var dmg_mult = 1.0 if combo_step == 1 else (1.15 if combo_step == 2 else 1.45)
	attack.damage = int(round(attack_damage * dmg_mult))
	attack.is_special = false
	attack.attacker = self
	attack.forward_dir = forward
	get_parent().add_child(attack)
	attack.global_position = global_position + forward * 1.15
	attack.rotation.y = pivot.rotation.y

	_sync_ui()
	await get_tree().create_timer(0.28 if combo_step < 3 else 0.36).timeout
	is_attacking = false

func perform_special_nova():
	if current_stamina < 40.0:
		spawn_floating_text("LOW STAMINA!", Color(1.0, 0.6, 0.2))
		return
	current_stamina -= 40.0
	is_attacking = true
	add_trauma(0.35)

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_special"):
		audio.play_special()

	# 360 degree spin animation
	var spin = create_tween()
	spin.tween_property(pivot, "rotation:y", pivot.rotation.y + TAU, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var attack_scene = preload("res://scenes/attack_area.tscn")
	var attack = attack_scene.instantiate()
	attack.damage = int(round(attack_damage * 1.9))
	attack.is_special = true
	attack.knockback_force = 14.0
	attack.attacker = self
	get_parent().add_child(attack)
	attack.global_position = global_position

	_sync_ui()
	await get_tree().create_timer(0.36).timeout
	is_attacking = false

func perform_dash():
	if current_stamina < 22.0:
		return
	current_stamina -= 22.0
	is_dashing = true
	is_invulnerable = true

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_dash"):
		audio.play_dash()

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dash_dir = Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	if dash_dir == Vector3.ZERO:
		dash_dir = -pivot.global_transform.basis.z.normalized()
	else:
		pivot.rotation.y = atan2(-dash_dir.x, -dash_dir.z)

	velocity = dash_dir * (speed * 2.55)
	if part_body:
		var tilt = create_tween()
		tilt.tween_property(part_body, "rotation_degrees:x", 26.0, 0.1)
		tilt.tween_property(part_body, "rotation_degrees:x", 0.0, 0.16)

	_sync_ui()
	await get_tree().create_timer(0.24).timeout
	is_dashing = false
	await get_tree().create_timer(0.10).timeout
	is_invulnerable = false

func _animate_character(delta: float):
	var flat_speed = Vector2(velocity.x, velocity.z).length()
	if flat_speed > 0.4:
		walk_cycle += delta * flat_speed * 2.1
		var swing = sin(walk_cycle) * 34.0
		if part_leg_l:
			part_leg_l.rotation_degrees.x = swing
		if part_leg_r:
			part_leg_r.rotation_degrees.x = -swing
		if part_arm_l and not is_attacking:
			part_arm_l.rotation_degrees.x = -swing * 0.6
		if part_arm_r and not is_attacking:
			part_arm_r.rotation_degrees.x = swing * 0.6
		if part_body and not is_dashing:
			part_body.position.y = 0.75 + abs(sin(walk_cycle)) * 0.05
	else:
		walk_cycle += delta * 2.5
		if part_leg_l:
			part_leg_l.rotation_degrees.x = move_toward(part_leg_l.rotation_degrees.x, 0.0, 180.0 * delta)
		if part_leg_r:
			part_leg_r.rotation_degrees.x = move_toward(part_leg_r.rotation_degrees.x, 0.0, 180.0 * delta)
		if part_body and not is_dashing:
			part_body.position.y = 0.75 + sin(walk_cycle) * 0.02

func on_successful_hit(_was_special: bool):
	add_trauma(0.18)
	if lifesteal > 0 and current_health < max_health:
		current_health = min(max_health, current_health + lifesteal)
		_sync_ui()

func take_damage(amount: int):
	if is_invulnerable or is_dead:
		return
	current_health = max(0, current_health - amount)
	add_trauma(0.32)

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		audio.play_player_hit()

	spawn_floating_text("-" + str(amount), Color(1.0, 0.25, 0.25))
	_sync_ui()

	is_invulnerable = true
	await get_tree().create_timer(0.35).timeout
	is_invulnerable = false

	if current_health <= 0:
		die()

func heal(amount: int):
	if is_dead:
		return
	current_health = min(max_health, current_health + amount)
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		audio.play_pickup()
	spawn_floating_text("+" + str(amount) + " HP", Color(0.3, 1.0, 0.45))
	_sync_ui()

func collect_soul_gem(_amount: int):
	current_stamina = max_stamina
	attack_damage += 3
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		audio.play_pickup()
	spawn_floating_text("SOUL GEM! +3 ATK", Color(0.3, 0.95, 1.0))
	_sync_ui()

func add_gold(amount: int):
	gold += amount
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_gold"):
		audio.play_gold()
	spawn_floating_text("+" + str(amount) + " GOLD", Color(1.0, 0.85, 0.2))
	_sync_ui()

func grant_relic(relic_name: String, bonus_type: String):
	if not relics.has(relic_name):
		relics.append(relic_name)
	match bonus_type:
		"vampiric":
			lifesteal += 4
			spawn_floating_text(relic_name + " (+4 LIFESTEAL)", Color(1.0, 0.35, 0.5))
		"sunfire":
			attack_damage += 10
			spawn_floating_text(relic_name + " (+10 ATK)", Color(1.0, 0.65, 0.15))
		"dragonscale":
			max_health += 40
			current_health = max_health
			spawn_floating_text(relic_name + " (+40 MAX HP)", Color(0.35, 0.9, 1.0))
		"windwalker":
			speed += 1.6
			stamina_regen += 8.0
			spawn_floating_text(relic_name + " (+SPEED & STAMINA)", Color(0.4, 1.0, 0.6))
	_sync_ui()

func spawn_floating_text(txt: String, col: Color):
	var lbl = Label3D.new()
	lbl.text = txt
	lbl.font_size = 42
	lbl.outline_size = 10
	lbl.modulate = col
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 2.1, 0.0)
	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 1.3, 0.75)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75)
	tw.chain().tween_callback(lbl.queue_free)

func add_trauma(amount: float):
	shake_trauma = minf(1.0, shake_trauma + amount)

func _update_camera_shake(delta: float):
	if shake_trauma > 0.0:
		shake_trauma = maxf(0.0, shake_trauma - delta * 2.4)
		var amt = shake_trauma * shake_trauma * 0.38
		cam.position = base_cam_pos + Vector3(
			randf_range(-amt, amt),
			randf_range(-amt, amt),
			randf_range(-amt, amt)
		)
	else:
		cam.position = base_cam_pos

func _sync_ui():
	var ui = get_tree().get_first_node_in_group("ui")
	if not ui:
		return
	if ui.has_method("update_health"):
		ui.update_health(current_health, max_health)
	if ui.has_method("update_stamina"):
		ui.update_stamina(current_stamina, max_stamina)
	if ui.has_method("update_stats"):
		ui.update_stats(gold, attack_damage, relics)

func die():
	if is_dead:
		return
	is_dead = true
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		audio.play_game_over()

	var game_over_scene = preload("res://scenes/game_over.tscn")
	var game_over = game_over_scene.instantiate()
	game_over.is_victory = false
	get_tree().current_scene.add_child(game_over)
	set_physics_process(false)
