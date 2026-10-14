extends CharacterBody3D
## Tactical 3D Dungeon Monster & Boss AI
## Features:
## - Surround / Flank Slot Assignment & Separation Steering (no brainless single-file clumping)
## - Archetype Combat Behaviors:
##   * Skeleton Executioner: Raises Buckler Shield Stance (blocks frontal light slashes; flank or use Q/E Nova to break guard!) + Telegraphed Cleaver Lunge
##   * Shadow Goblin: High-speed flanking, backstab dash from a red ground line telegraph, and hit-and-run retreat after striking
##   * Obsidian Rune Golem: Unstoppable heavy tank with telegraphed crimson AoE Ground Slam shockwave (must dash/move out!)
##   * Cultist Necromancer: Predictive lead-target arcane bolt volleys + Shadow Blink teleport when player closes in
##   * The Abyssal Warden (Boss): 3-Phase Boss AI with Hellfire Meteor Rain AoEs, Dash Cleave, and Spiral Bullet-Hell Orbs

@export var enemy_type: String = "skeleton" # "skeleton", "goblin", "golem", "mage", "boss"
@export var display_name: String = "Skeleton Executioner"
@export var chamber_id: int = 0
@export var max_health: int = 55
@export var current_health: int = 55
@export var speed: float = 4.4
@export var detection_range: float = 16.5
@export var attack_range: float = 2.0
@export var attack_damage: int = 12
@export var attack_cooldown: float = 1.25

var player: CharacterBody3D = null
var can_attack: bool = true
var is_winding_up: bool = false
var is_dead: bool = false
var knockback_vel: Vector3 = Vector3.ZERO
var walk_cycle: float = 0.0
var boss_activated: bool = false
var ranged_cooldown: float = 2.2
var special_cooldown: float = 3.5

# Tactical AI state
var flank_angle_offset: float = 0.0
var strafe_dir: float = 1.0
var strafe_timer: float = 0.0
var retreat_timer: float = 0.0
var is_blocking: bool = false
var block_timer: float = 0.0
var shield_visual: MeshInstance3D = null

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
	flank_angle_offset = randf_range(-PI * 0.65, PI * 0.65)
	strafe_dir = 1.0 if randf() > 0.5 else -1.0
	strafe_timer = randf_range(1.2, 2.8)
	special_cooldown = randf_range(1.5, 3.5)

	if enemy_type == "mage":
		_swap_model("res://models/enemy_mage.glb")
	elif enemy_type == "boss":
		_swap_model("res://models/boss_demon_lord.glb")
		if has_node("HealthBar"):
			$HealthBar.position.y = 2.85
			$HealthBar.scale = Vector3(1.6, 1.4, 1.6)

	_cache_rig_parts()
	if enemy_type == "skeleton":
		_create_shield_stance_visual()

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

func _create_shield_stance_visual():
	shield_visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.2
	shield_visual.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.78, 1.0, 0.28)
	shield_visual.material_override = mat
	shield_visual.position = Vector3(0, 0.9, -0.45)
	shield_visual.visible = false
	pivot.add_child(shield_visual)

func _physics_process(delta: float):
	if is_dead:
		return

	find_player()
	knockback_vel = knockback_vel.move_toward(Vector3.ZERO, 28.0 * delta)

	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_dir = -strafe_dir
		strafe_timer = randf_range(1.4, 3.0)

	if retreat_timer > 0.0:
		retreat_timer -= delta

	if block_timer > 0.0:
		block_timer -= delta
		if block_timer <= 0.0:
			_set_blocking(false)

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

func _set_blocking(active: bool):
	is_blocking = active
	if shield_visual:
		shield_visual.visible = active
	if part_arm_l:
		part_arm_l.rotation_degrees = Vector3(-50, 35, 0) if active else Vector3.ZERO

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

func _compute_separation_force() -> Vector3:
	var sep := Vector3.ZERO
	var desired_space := 2.1 if enemy_type != "golem" else 2.8
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		var diff: Vector3 = global_position - other.global_position
		diff.y = 0.0
		var d := diff.length()
		if d > 0.01 and d < desired_space:
			sep += diff.normalized() * ((desired_space - d) / desired_space) * 4.5
	return sep

