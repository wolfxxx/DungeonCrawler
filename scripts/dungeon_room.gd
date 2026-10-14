extends Node3D
## 3D Multi-Chamber Dungeon Generator & Room Manager
## Builds 4 interconnected 3D KayKit Dungeon Chambers with Portcullis Gates, Breakable Barrels,
## Golden Relic Chests, Flickering Torchlight, and Custom Blender 3D Monsters & Boss

@onready var arch_root: Node3D = $Architecture
@onready var props_root: Node3D = $Props
@onready var lights_root: Node3D = $TorchLights
@onready var gates_root: Node3D = $Gates
@onready var enemies_root: Node3D = $Enemies
@onready var pickups_root: Node3D = $Pickups

# Preloaded KayKit 3D Dungeon Assets
var glb_floor := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/floor_tile_large.gltf.glb")
var glb_floor_grate := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/floor_tile_grate.gltf.glb")
var glb_wall := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/wall.gltf.glb")
var glb_wall_arched := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/wall_arched.gltf.glb")
var glb_wall_half := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/wall_half.gltf.glb")
var glb_doorway := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/wall_doorway.glb")
var glb_gate := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/wall_gated.gltf.glb")
var glb_pillar := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/pillar_decorated.gltf.glb")
var glb_torch := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/torch_lit.gltf.glb")
var glb_banner_red := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/banner_shield_red.gltf.glb")
var glb_banner_blue := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/banner_patternA_blue.gltf.glb")
var glb_banner_boss := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/banner_triple_red.gltf.glb")
var glb_barrel := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/barrel_large.gltf.glb")
var glb_crates := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/box_stacked.gltf.glb")
var glb_chest_gold := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/chest_gold.glb")
var glb_table := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/table_long_tablecloth_decorated_A.gltf.glb")
var glb_shelf := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/shelf_small_candles.gltf.glb")
var glb_stairs := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/stairs_walled.gltf.glb")

# Preloaded Enemy & Pickup Scenes
var scn_skeleton := preload("res://scenes/enemy.tscn")
var scn_goblin := preload("res://scenes/enemy_fast.tscn")
var scn_golem := preload("res://scenes/enemy_tank.tscn")
var scn_pickup := preload("res://scenes/health_pickup.tscn")

var chamber_names := [
	"I. Entry Hall of the Catacombs",
	"II. The Pillared Crypt",
	"III. Sanctum of the Obsidian Guard",
	"IV. Throne of the Abyssal Warden"
]

var gate_nodes: Dictionary = {} # chamber_id -> StaticBody3D gate
var door_meshes: Dictionary = {} # chamber_id -> Node3D (wall_doorway_door)
var door_labels: Dictionary = {} # chamber_id -> Label3D
var door_lights: Dictionary = {} # chamber_id -> OmniLight3D
var torch_lights: Array[OmniLight3D] = []
var current_chamber: int = 0
var time_accum: float = 0.0

func _ready():
	add_to_group("dungeon_room")
	_build_dungeon_architecture()
	_populate_props_and_chests()
	_spawn_all_chambers_enemies()
	print("Dungeon room loaded")
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_vo"):
		audio.play_vo("VoEnter")
	if "--capture-shots" in OS.get_cmdline_user_args():
		_capture_showcase_screenshots()

func _process(delta: float):
	time_accum += delta
	# Subtle torchlight flicker
	for i in range(torch_lights.size()):
		var l = torch_lights[i]
		if is_instance_valid(l):
			l.light_energy = 2.0 + sin(time_accum * 7.0 + float(i) * 1.7) * 0.28

	# Update current chamber indicator based on player Z
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var pz = player.global_position.z
		var cid = 0
		if pz < -48.0:
			cid = 3
		elif pz < -28.0:
			cid = 2
		elif pz < -8.0:
			cid = 1
		if cid != current_chamber:
			current_chamber = cid
			var ui = get_tree().get_first_node_in_group("ui")
			if ui and ui.has_method("set_chamber_title"):
				ui.set_chamber_title(chamber_names[current_chamber])

