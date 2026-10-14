extends Area3D
## 3D Sword Slash & Whirlwind Nova Attack Area
## Normal slashes require directional arc check (front 140° cone); Special Nova hits 360°
## Both check 3D physics line-of-sight so attacks never hit through walls or closed doors

var damage: int = 18
var is_special: bool = false
var knockback_force: float = 9.0
var attacker: Node3D = null
var forward_dir: Vector3 = Vector3.FORWARD

@onready var visual: Node3D = $Visual
@onready var slash_ring: MeshInstance3D = $Visual/SlashRing
@onready var slash_disc: MeshInstance3D = $Visual/SlashDisc
@onready var slash_light: OmniLight3D = $Visual/SlashLight
@onready var col_shape: CollisionShape3D = $CollisionShape3D

func _ready():
	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var disc_mat = StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if is_special:
		ring_mat.albedo_color = Color(1.0, 0.72, 0.15, 0.9)
		disc_mat.albedo_color = Color(1.0, 0.45, 0.1, 0.4)
		slash_light.light_color = Color(1.0, 0.65, 0.2)
		slash_light.light_energy = 5.0
		var sphere = SphereShape3D.new()
		sphere.radius = 3.6
		col_shape.shape = sphere
		visual.scale = Vector3(0.55, 1.0, 0.55)
	else:
		ring_mat.albedo_color = Color(0.25, 0.92, 1.0, 0.85)
		disc_mat.albedo_color = Color(0.2, 0.75, 1.0, 0.32)
		slash_light.light_color = Color(0.25, 0.9, 1.0)
		slash_light.light_energy = 3.0
		var sphere = SphereShape3D.new()
		sphere.radius = 1.85
		col_shape.shape = sphere
		visual.scale = Vector3(0.42, 1.0, 0.42)

	slash_ring.material_override = ring_mat
	slash_disc.material_override = disc_mat

	var target_scale = Vector3(1.65, 1.0, 1.65) if is_special else Vector3(0.92, 1.0, 0.92)
	var duration = 0.32 if is_special else 0.2
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "rotation:y", visual.rotation.y + (TAU if is_special else PI * 0.75), duration)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, duration)
	tween.tween_property(disc_mat, "albedo_color:a", 0.0, duration)
	tween.tween_property(slash_light, "light_energy", 0.0, duration)
	tween.chain().tween_callback(queue_free)

	await get_tree().physics_frame
	await get_tree().physics_frame
	_apply_hits()

func _has_clear_line_of_sight(origin: Vector3, target: Node3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return true
	var from_pt = origin + Vector3(0.0, 0.85, 0.0)
	var to_pt = target.global_position + Vector3(0.0, 0.85, 0.0)
	var query = PhysicsRayQueryParameters3D.create(from_pt, to_pt, 1)
	var exclude_rids: Array[RID] = []
	if is_instance_valid(attacker) and attacker is CollisionObject3D:
		exclude_rids.append((attacker as CollisionObject3D).get_rid())
	if is_instance_valid(target) and target is CollisionObject3D:
		exclude_rids.append((target as CollisionObject3D).get_rid())
	query.exclude = exclude_rids

	var hit = space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider = hit.get("collider")
	if collider and collider.is_in_group("breakables"):
		return true
	# Blocked by a solid dungeon wall or closed door!
	return false

func _apply_hits():
	var hit_any = false
	var origin = attacker.global_position if is_instance_valid(attacker) else global_position

	for body in get_overlapping_bodies():
		if body == attacker:
			continue
		var to_target = body.global_position - origin
		to_target.y = 0.0
		var dist = to_target.length()
		var dir = to_target.normalized() if dist > 0.01 else forward_dir

		# For normal attacks, enforce a forward 140-degree slash cone so behind-the-back swings miss
		if not is_special and dist > 0.55:
			if forward_dir.dot(dir) < -0.15:
				continue

		# Prevent slashing through dungeon walls or closed doors
		if not _has_clear_line_of_sight(origin, body):
			continue

		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(damage, dir * knockback_force, is_special)
			hit_any = true
		elif body.is_in_group("breakables") and body.has_method("take_damage"):
			body.take_damage(damage)
			hit_any = true

	if hit_any and is_instance_valid(attacker) and attacker.has_method("on_successful_hit"):
		attacker.on_successful_hit(is_special)