func follow_and_fight(delta: float, dist: float):
	var to_player = (player.global_position - global_position)
	to_player.y = 0.0
	var norm_dir = to_player.normalized() if to_player.length() > 0.01 else Vector3.FORWARD
	var tangent = Vector3(-norm_dir.z, 0.0, norm_dir.x) * strafe_dir
	var sep = _compute_separation_force()

	# Face player smoothly (unless locked in lunge windup)
	if not is_winding_up:
		var target_yaw = atan2(-norm_dir.x, -norm_dir.z)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, target_yaw, 11.0 * delta)

	if is_winding_up:
		velocity = knockback_vel
		return

	match enemy_type:
		"skeleton":
			_ai_skeleton(delta, dist, norm_dir, tangent, sep)
		"goblin":
			_ai_goblin(delta, dist, norm_dir, tangent, sep)
		"golem":
			_ai_golem(delta, dist, norm_dir, tangent, sep)
		"mage":
			_ai_mage(delta, dist, norm_dir, tangent, sep)
		"boss":
			_ai_boss(delta, dist, norm_dir, tangent, sep)

func _ai_skeleton(delta: float, dist: float, norm_dir: Vector3, tangent: Vector3, sep: Vector3):
	# Skeleton Executioner: Tactical shield guard while circling, then lunging cleaver strike
	special_cooldown -= delta
	if dist < 5.5 and dist > 1.8 and special_cooldown <= 0.0 and not is_blocking and can_attack:
		_set_blocking(true)
		block_timer = 1.9
		special_cooldown = 4.6

	var move_spd = speed * (0.58 if is_blocking else 1.0)
	if retreat_timer > 0.0:
		velocity = (-norm_dir * 0.75 + tangent * 0.65).normalized() * speed + sep + knockback_vel
	elif dist > attack_range * 1.15:
		# Approach along flank curve rather than straight line
		var flank_dir = (norm_dir + tangent * 0.42).normalized()
		velocity = flank_dir * move_spd + sep + knockback_vel
	else:
		velocity = tangent * (move_spd * 0.55) + sep + knockback_vel
		if can_attack:
			_set_blocking(false)
			_perform_telegraphed_cleave(norm_dir)

func _ai_goblin(delta: float, dist: float, norm_dir: Vector3, tangent: Vector3, sep: Vector3):
	# Shadow Goblin: Fast flanker that circles behind player, dashes in with twin daggers, then darts away!
	special_cooldown -= delta
	if retreat_timer > 0.0:
		# Hit-and-run evasive retreat!
		velocity = (-norm_dir * 0.9 + tangent * 0.5).normalized() * (speed * 1.2) + sep + knockback_vel
		return

	if dist < 6.8 and dist > 2.6 and special_cooldown <= 0.0 and can_attack:
		special_cooldown = 3.8
		_perform_goblin_pounce(norm_dir)
		return

	if dist > attack_range:
		# Wide flanking arc toward player's rear/side
		var flank_weight = clampf((dist - 1.5) / 5.0, 0.25, 0.85)
		var desired = (norm_dir + tangent * flank_weight).normalized()
		velocity = desired * speed + sep + knockback_vel
	else:
		velocity = tangent * (speed * 0.8) + sep + knockback_vel
		if can_attack:
			_perform_goblin_quick_slash(norm_dir)

func _ai_golem(delta: float, dist: float, norm_dir: Vector3, _tangent: Vector3, sep: Vector3):
	# Obsidian Rune Golem: Heavy Juggernaut with telegraphed crimson AoE Ground Slam
	special_cooldown -= delta
	if dist <= 3.4 and special_cooldown <= 0.0 and can_attack:
		special_cooldown = 4.5
		_perform_golem_ground_slam()
		return

	if dist > attack_range:
		velocity = norm_dir * speed + sep * 0.5 + knockback_vel
	else:
		velocity = knockback_vel
		if can_attack:
			_perform_golem_ground_slam()

func _ai_mage(delta: float, dist: float, norm_dir: Vector3, tangent: Vector3, sep: Vector3):
	# Cultist Necromancer: Keeps distance, blinks away when rushed, fires lead-predicted arcane bolts
	special_cooldown -= delta
	if dist < 3.6 and special_cooldown <= 0.0:
		special_cooldown = 5.2
		_perform_mage_blink(-norm_dir + tangent * 0.6)
		return

	if dist > 8.2:
		velocity = (norm_dir + tangent * 0.35).normalized() * speed + sep + knockback_vel
	elif dist < 4.8:
		velocity = (-norm_dir + tangent * 0.45).normalized() * (speed * 0.92) + sep + knockback_vel
	else:
		velocity = tangent * (speed * 0.68) + sep + knockback_vel

	ranged_cooldown -= delta
	if ranged_cooldown <= 0.0 and dist < 14.0:
		ranged_cooldown = 2.1
		_cast_predictive_bolt()