func _build_dungeon_architecture():
	# 4 Chambers spanning Z from +8 down to -72 (20m per chamber), X from -10 to +10 (5 tiles wide = 20m)
	# Each floor_tile_large is 4x4m, so X centers at [-8, -4, 0, 4, 8], Z centers from +6 down to -70 in steps of -4
	for gz in range(20):
		var z_pos = 6.0 - float(gz) * 4.0
		for gx in [-8.0, -4.0, 0.0, 4.0, 8.0]:
			var use_grate = ( abs(gx) == 4.0 and (gz % 3 == 1) )
			var tile = (glb_floor_grate if use_grate else glb_floor).instantiate()
			arch_root.add_child(tile)
			tile.position = Vector3(gx, 0.0, z_pos)

		# Left (-10) and Right (+10) perimeter walls + physics colliders
		var wl = (glb_wall_arched if gz % 2 == 1 else glb_wall).instantiate()
		arch_root.add_child(wl)
		wl.position = Vector3(-10.0, 0.0, z_pos)
		wl.rotation_degrees.y = 90.0

		var wr = (glb_wall_arched if gz % 2 == 1 else glb_wall).instantiate()
		arch_root.add_child(wr)
		wr.position = Vector3(10.0, 0.0, z_pos)
		wr.rotation_degrees.y = -90.0

		# Add wall torches every 2 segments
		if gz % 2 == 1:
			_add_wall_torch(Vector3(-9.3, 2.2, z_pos), 90.0)
			_add_wall_torch(Vector3(9.3, 2.2, z_pos), -90.0)

	# Outer Left/Right/South/North physics boundary walls
	_add_invisible_wall(Vector3(-10.0, 2.0, -32.0), Vector3(1.0, 4.0, 84.0))
	_add_invisible_wall(Vector3(10.0, 2.0, -32.0), Vector3(1.0, 4.0, 84.0))
	_add_invisible_wall(Vector3(0.0, 2.0, 8.5), Vector3(22.0, 4.0, 1.0))
	_add_invisible_wall(Vector3(0.0, 2.0, -72.5), Vector3(22.0, 4.0, 1.0))

	# South low wall (half height so camera never gets occluded)
	for gx in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		var sw = glb_wall_half.instantiate()
		arch_root.add_child(sw)
		sw.position = Vector3(gx, 0.0, 8.0)

	# North Boss Back Wall + Grand Stairs
	for gx in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		var nw = glb_wall_arched.instantiate()
		arch_root.add_child(nw)
		nw.position = Vector3(gx, 0.0, -72.0)
		var bnr = glb_banner_boss.instantiate()
		arch_root.add_child(bnr)
		bnr.position = Vector3(gx, 1.8, -71.4)

	var throne_stairs = glb_stairs.instantiate()
	arch_root.add_child(throne_stairs)
	throne_stairs.position = Vector3(0.0, 0.0, -69.5)

	# Divider Walls with Central Hinged Doors at z = -8, -28, -48
	var gate_z_list := [-8.0, -28.0, -48.0]
	for i in range(gate_z_list.size()):
		var gz_coord = gate_z_list[i]
		for gx in [-8.0, -4.0, 4.0, 8.0]:
			var hw = glb_wall_half.instantiate()
			arch_root.add_child(hw)
			hw.position = Vector3(gx, 0.0, gz_coord)
		# Permanent left and right collider wings covering walls + doorway stone jambs [-10..-1.05] and [+1.05..+10]
		_add_invisible_wall(Vector3(-5.525, 2.0, gz_coord), Vector3(8.95, 4.0, 1.1))
		_add_invisible_wall(Vector3(5.525, 2.0, gz_coord), Vector3(8.95, 4.0, 1.1))

		# Central doorway frame with hinged wooden door (wall_doorway_door)
		var frame = glb_doorway.instantiate()
		arch_root.add_child(frame)
		frame.position = Vector3(0.0, 0.0, gz_coord)
		var door_mesh = frame.find_child("wall_doorway_door", true, false) as Node3D
		if door_mesh:
			door_meshes[i] = door_mesh

		# Decorative pillars flanking doorway
		for px in [-2.2, 2.2]:
			var pil = glb_pillar.instantiate()
			arch_root.add_child(pil)
			pil.position = Vector3(px, 0.0, gz_coord)

		# Doorway physics blocker while door is closed & sealed
		var gate_body = StaticBody3D.new()
		gate_body.collision_layer = 1
		gate_body.collision_mask = 0
		var g_col = CollisionShape3D.new()
		var g_box = BoxShape3D.new()
		g_box.size = Vector3(2.4, 4.0, 1.1)
		g_col.shape = g_box
		g_col.position = Vector3(0, 2.0, 0)
		gate_body.add_child(g_col)

		var d_light = OmniLight3D.new()
		d_light.light_color = Color(1.0, 0.32, 0.2)
		d_light.light_energy = 1.8
		d_light.omni_range = 4.5
		d_light.position = Vector3(0, 2.2, 0.6)
		gate_body.add_child(d_light)
		door_lights[i] = d_light

		var d_lbl = Label3D.new()
		d_lbl.text = "SEALED DOOR — Defeat Chamber Enemies"
		d_lbl.font_size = 30
		d_lbl.outline_size = 8
		d_lbl.modulate = Color(1.0, 0.55, 0.35)
		d_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		d_lbl.position = Vector3(0, 2.8, 0.5)
		gate_body.add_child(d_lbl)
		door_labels[i] = d_lbl

		gates_root.add_child(gate_body)
		gate_body.position = Vector3(0.0, 0.0, gz_coord)
		gate_nodes[i] = gate_body

