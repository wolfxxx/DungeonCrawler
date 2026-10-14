extends CharacterBody3D
## 3D Dungeon Monster & Boss AI
## Supports Skeleton Executioner, Goblin Stalker, Obsidian Golem, Cultist Necromancer, and Boss Demon Lord

@export var enemy_type: String = "skeleton" # "skeleton", "goblin", "golem", "mage", "boss"
@export var display_name: String = "Skeleton Executioner"
@export var chamber_id: int = 0
@export var max_health: int = 45
@export var current_health: int = 45
@export var speed: float = 4.2
@export var detection_range: float = 16.0
@export var attack_range: float = 1.9
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.1

var player: CharacterBody3D = null
var can_attack: bool = true
var is_dead: bool = false
var knockback_vel: Vector3 = Vector3.ZERO
var walk_cycle: float = 0.0
var boss_activated: bool = false
var ranged_cooldown: float = 2.4

@onready var pivot: Node3D = $Pivot
@onready var model: Node3D = $Pivot/Model

var part_body: Node3D
var part_head: Node3D
var part_arm_r: Node3D
var part_arm_l: Node3D
var part_leg_l: Node3D
var part_leg_r: Node3D

func _ready():
	add_to_group("enemies")
	current_health = max_health
	walk_cycle = randf() * TAU

	if enemy_type == "mage":
		_swap_model("res://models/enemy_mage.glb")
	elif enemy_type == "boss":
		_swap_model("res://models/boss_demon_lord.glb")
		if has_node("HealthBar"):
			$HealthBar.position.y = 2.85
			$HealthBar.scale = Vector3(1.6, 1.4, 1.6)

	_cache_rig_parts()

	if has_node("HealthBar"):
		$HealthBar.update_health(current_health, max_health)

func _swap_model(res_path: String):
	if pivot.has_node("Model"):
		pivot.get_node("Model").queue_free()
	var sc = load(res_path)
	if sc:
		var inst = sc.instantiate()
		inst.name = "Model"
		inst.rotation_degrees.y = 180.0
		pivot.add_child(inst)
		model = inst

func _cache_rig_parts():
	if not model:
		return
	part_body = model.find_child("Body", true, false) as Node3D
	part_head = model.find_child("Head", true, false) as Node3D
	part_arm_r = model.find_child("ArmR", true, false) as Node3D
	part_arm_l = model.find_child("ArmL", true, false) as Node3D
	part_leg_l = model.find_child("LegL", true, false) as Node3D
	part_leg_r = model.find_child("LegR", true, false) as Node3D

func _physics_process(delta: float):
	if is_dead:
		return

	find_player()
	knockback_vel = knockback_vel.move_toward(Vector3.ZERO, 28.0 * delta)

	if player and not player.get("is_dead"):
		var room = get_tree().get_first_node_in_group("dungeon_room")
		var chamber_unlocked = true
		if room and room.has_method("is_chamber_accessible"):
			chamber_unlocked = room.is_chamber_accessible(chamber_id)
		var dist = global_position.distance_to(player.global_position)
		if chamber_unlocked and dist < detection_range:
			if enemy_type == "boss" and not boss_activated:
				_activate_boss()
			follow_and_fight(delta, dist)
		else:
			velocity = knockback_vel
	else:
		velocity = knockback_vel

	move_and_slide()
	global_position.y = 0.0
	_animate_monster(delta)

func _activate_boss():
	boss_activated = true
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		if audio.has_method("play_boss_roar"):
			audio.play_boss_roar()
		if audio.has_method("play_vo"):
			audio.play_vo("VoBoss")
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_boss_bar"):
		ui.show_boss_bar(display_name, current_health, max_health)

func find_player():
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D

func follow_and_fight(delta: float, dist: float):
	var dir = (player.global_position - global_position)
	dir.y = 0.0
	var norm_dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD

	# Face player smoothly
	var target_yaw = atan2(-norm_dir.x, -norm_dir.z)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, target_yaw, 10.0 * delta)

	if enemy_type == "mage":
		# Keep medium distance and cast arcane bolts
		if dist > 7.5:
			velocity = norm_dir * speed + knockback_vel
		elif dist < 4.2:
			velocity = -norm_dir * (speed * 0.75) + knockback_vel
		else:
			velocity = knockback_vel
		ranged_cooldown -= delta
		if ranged_cooldown <= 0.0 and dist < 13.0:
			ranged_cooldown = attack_cooldown
			_cast_projectile(norm_dir, Color(0.8, 0.2, 1.0), attack_damage)
	elif enemy_type == "boss":
		if dist > attack_range:
			velocity = norm_dir * speed + knockback_vel
		else:
			velocity = knockback_vel
			if can_attack:
				_perform_melee_attack()
		ranged_cooldown -= delta
		if ranged_cooldown <= 0.0 and dist < 16.0:
			ranged_cooldown = 3.2
			_cast_boss_volley(norm_dir)
	else:
		if dist > attack_range * 0.85:
			velocity = norm_dir * speed + knockback_vel
		else:
			velocity = knockback_vel
		if dist <= attack_range and can_attack:
			_perform_melee_attack()