func _ai_boss(delta: float, dist: float, norm_dir: Vector3, tangent: Vector3, sep: Vector3):
	# The Abyssal Warden: Multi-attack Boss with Hellfire Meteor AoEs, Dash Cleave, and 5-Way Orb Fan
	var enraged = current_health < max_health * 0.55
	var spd_mult = 1.25 if enraged else 1.0

	special_cooldown -= delta
	ranged_cooldown -= delta

	if special_cooldown <= 0.0 and can_attack:
		special_cooldown = 3.4 if enraged else 4.6
		if dist > 4.2 and randf() < 0.55:
			_perform_boss_dash_cleave(norm_dir)
			return
		else:
			_perform_boss_meteor_call()
			return

	if ranged_cooldown <= 0.0 and dist < 17.0:
		ranged_cooldown = 2.4 if enraged else 3.2
		_cast_boss_volley(norm_dir, enraged)

	if dist > attack_range:
		velocity = (norm_dir + tangent * 0.28).normalized() * (speed * spd_mult) + sep * 0.3 + knockback_vel
	else:
		velocity = tangent * (speed * 0.45) + knockback_vel
		if can_attack:
			_perform_telegraphed_cleave(norm_dir)

# ============================================================================
# TELEGRAPHED TACTICAL ATTACKS
# ============================================================================

func _spawn_ground_telegraph(pos: Vector3, radius: float, duration: float, col: Color) -> Node3D:
	var marker = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.05
	cyl.radial_segments = 28
	marker.mesh = cyl

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.18)
	marker.material_override = mat

	get_parent().add_child(marker)
	marker.global_position = Vector3(pos.x, 0.05, pos.z)
	marker.scale = Vector3(0.2, 1.0, 0.2)

	var tw = marker.create_tween()
	tw.set_parallel(true)
	tw.tween_property(marker, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.58, duration)
	tw.chain().tween_callback(marker.queue_free)
	return marker