func _add_invisible_wall(pos: Vector3, sz: Vector3):
	var sb = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = sz
	cs.shape = box
	sb.add_child(cs)
	arch_root.add_child(sb)
	sb.position = pos

func _add_wall_torch(pos: Vector3, rot_y: float):
	var t = glb_torch.instantiate()
	arch_root.add_child(t)
	t.position = pos
	t.rotation_degrees.y = rot_y

	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.28)
	light.light_energy = 2.0
	light.omni_range = 11.5
	light.position = pos + Vector3(0.0, 0.45, 0.0)
	lights_root.add_child(light)
	torch_lights.append(light)

func _populate_props_and_chests():
	# Chamber 1 Pillars
	for ppos in [Vector3(-4.5, 0, -14), Vector3(4.5, 0, -14), Vector3(-4.5, 0, -22), Vector3(4.5, 0, -22)]:
		_add_static_prop(glb_pillar, ppos, 0.0, Vector3(1.1, 4.0, 1.1))

	# Chamber 2 Banquet Tables & Candle Shelves
	_add_static_prop(glb_table, Vector3(-5.0, 0, -38.0), 90.0, Vector3(2.0, 1.2, 4.0))
	_add_static_prop(glb_table, Vector3(5.0, 0, -38.0), 90.0, Vector3(2.0, 1.2, 4.0))
	_add_static_prop(glb_shelf, Vector3(-8.8, 0, -33.0), 90.0, Vector3(1.2, 2.2, 1.8))
	_add_static_prop(glb_shelf, Vector3(8.8, 0, -33.0), -90.0, Vector3(1.2, 2.2, 1.8))

	# Breakable Barrels & Crates across Chambers
	var barrel_coords := [
		Vector3(-6.5, 0, 3.5), Vector3(6.5, 0, 2.5), Vector3(-7.0, 0, -4.5),
		Vector3(-7.0, 0, -12.0), Vector3(7.0, 0, -18.0), Vector3(-6.5, 0, -24.5),
		Vector3(-7.2, 0, -32.0), Vector3(7.2, 0, -43.0),
		Vector3(-7.5, 0, -54.0), Vector3(7.5, 0, -54.0), Vector3(-7.5, 0, -64.0), Vector3(7.5, 0, -64.0)
	]
	for i in range(barrel_coords.size()):
		_add_breakable_prop(barrel_coords[i], i % 3 == 0)

	# 3 Interactive Golden Relic Chests
	_add_relic_chest(Vector3(6.8, 0.0, -5.2), "Vampiric Blade", "vampiric")
	_add_relic_chest(Vector3(-6.8, 0.0, -25.0), "Sunfire Brand", "sunfire")
	_add_relic_chest(Vector3(6.8, 0.0, -45.0), "Dragonscale Plate", "dragonscale")

	# Pickups placed in the dungeon
	_spawn_pickup(Vector3(-5.5, 0, -2.0), "health", 35)
	_spawn_pickup(Vector3(0.0, 0, -18.0), "soul_gem", 1)
	_spawn_pickup(Vector3(5.5, 0, -23.0), "health", 35)
	_spawn_pickup(Vector3(-5.5, 0, -42.0), "health", 40)
	_spawn_pickup(Vector3(0.0, 0, -44.0), "soul_gem", 1)
	_spawn_pickup(Vector3(-6.0, 0, -60.0), "health", 45)
	_spawn_pickup(Vector3(6.0, 0, -60.0), "health", 45)

func _add_static_prop(scene: PackedScene, pos: Vector3, rot_y: float, box_size: Vector3):
	var sb = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = box_size
	cs.shape = box
	cs.position = Vector3(0, box_size.y * 0.5, 0)
	sb.add_child(cs)
	var inst = scene.instantiate()
	sb.add_child(inst)
	props_root.add_child(sb)
	sb.position = pos
	sb.rotation_degrees.y = rot_y