func _perform_melee_attack():
	if not player or not can_attack or is_dead:
		return
	can_attack = false

	if part_arm_r:
		var tw = create_tween()
		tw.tween_property(part_arm_r, "rotation_degrees:x", -55.0, 0.12)
		tw.tween_property(part_arm_r, "rotation_degrees:x", 65.0, 0.12)
		tw.tween_property(part_arm_r, "rotation_degrees:x", 0.0, 0.16)

	await get_tree().create_timer(0.14).timeout
	if is_dead or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= attack_range + 0.65:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _cast_projectile(dir: Vector3, col: Color, dmg: int):
	if part_arm_r:
		var tw = create_tween()
		tw.tween_property(part_arm_r, "rotation_degrees:x", 50.0, 0.15)
		tw.tween_property(part_arm_r, "rotation_degrees:x", 0.0, 0.25)

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_fireball"):
		audio.play_fireball()

	_spawn_orb(global_position + Vector3(0, 1.1, 0) + dir * 0.7, dir, col, dmg)

func _cast_boss_volley(center_dir: Vector3):
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_fireball"):
		audio.play_fireball()

	for angle_deg in [-22.0, 0.0, 22.0]:
		var rotated_dir = center_dir.rotated(Vector3.UP, deg_to_rad(angle_deg)).normalized()
		_spawn_orb(global_position + Vector3(0, 1.35, 0) + rotated_dir * 0.9, rotated_dir, Color(1.0, 0.4, 0.05), int(round(attack_damage * 0.8)))

func _spawn_orb(start_pos: Vector3, dir: Vector3, col: Color, dmg: int):
	var orb = Area3D.new()
	orb.collision_layer = 0
	orb.collision_mask = 1
	var shape_node = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.32
	shape_node.shape = sphere
	orb.add_child(shape_node)

	var mesh_inst = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.48
	mesh_inst.mesh = sm
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mesh_inst.material_override = mat
	orb.add_child(mesh_inst)

	var light = OmniLight3D.new()
	light.light_color = col
	light.light_energy = 2.2
	light.omni_range = 3.2
	orb.add_child(light)

	get_parent().add_child(orb)
	orb.global_position = start_pos

	orb.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(dmg)
			orb.queue_free()
		elif body is StaticBody3D:
			orb.queue_free()
	)

	var travel = orb.create_tween()
	travel.tween_property(orb, "global_position", start_pos + dir * 15.0, 1.8)
	travel.tween_callback(orb.queue_free)

func _animate_monster(delta: float):
	var flat_spd = Vector2(velocity.x, velocity.z).length()
	if flat_spd > 0.3:
		walk_cycle += delta * flat_spd * 2.3
		var sw = sin(walk_cycle) * 30.0
		if part_leg_l:
			part_leg_l.rotation_degrees.x = sw
		if part_leg_r:
			part_leg_r.rotation_degrees.x = -sw
		if part_arm_l:
			part_arm_l.rotation_degrees.x = -sw * 0.5
	else:
		if part_leg_l:
			part_leg_l.rotation_degrees.x = move_toward(part_leg_l.rotation_degrees.x, 0.0, 140.0 * delta)
		if part_leg_r:
			part_leg_r.rotation_degrees.x = move_toward(part_leg_r.rotation_degrees.x, 0.0, 140.0 * delta)

func take_damage(amount: int, kb: Vector3 = Vector3.ZERO):
	if is_dead:
		return
	current_health = max(0, current_health - amount)
	knockback_vel = kb * (0.35 if enemy_type == "boss" or enemy_type == "golem" else 1.0)

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		audio.play_enemy_hit()

	if has_node("HealthBar"):
		$HealthBar.update_health(current_health, max_health)

	if enemy_type == "boss":
		if not boss_activated:
			_activate_boss()
		var ui = get_tree().get_first_node_in_group("ui")
		if ui and ui.has_method("update_boss_bar"):
			ui.update_boss_bar(current_health, max_health)

	_spawn_damage_number(amount)

	# Hit scale punch
	var punch = create_tween()
	punch.tween_property(pivot, "scale", Vector3(1.18, 0.86, 1.18), 0.06)
	punch.tween_property(pivot, "scale", Vector3.ONE, 0.10)

	if current_health <= 0:
		die()

func _spawn_damage_number(amount: int):
	var lbl = Label3D.new()
	lbl.text = str(amount)
	lbl.font_size = 46
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.9, 0.25) if amount < 30 else Color(1.0, 0.45, 0.1)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector3(randf_range(-0.35, 0.35), 1.9, randf_range(-0.2, 0.2))
	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 1.2, 0.55)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(lbl.queue_free)

func die():
	if is_dead:
		return
	is_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		audio.play_enemy_death()

	# Drop loot
	var pickup_scene = preload("res://scenes/health_pickup.tscn")
	var roll = randf()
	if enemy_type == "boss" or roll < 0.72:
		var pickup = pickup_scene.instantiate()
		if enemy_type == "boss" or roll < 0.25:
			pickup.pickup_type = "soul_gem"
			pickup.amount = 1
		elif roll < 0.52:
			pickup.pickup_type = "health"
			pickup.amount = 35
		else:
			pickup.pickup_type = "gold"
			pickup.amount = randi_range(15, 35)
		get_parent().add_child(pickup)
		pickup.global_position = global_position

	# Notify room & UI
	var room = get_tree().get_first_node_in_group("dungeon_room")
	if room and room.has_method("on_enemy_defeated"):
		room.call_deferred("on_enemy_defeated", chamber_id, enemy_type == "boss")

	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		if enemy_type == "boss" and ui.has_method("hide_boss_bar"):
			ui.hide_boss_bar()
		if ui.has_method("update_enemies_remaining"):
			ui.call_deferred("update_enemies_remaining")

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(pivot, "scale", Vector3.ZERO, 0.28)
	tween.tween_property(pivot, "rotation_degrees:x", -85.0, 0.28)
	tween.chain().tween_callback(queue_free)