func _perform_telegraphed_cleave(lunge_dir: Vector3):
	can_attack = false
	is_winding_up = true

	var strike_pos = global_position + lunge_dir * 1.35
	var strike_radius = 1.65 if enemy_type != "boss" else 2.4
	var windup_time = 0.42 if enemy_type != "boss" else 0.48

	_spawn_ground_telegraph(strike_pos, strike_radius, windup_time, Color(1.0, 0.22, 0.15))

	# Raise weapon overhead during wind-up
	if part_arm_r:
		var w_tw = create_tween()
		w_tw.tween_property(part_arm_r, "rotation_degrees:x", -95.0, windup_time)

	await get_tree().create_timer(windup_time).timeout
	if is_dead or not is_instance_valid(player):
		is_winding_up = false
		return

	is_winding_up = false
	# Lunge forward and cleave!
	knockback_vel = lunge_dir * 7.5
	if part_arm_r:
		var s_tw = create_tween()
		s_tw.tween_property(part_arm_r, "rotation_degrees:x", 75.0, 0.10)
		s_tw.tween_property(part_arm_r, "rotation_degrees:x", 0.0, 0.18)

	if player.global_position.distance_to(strike_pos) <= strike_radius + 0.35:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

	retreat_timer = 0.65
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _perform_goblin_pounce(pounce_dir: Vector3):
	can_attack = false
	is_winding_up = true

	var target_spot = global_position + pounce_dir * 3.8
	_spawn_ground_telegraph(target_spot, 1.35, 0.36, Color(1.0, 0.55, 0.1))
	_spawn_status_text("AMBUSH!", Color(1.0, 0.65, 0.2))

	if part_body:
		var crouch = create_tween()
		crouch.tween_property(part_body, "position:y", 0.48, 0.32)

	await get_tree().create_timer(0.36).timeout
	if is_dead or not is_instance_valid(player):
		is_winding_up = false
		return

	is_winding_up = false
	knockback_vel = pounce_dir * 15.5
	if part_body:
		part_body.position.y = 0.75

	await get_tree().create_timer(0.16).timeout
	if is_dead or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= 1.85:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage + 3)

	# Immediately dart away after pouncing!
	retreat_timer = 1.25
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _perform_goblin_quick_slash(_dir: Vector3):
	can_attack = false
	is_winding_up = true
	_spawn_ground_telegraph(global_position - pivot.global_transform.basis.z * 1.0, 1.25, 0.26, Color(1.0, 0.4, 0.15))

	if part_arm_r:
		var tw = create_tween()
		tw.tween_property(part_arm_r, "rotation_degrees:x", -75.0, 0.24)
		tw.tween_property(part_arm_r, "rotation_degrees:x", 70.0, 0.08)
		tw.tween_property(part_arm_r, "rotation_degrees:x", 0.0, 0.12)

	await get_tree().create_timer(0.26).timeout
	is_winding_up = false
	if is_dead or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= attack_range + 0.35:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

	# Hit-and-run disengage!
	retreat_timer = 1.15
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _perform_golem_ground_slam():
	can_attack = false
	is_winding_up = true
	var slam_center = global_position
	var slam_radius = 3.25
	var windup = 0.68

	_spawn_status_text("SHOCKWAVE!", Color(1.0, 0.3, 0.9))
	_spawn_ground_telegraph(slam_center, slam_radius, windup, Color(0.95, 0.18, 0.45))

	if part_arm_r and part_arm_l:
		var raise = create_tween()
		raise.set_parallel(true)
		raise.tween_property(part_arm_r, "rotation_degrees:x", -120.0, windup)
		raise.tween_property(part_arm_l, "rotation_degrees:x", -120.0, windup)

	await get_tree().create_timer(windup).timeout
	if is_dead or not is_instance_valid(player):
		is_winding_up = false
		return

	is_winding_up = false
	if part_arm_r and part_arm_l:
		var slam = create_tween()
		slam.set_parallel(true)
		slam.tween_property(part_arm_r, "rotation_degrees:x", 45.0, 0.10)
		slam.tween_property(part_arm_l, "rotation_degrees:x", 45.0, 0.10)
		slam.chain().tween_property(part_arm_r, "rotation_degrees:x", 0.0, 0.25)
		slam.parallel().tween_property(part_arm_l, "rotation_degrees:x", 0.0, 0.25)

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_barrel_break"):
		audio.play_barrel_break()

	if player.has_method("add_trauma"):
		player.add_trauma(0.35)

	if player.global_position.distance_to(slam_center) <= slam_radius:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage + 4)

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _perform_mage_blink(away_dir: Vector3):
	var norm = away_dir.normalized() if away_dir.length() > 0.01 else Vector3.BACK
	var dest = global_position + norm * 5.2
	dest.x = clampf(dest.x, -8.2, 8.2)
	_spawn_status_text("SHADOW BLINK!", Color(0.75, 0.35, 1.0))
	var tw = create_tween()
	tw.tween_property(pivot, "scale", Vector3(0.1, 1.5, 0.1), 0.12)
	tw.tween_callback(func(): global_position = Vector3(dest.x, 0.0, dest.z))
	tw.tween_property(pivot, "scale", Vector3.ONE, 0.14)

func _cast_predictive_bolt():
	if not is_instance_valid(player):
		return
	is_winding_up = true
	if part_arm_r:
		var tw = create_tween()
		tw.tween_property(part_arm_r, "rotation_degrees:x", -75.0, 0.22)
		tw.tween_property(part_arm_r, "rotation_degrees:x", 0.0, 0.22)

	await get_tree().create_timer(0.22).timeout
	is_winding_up = false
	if is_dead or not is_instance_valid(player):
		return

	# Lead target using player's current velocity!
	var predicted_pos = player.global_position + player.velocity * 0.42
	var dir = (predicted_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_fireball"):
		audio.play_fireball()

	for spread in [-10.0, 10.0]:
		var bdir = dir.rotated(Vector3.UP, deg_to_rad(spread)).normalized()
		_spawn_orb(global_position + Vector3(0, 1.1, 0) + bdir * 0.7, bdir, Color(0.8, 0.25, 1.0), attack_damage)

func _perform_boss_dash_cleave(dir: Vector3):
	can_attack = false
	is_winding_up = true
	_spawn_status_text("HELLFIRE CHARGE!", Color(1.0, 0.35, 0.1))
	var target_spot = global_position + dir * 5.2
	_spawn_ground_telegraph(target_spot, 2.6, 0.52, Color(1.0, 0.3, 0.05))

	await get_tree().create_timer(0.52).timeout
	if is_dead or not is_instance_valid(player):
		is_winding_up = false
		return

	is_winding_up = false
	knockback_vel = dir * 18.0
	await get_tree().create_timer(0.22).timeout
	if is_dead or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= 2.8:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage + 4)

	await get_tree().create_timer(1.0).timeout
	can_attack = true