func _add_breakable_prop(pos: Vector3, is_crate: bool):
	var sb = StaticBody3D.new()
	sb.collision_layer = 5
	sb.collision_mask = 0
	sb.add_to_group("breakables")
	var cs = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 0.65
	cyl.height = 1.3
	cs.shape = cyl
	cs.position = Vector3(0, 0.65, 0)
	sb.add_child(cs)

	var visual = (glb_crates if is_crate else glb_barrel).instantiate()
	sb.add_child(visual)

	var script = GDScript.new()
	script.source_code = """extends StaticBody3D
var hp: int = 1
var broken: bool = false
func take_damage(_amt: int):
	if broken:
		return
	broken = true
	collision_layer = 0
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_barrel_break"):
		audio.play_barrel_break()
	if randf() < 0.65:
		var pk_scn = load("res://scenes/health_pickup.tscn")
		var pk = pk_scn.instantiate()
		pk.pickup_type = "gold" if randf() < 0.7 else "health"
		pk.amount = 20 if pk.pickup_type == "gold" else 25
		get_parent().add_child(pk)
		pk.global_position = global_position
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3(1.4, 0.1, 1.4), 0.16)
	tw.tween_callback(queue_free)
"""
	script.reload()
	sb.set_script(script)
	props_root.add_child(sb)
	sb.position = pos

func _add_relic_chest(pos: Vector3, relic_name: String, bonus_type: String):
	_add_invisible_wall(pos + Vector3(0, 0.6, 0), Vector3(1.5, 1.2, 1.1))
	var area = Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 1
	var cs = CollisionShape3D.new()
	var sph = SphereShape3D.new()
	sph.radius = 1.6
	cs.shape = sph
	cs.position = Vector3(0, 0.8, 0)
	area.add_child(cs)

	var chest_inst = glb_chest_gold.instantiate()
	area.add_child(chest_inst)

	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.2)
	light.light_energy = 2.2
	light.omni_range = 4.0
	light.position = Vector3(0, 1.1, 0)
	area.add_child(light)

	var lbl = Label3D.new()
	lbl.text = "RELIC CHEST: " + relic_name
	lbl.font_size = 32
	lbl.outline_size = 8
	lbl.modulate = Color(1.0, 0.88, 0.3)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 1.65, 0)
	area.add_child(lbl)

	props_root.add_child(area)
	area.position = pos

	var opened := [false]
	area.body_entered.connect(func(body: Node3D):
		if opened[0]:
			return
		if body.is_in_group("player") and body.has_method("grant_relic"):
			opened[0] = true
			var audio = get_tree().get_first_node_in_group("audio_manager")
			if audio and audio.has_method("play_chest"):
				audio.play_chest()
			body.grant_relic(relic_name, bonus_type)
			lbl.text = "OPENED: " + relic_name
			lbl.modulate = Color(0.5, 1.0, 0.6)
			var tw = area.create_tween()
			tw.tween_property(chest_inst, "scale", Vector3(1.25, 0.8, 1.25), 0.15)
			tw.tween_property(chest_inst, "scale", Vector3.ONE, 0.15)
			tw.tween_property(light, "light_energy", 0.3, 0.5)
	)

func _spawn_pickup(pos: Vector3, ptype: String, amt: int):
	var pk = scn_pickup.instantiate()
	pk.pickup_type = ptype
	pk.amount = amt
	pickups_root.add_child(pk)
	pk.position = pos

func _spawn_all_chambers_enemies():
	# Chamber 0: Entry Hall (z: +4 to -6)
	_spawn_enemy(scn_skeleton, Vector3(-4.0, 0, -1.0), 0)
	_spawn_enemy(scn_skeleton, Vector3(4.0, 0, -1.5), 0)
	_spawn_enemy(scn_goblin, Vector3(-2.5, 0, -4.5), 0)
	_spawn_enemy(scn_goblin, Vector3(3.0, 0, -5.0), 0)

	# Chamber 1: The Pillared Crypt (z: -12 to -25)
	_spawn_enemy(scn_skeleton, Vector3(-5.5, 0, -13.0), 1)
	_spawn_enemy(scn_skeleton, Vector3(5.5, 0, -13.0), 1)
	_spawn_enemy(scn_goblin, Vector3(-2.5, 0, -17.0), 1)
	_spawn_enemy(scn_goblin, Vector3(2.5, 0, -17.0), 1)
	_spawn_enemy(scn_golem, Vector3(0.0, 0, -22.0), 1)
	_spawn_custom_enemy("mage", "Cultist Necromancer", Vector3(0.0, 0, -24.5), 1, 50, 3.6, 12)

	# Chamber 2: Sanctum of the Obsidian Guard (z: -32 to -45)
	_spawn_enemy(scn_goblin, Vector3(-3.0, 0, -33.0), 2)
	_spawn_enemy(scn_goblin, Vector3(3.0, 0, -33.0), 2)
	_spawn_enemy(scn_golem, Vector3(-3.5, 0, -39.0), 2)
	_spawn_enemy(scn_golem, Vector3(3.5, 0, -39.0), 2)
	_spawn_custom_enemy("mage", "Cultist Necromancer", Vector3(-4.0, 0, -44.0), 2, 55, 3.6, 13)
	_spawn_custom_enemy("mage", "Cultist Necromancer", Vector3(4.0, 0, -44.0), 2, 55, 3.6, 13)

	# Chamber 3: Throne of the Abyssal Warden (z: -52 to -68)
	_spawn_enemy(scn_skeleton, Vector3(-5.0, 0, -56.0), 3)
	_spawn_enemy(scn_skeleton, Vector3(5.0, 0, -56.0), 3)
	_spawn_custom_enemy("boss", "The Abyssal Warden", Vector3(0.0, 0, -63.0), 3, 300, 4.4, 22)

func _spawn_enemy(scene: PackedScene, pos: Vector3, cid: int) -> Node3D:
	var e = scene.instantiate()
	e.chamber_id = cid
	enemies_root.add_child(e)
	e.position = pos
	return e

func _spawn_custom_enemy(etype: String, dname: String, pos: Vector3, cid: int, hp: int, spd: float, dmg: int):
	var e = scn_skeleton.instantiate()
	e.enemy_type = etype
	e.display_name = dname
	e.chamber_id = cid
	e.max_health = hp
	e.current_health = hp
	e.speed = spd
	e.attack_damage = dmg
	if etype == "boss":
		e.attack_range = 2.6
		e.detection_range = 20.0
	enemies_root.add_child(e)
	e.position = pos

func is_chamber_accessible(cid: int) -> bool:
	if cid <= 0:
		return true
	return not gate_nodes.has(cid - 1)

func on_enemy_defeated(cid: int, was_boss: bool):
	# Check if all enemies in chamber `cid` are defeated
	var remaining_in_chamber := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.get("chamber_id") == cid:
			remaining_in_chamber += 1

	if door_labels.has(cid) and is_instance_valid(door_labels[cid]) and remaining_in_chamber > 0:
		door_labels[cid].text = "SEALED DOOR — %d Enemies Left" % remaining_in_chamber

	if remaining_in_chamber == 0 and gate_nodes.has(cid):
		_open_gate(cid)

	if was_boss:
		var ui = get_tree().get_first_node_in_group("ui")
		if ui and ui.has_method("show_victory"):
			ui.show_victory()

func _open_gate(cid: int):
	var gate: StaticBody3D = gate_nodes[cid]
	if not is_instance_valid(gate):
		return
	gate_nodes.erase(cid)

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		if audio.has_method("play_door_open"):
			audio.play_door_open()
		if audio.has_method("play_vo"):
			audio.play_vo("VoCleared")

	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_banner"):
		ui.show_banner("CHAMBER CLEARED — DOOR UNSEALED & OPENED!")

	gate.collision_layer = 0
	for child in gate.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	# Swing the hinged wooden door (wall_doorway_door) wide open!
	if door_meshes.has(cid) and is_instance_valid(door_meshes[cid]):
		var d_mesh: Node3D = door_meshes[cid]
		var d_tw = create_tween()
		d_tw.tween_property(d_mesh, "rotation_degrees:y", -105.0, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if door_lights.has(cid) and is_instance_valid(door_lights[cid]):
		door_lights[cid].light_color = Color(0.25, 1.0, 0.45)

	if door_labels.has(cid) and is_instance_valid(door_labels[cid]):
		var lbl: Label3D = door_labels[cid]
		lbl.text = "DOOR OPENED!"
		lbl.modulate = Color(0.35, 1.0, 0.5)
		var l_tw = create_tween()
		l_tw.tween_interval(1.5)
		l_tw.tween_property(lbl, "modulate:a", 0.0, 0.6)

func clear_room() -> bool:
	return get_tree().get_nodes_in_group("enemies").size() == 0

func _capture_showcase_screenshots():
	await get_tree().create_timer(1.2).timeout
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = Vector3(0.0, 0.0, 0.5)
		if player.has_method("perform_special"):
			player.perform_special()
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var img1 = get_viewport().get_texture().get_image()
	img1.save_png("res://screenshots/gameplay_chamber1.png")

	if player:
		player.global_position = Vector3(0.0, 0.0, -56.5)
	await get_tree().create_timer(0.8).timeout
	if player and player.has_method("perform_attack"):
		player.perform_attack()
	await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	var img2 = get_viewport().get_texture().get_image()
	img2.save_png("res://screenshots/gameplay_boss_throne.png")
	get_tree().quit()