func _perform_boss_meteor_call():
	can_attack = false
	is_winding_up = true
	_spawn_status_text("ABYSSAL METEORS!", Color(1.0, 0.25, 0.1))

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_boss_roar"):
		audio.play_boss_roar()

	var spots: Array[Vector3] = []
	if is_instance_valid(player):
		spots.append(player.global_position)
		spots.append(player.global_position + player.velocity * 0.65)
		for _i in range(2):
			spots.append(player.global_position + Vector3(randf_range(-4.2, 4.2), 0.0, randf_range(-4.2, 4.2)))

	for sp in spots:
		_spawn_ground_telegraph(sp, 2.1, 0.75, Color(1.0, 0.22, 0.05))

	await get_tree().create_timer(0.75).timeout
	is_winding_up = false
	if is_dead or not is_instance_valid(player):
		return

	if player.has_method("add_trauma"):
		player.add_trauma(0.42)

	for sp in spots:
		if player.global_position.distance_to(sp) <= 2.1:
			if player.has_method("take_damage"):
				player.take_damage(int(round(attack_damage * 0.85)))
			break

	await get_tree().create_timer(1.0).timeout
	can_attack = true

func _cast_boss_volley(center_dir: Vector3, enraged: bool):
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_fireball"):
		audio.play_fireball()

	var angles = [-32.0, -16.0, 0.0, 16.0, 32.0] if enraged else [-22.0, 0.0, 22.0]
	for angle_deg in angles:
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
	travel.tween_property(orb, "global_position", start_pos + dir * 15.5, 1.7)
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
		if part_arm_l and not is_blocking and not is_winding_up:
			part_arm_l.rotation_degrees.x = -sw * 0.5
	else:
		if part_leg_l:
			part_leg_l.rotation_degrees.x = move_toward(part_leg_l.rotation_degrees.x, 0.0, 140.0 * delta)
		if part_leg_r:
			part_leg_r.rotation_degrees.x = move_toward(part_leg_r.rotation_degrees.x, 0.0, 140.0 * delta)

func take_damage(amount: int, kb: Vector3 = Vector3.ZERO, is_special: bool = false):
	if is_dead:
		return

	# Check Skeleton Shield Guard: frontal normal slashes are blocked unless flanked or hit with Whirlwind Nova!
	if is_blocking:
		if is_special:
			_set_blocking(false)
			_spawn_status_text("GUARD BROKEN!", Color(1.0, 0.75, 0.2))
		else:
			var enemy_forward = -pivot.global_transform.basis.z.normalized()
			var attack_from_front = true
			if is_instance_valid(player):
				var to_player = (player.global_position - global_position).normalized()
				attack_from_front = enemy_forward.dot(to_player) > 0.1
			if attack_from_front:
				amount = max(2, int(round(amount * 0.15)))
				knockback_vel = kb * 0.2
				_spawn_status_text("BLOCKED! (Flank or Q/E)", Color(0.4, 0.85, 1.0))
				var audio_blk = get_tree().get_first_node_in_group("audio_manager")
				if audio_blk and audio_blk.has_method("play_player_hit"):
					audio_blk.play_player_hit()
				return

	current_health = max(0, current_health - amount)

	# Enemies mid-windup have hyper-armor against light staggers; Golems & Boss have heavy poise
	var kb_mult = 0.25 if (enemy_type == "boss" or enemy_type == "golem" or is_winding_up) else 0.75
	knockback_vel = kb * kb_mult

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

	# Goblins evade back after taking a hit so you can't mindless-mash them
	if enemy_type == "goblin" and current_health > 0 and not is_winding_up:
		retreat_timer = 0.75

	if current_health <= 0:
		die()

func _spawn_status_text(txt: String, col: Color):
	var lbl = Label3D.new()
	lbl.text = txt
	lbl.font_size = 34
	lbl.outline_size = 9
	lbl.modulate = col
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector3(0.0, 2.25, 0.0)
	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y + 1.0, 0.65)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65)
	tw.chain().tween_callback(lbl.queue_free)

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
