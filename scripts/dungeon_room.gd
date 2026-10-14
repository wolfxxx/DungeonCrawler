extends Node3D
## 3D Multi-Floor & Multi-Chamber Dungeon Generator & Room Manager
## Features:
## - 3 Escalating Dungeon Floors (Catacombs -> Frostbitten Ossuary -> Infernal Sanctum)
## - 4 Interconnected KayKit 3D Chambers per Floor with Hinged Doors
## - Mystic Dungeon Merchant Stalls (Press [F] to spend Gold on Relics, Weaponsmithing, & Perks)
## - Descent Portal at the North Grand Stairs after defeating Floor 1 & Floor 2 Bosses

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
var glb_coins := preload("res://addons/kaykit_dungeon_remastered/Assets/gltf/coin_stack_small.gltf.glb")
var glb_merchant_npc := preload("res://models/enemy_mage.glb")

# Preloaded Enemy & Pickup Scenes
var scn_skeleton := preload("res://scenes/enemy.tscn")
var scn_goblin := preload("res://scenes/enemy_fast.tscn")
var scn_golem := preload("res://scenes/enemy_tank.tscn")
var scn_pickup := preload("res://scenes/health_pickup.tscn")

const MAX_FLOORS: int = 3
var current_floor: int = 1

const FLOOR_THEMES := {
	1: {
		"name": "The Forgotten Catacombs",
		"light_color": Color(1.0, 0.65, 0.28),
		"boss_name": "The Abyssal Warden",
		"chambers": [
			"I. Entry Hall of the Catacombs",
			"II. The Pillared Crypt",
			"III. Sanctum of the Obsidian Guard",
			"IV. Throne of the Abyssal Warden"
		]
	},
	2: {
		"name": "The Frostbitten Ossuary",
		"light_color": Color(0.32, 0.78, 1.0),
		"boss_name": "Malakor, Archlich of Frost",
		"chambers": [
			"I. Glacial Vestibule",
			"II. Hall of Frozen Pillars",
			"III. Necromancer's Conclave",
			"IV. Sanctum of the Archlich"
		]
	},
	3: {
		"name": "The Infernal Sanctum",
		"light_color": Color(1.0, 0.32, 0.52),
		"boss_name": "Baelgor, Lord of the Abyss",
		"chambers": [
			"I. Hellfire Approach",
			"II. Vault of the Blood Guard",
			"III. Citadel of Doom",
			"IV. Abyssal Throne of Baelgor"
		]
	}
}

var chamber_names: Array = []
var gate_nodes: Dictionary = {} # chamber_id -> StaticBody3D gate
var door_meshes: Dictionary = {} # chamber_id -> Node3D (wall_doorway_door)
var door_labels: Dictionary = {} # chamber_id -> Label3D
var door_lights: Dictionary = {} # chamber_id -> OmniLight3D
var entered_chambers: Dictionary = {0: true} # chamber_id -> bool
var torch_lights: Array[OmniLight3D] = []
var merchant_positions: Array[Vector3] = []
var merchant_npcs: Array[Node3D] = []
var descent_portal: Node3D = null
var descent_portal_active_timer: float = 0.0
var current_chamber: int = 0
var time_accum: float = 0.0

func _ready():
	add_to_group("dungeon_room")
	_build_floor(1)
	print("Dungeon room loaded")
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_vo"):
		audio.play_vo("VoEnter")
	if "--capture-shots" in OS.get_cmdline_user_args():
		_capture_showcase_screenshots()

func _clear_floor_nodes():
	for c in enemies_root.get_children():
		c.remove_from_group("enemies")
	for root in [arch_root, props_root, lights_root, gates_root, enemies_root, pickups_root]:
		for c in root.get_children():
			c.queue_free()
	gate_nodes.clear()
	door_meshes.clear()
	door_labels.clear()
	door_lights.clear()
	torch_lights.clear()
	merchant_positions.clear()
	merchant_npcs.clear()
	descent_portal = null
	descent_portal_active_timer = 0.0
	entered_chambers = {0: true}
	current_chamber = 0

func _build_floor(floor_num: int):
	current_floor = floor_num
	_clear_floor_nodes()

	var theme: Dictionary = FLOOR_THEMES.get(current_floor, FLOOR_THEMES[1])
	chamber_names = theme["chambers"]

	_build_dungeon_architecture(theme["light_color"])
	_populate_props_and_chests()
	_spawn_merchant_stalls()
	_spawn_all_chambers_enemies()

	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		if ui.has_method("hide_boss_bar"):
			ui.hide_boss_bar()
		if ui.has_method("set_floor_info"):
			ui.set_floor_info(current_floor, MAX_FLOORS)
		if ui.has_method("set_chamber_title"):
			ui.set_chamber_title(chamber_names[0])
		if ui.has_method("update_enemies_remaining"):
			ui.call_deferred("update_enemies_remaining")

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		var player = get_tree().get_first_node_in_group("player") as Node3D
		if not player:
			return
		# Check if near Descent Portal
		if is_instance_valid(descent_portal) and player.global_position.distance_to(descent_portal.global_position) < 3.6:
			_descend_to_next_floor()
			get_viewport().set_input_as_handled()
			return
		# Check if near any Mystic Merchant Stall
		for mpos in merchant_positions:
			if player.global_position.distance_to(mpos) < 3.8:
				var ui = get_tree().get_first_node_in_group("ui")
				if ui and ui.has_method("open_merchant_shop"):
					ui.open_merchant_shop()
					get_viewport().set_input_as_handled()
				return

func _process(delta: float):
	time_accum += delta
	# Subtle torchlight flicker
	for i in range(torch_lights.size()):
		var l = torch_lights[i]
		if is_instance_valid(l):
			l.light_energy = 2.0 + sin(time_accum * 7.0 + float(i) * 1.7) * 0.28

	# Animate Merchant NPCs & Descent Portal
	for m_npc in merchant_npcs:
		if is_instance_valid(m_npc):
			m_npc.position.y = 0.08 + sin(time_accum * 2.6) * 0.06
	if is_instance_valid(descent_portal):
		descent_portal.rotation.y += delta * 1.8
		if descent_portal_active_timer > 0.0:
			descent_portal_active_timer = maxf(0.0, descent_portal_active_timer - delta)

	# Update current chamber indicator based on player Z
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var pz = player.global_position.z
		if pz < -47.2 and not gate_nodes.has(2):
			entered_chambers[3] = true
		if pz < -27.2 and not gate_nodes.has(1):
			entered_chambers[2] = true
		if pz < -7.2 and not gate_nodes.has(0):
			entered_chambers[1] = true

		var cid = 0
		if pz < -48.0:
			cid = 3
		elif pz < -28.0:
			cid = 2
		elif pz < -8.0:
			cid = 1
		if cid != current_chamber:
			current_chamber = cid
			entered_chambers[cid] = true
			var ui = get_tree().get_first_node_in_group("ui")
			if ui and ui.has_method("set_chamber_title"):
				ui.set_chamber_title(chamber_names[current_chamber])

		# Auto-descend if player walks directly into the active Descent Portal ring
		if is_instance_valid(descent_portal) and descent_portal_active_timer <= 0.0:
			if player.global_position.distance_to(descent_portal.global_position) < 2.2:
				_descend_to_next_floor()

	# Continuous failsafe gate check so a cleared chamber's door ALWAYS opens immediately
	for cid in [0, 1, 2]:
		if gate_nodes.has(cid):
			var alive_in_cid := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.get("is_dead") and e.get("chamber_id") == cid:
					alive_in_cid += 1
			if alive_in_cid == 0:
				_open_gate(cid)
			elif door_labels.has(cid) and is_instance_valid(door_labels[cid]):
				door_labels[cid].text = "SEALED DOOR — %d Enemies Left" % alive_in_cid

func _build_dungeon_architecture(torch_col: Color):
	# 4 Chambers spanning Z from +8 down to -72 (20m per chamber), X from -10 to +10 (5 tiles wide = 20m)
	for gz in range(20):
		var z_pos = 6.0 - float(gz) * 4.0
		for gx in [-8.0, -4.0, 0.0, 4.0, 8.0]:
			var use_grate = (abs(gx) == 4.0 and ((gz + current_floor) % 3 == 1))
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
			_add_wall_torch(Vector3(-9.3, 2.2, z_pos), 90.0, torch_col)
			_add_wall_torch(Vector3(9.3, 2.2, z_pos), -90.0, torch_col)

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

func _add_wall_torch(pos: Vector3, rot_y: float, torch_col: Color):
	var t = glb_torch.instantiate()
	arch_root.add_child(t)
	t.position = pos
	t.rotation_degrees.y = rot_y

	var light = OmniLight3D.new()
	light.light_color = torch_col
	light.light_energy = 2.0
	light.omni_range = 11.5
	light.position = pos + Vector3(0.0, 0.45, 0.0)
	lights_root.add_child(light)
	torch_lights.append(light)

func _spawn_merchant_stalls():
	# Place a Mystic Merchant Stall in Chamber 1 (before Gate 1) and Chamber 2 (before Boss Gate 2)
	_create_merchant_stall(Vector3(6.6, 0.0, -24.8), -90.0)
	_create_merchant_stall(Vector3(-6.6, 0.0, -44.8), 90.0)

func _create_merchant_stall(pos: Vector3, rot_y: float):
	merchant_positions.append(pos)
	var stall_root = Node3D.new()
	props_root.add_child(stall_root)
	stall_root.position = pos
	stall_root.rotation_degrees.y = rot_y

	# Table collider + mesh
	_add_invisible_wall(pos + Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 2.8))
	var tbl = glb_table.instantiate()
	stall_root.add_child(tbl)
	tbl.scale = Vector3(0.85, 0.9, 0.85)

	# Gold coin stacks on the merchant's table
	for cx in [-0.55, 0.0, 0.55]:
		var c_inst = glb_coins.instantiate()
		stall_root.add_child(c_inst)
		c_inst.position = Vector3(cx, 0.82, 0.15)

	# Robed Mystic Merchant NPC standing behind the table
	var npc = glb_merchant_npc.instantiate()
	stall_root.add_child(npc)
	npc.position = Vector3(0.0, 0.08, -1.05)
	npc.scale = Vector3(1.12, 1.12, 1.12)
	merchant_npcs.append(npc)

	# Warm Golden-Violet Lantern Light
	var m_light = OmniLight3D.new()
	m_light.light_color = Color(1.0, 0.78, 0.25)
	m_light.light_energy = 2.6
	m_light.omni_range = 5.5
	m_light.position = Vector3(0.0, 2.2, 0.2)
	stall_root.add_child(m_light)

	# Floating 3D Merchant Sign
	var lbl = Label3D.new()
	lbl.text = "MYSTIC MERCHANT\nPress [F] to Spend Gold"
	lbl.font_size = 32
	lbl.outline_size = 9
	lbl.modulate = Color(1.0, 0.88, 0.32)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.75, 0.0)
	stall_root.add_child(lbl)

func _populate_props_and_chests():
	# Floor-varied Chamber 1 Pillars
	var p_offset_x := 4.5 if current_floor % 2 == 1 else 3.6
	for ppos in [Vector3(-p_offset_x, 0, -14), Vector3(p_offset_x, 0, -14), Vector3(-p_offset_x, 0, -22), Vector3(p_offset_x, 0, -22)]:
		_add_static_prop(glb_pillar, ppos, 0.0, Vector3(1.1, 4.0, 1.1))

	# Chamber 2 Banquet Tables & Candle Shelves
	_add_static_prop(glb_table, Vector3(-5.0, 0, -37.5), 90.0, Vector3(2.0, 1.2, 4.0))
	_add_static_prop(glb_table, Vector3(5.0, 0, -37.5), 90.0, Vector3(2.0, 1.2, 4.0))
	_add_static_prop(glb_shelf, Vector3(-8.8, 0, -33.0), 90.0, Vector3(1.2, 2.2, 1.8))
	_add_static_prop(glb_shelf, Vector3(8.8, 0, -33.0), -90.0, Vector3(1.2, 2.2, 1.8))

	# Breakable Barrels & Crates across Chambers
	var barrel_coords := [
		Vector3(-6.5, 0, 3.5), Vector3(6.5, 0, 2.5), Vector3(-7.0, 0, -4.5),
		Vector3(-7.0, 0, -12.0), Vector3(7.0, 0, -18.0),
		Vector3(-7.2, 0, -32.0), Vector3(7.2, 0, -43.0),
		Vector3(-7.5, 0, -54.0), Vector3(7.5, 0, -54.0), Vector3(-7.5, 0, -64.0), Vector3(7.5, 0, -64.0)
	]
	for i in range(barrel_coords.size()):
		_add_breakable_prop(barrel_coords[i], (i + current_floor) % 3 == 0)

	# 3 Interactive Golden Relic Chests (one in Chamber 0, Chamber 1, Chamber 2)
	_add_relic_chest(Vector3(6.8, 0.0, -5.2), "Vampiric Blade", "vampiric")
	_add_relic_chest(Vector3(-6.8, 0.0, -25.0), "Sunfire Brand", "sunfire")
	_add_relic_chest(Vector3(6.8, 0.0, -45.0), "Dragonscale Plate", "dragonscale")

	# Pickups placed in the dungeon
	_spawn_pickup(Vector3(-5.5, 0, -2.0), "health", 35)
	_spawn_pickup(Vector3(3.2, 0, -3.5), "gold", 30)
	_spawn_pickup(Vector3(0.0, 0, -18.0), "soul_gem", 1)
	_spawn_pickup(Vector3(-5.2, 0, -21.0), "gold", 35)
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
	if randf() < 0.78:
		var pk_scn = load("res://scenes/health_pickup.tscn")
		var pk = pk_scn.instantiate()
		pk.pickup_type = "gold" if randf() < 0.72 else "health"
		pk.amount = 25 if pk.pickup_type == "gold" else 25
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
	var hp_mult: float = 1.0 + float(current_floor - 1) * 0.38
	var dmg_mult: float = 1.0 + float(current_floor - 1) * 0.25
	var theme: Dictionary = FLOOR_THEMES.get(current_floor, FLOOR_THEMES[1])
	var boss_title: String = theme["boss_name"]

	# Chamber 0: Entry Hall (z: +4 to -6)
	_spawn_enemy(scn_skeleton, Vector3(-4.0, 0, -1.0), 0, hp_mult, dmg_mult)
	_spawn_enemy(scn_skeleton, Vector3(4.0, 0, -1.5), 0, hp_mult, dmg_mult)
	_spawn_enemy(scn_goblin, Vector3(-2.5, 0, -4.5), 0, hp_mult, dmg_mult)
	_spawn_enemy(scn_goblin, Vector3(3.0, 0, -5.0), 0, hp_mult, dmg_mult)
	if current_floor >= 2:
		_spawn_custom_enemy("mage", "Cultist Necromancer", Vector3(0.0, 0, -5.5), 0, int(50 * hp_mult), 3.7, int(12 * dmg_mult))

	# Chamber 1: The Pillared Crypt (z: -12 to -25)
	_spawn_enemy(scn_skeleton, Vector3(-5.5, 0, -13.0), 1, hp_mult, dmg_mult)
	_spawn_enemy(scn_skeleton, Vector3(5.5, 0, -13.0), 1, hp_mult, dmg_mult)
	_spawn_enemy(scn_goblin, Vector3(-2.5, 0, -17.0), 1, hp_mult, dmg_mult)
	_spawn_enemy(scn_goblin, Vector3(2.5, 0, -17.0), 1, hp_mult, dmg_mult)
	_spawn_enemy(scn_golem, Vector3(0.0, 0, -22.0), 1, hp_mult, dmg_mult)
	_spawn_custom_enemy("mage", "Cultist Necromancer", Vector3(-3.5, 0, -24.0), 1, int(52 * hp_mult), 3.6, int(12 * dmg_mult))

	# Chamber 2: Sanctum of the Obsidian Guard (z: -32 to -45)
	_spawn_enemy(scn_goblin, Vector3(-3.0, 0, -33.0), 2, hp_mult, dmg_mult)
	_spawn_enemy(scn_goblin, Vector3(3.0, 0, -33.0), 2, hp_mult, dmg_mult)
	_spawn_enemy(scn_golem, Vector3(-3.5, 0, -39.0), 2, hp_mult, dmg_mult)
	_spawn_enemy(scn_golem, Vector3(3.5, 0, -39.0), 2, hp_mult, dmg_mult)
	_spawn_custom_enemy("mage", "Cultist Necromancer", Vector3(-4.0, 0, -44.0), 2, int(58 * hp_mult), 3.7, int(13 * dmg_mult))
	_spawn_custom_enemy("mage", "Cultist Necromancer", Vector3(4.0, 0, -44.0), 2, int(58 * hp_mult), 3.7, int(13 * dmg_mult))

	# Chamber 3: Boss Throne Room (z: -52 to -68)
	_spawn_enemy(scn_skeleton, Vector3(-5.0, 0, -56.0), 3, hp_mult, dmg_mult)
	_spawn_enemy(scn_skeleton, Vector3(5.0, 0, -56.0), 3, hp_mult, dmg_mult)
	if current_floor >= 3:
		_spawn_enemy(scn_golem, Vector3(0.0, 0, -58.0), 3, hp_mult, dmg_mult)
	_spawn_custom_enemy("boss", boss_title, Vector3(0.0, 0, -63.0), 3, int(300 * hp_mult), 4.4 + float(current_floor - 1) * 0.25, int(22 * dmg_mult))

func _spawn_enemy(scene: PackedScene, pos: Vector3, cid: int, hp_mult: float = 1.0, dmg_mult: float = 1.0) -> Node3D:
	var e = scene.instantiate()
	e.chamber_id = cid
	e.max_health = int(round(float(e.max_health) * hp_mult))
	e.current_health = e.max_health
	e.attack_damage = int(round(float(e.attack_damage) * dmg_mult))
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
	return (not gate_nodes.has(cid - 1)) and entered_chambers.has(cid)

func on_enemy_defeated(cid: int, was_boss: bool):
	var remaining_in_chamber := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.get("chamber_id") == cid:
			remaining_in_chamber += 1

	if door_labels.has(cid) and is_instance_valid(door_labels[cid]) and remaining_in_chamber > 0:
		door_labels[cid].text = "SEALED DOOR — %d Enemies Left" % remaining_in_chamber

	if remaining_in_chamber == 0 and gate_nodes.has(cid):
		_open_gate(cid)

	if was_boss:
		if current_floor < MAX_FLOORS:
			_spawn_descent_portal()
		else:
			var ui = get_tree().get_first_node_in_group("ui")
			if ui and ui.has_method("show_victory"):
				ui.show_victory()

func _spawn_descent_portal():
	if is_instance_valid(descent_portal):
		return
	descent_portal = Node3D.new()
	props_root.add_child(descent_portal)
	descent_portal.position = Vector3(0.0, 0.15, -66.8)
	descent_portal_active_timer = 1.4

	# Glowing Outer Cyan-Gold Portal Ring
	var ring_mesh = MeshInstance3D.new()
	var torus = CylinderMesh.new()
	torus.top_radius = 1.9
	torus.bottom_radius = 1.9
	torus.height = 0.12
	torus.radial_segments = 32
	ring_mesh.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.25, 0.92, 1.0, 0.65)
	ring_mesh.material_override = mat
	descent_portal.add_child(ring_mesh)

	var p_light = OmniLight3D.new()
	p_light.light_color = Color(0.25, 0.92, 1.0)
	p_light.light_energy = 3.5
	p_light.omni_range = 7.0
	p_light.position = Vector3(0.0, 1.5, 0.0)
	descent_portal.add_child(p_light)

	var lbl = Label3D.new()
	lbl.text = "STAIRS TO FLOOR %d\nWalk Into Portal or Press [F] to Descend" % (current_floor + 1)
	lbl.font_size = 36
	lbl.outline_size = 10
	lbl.modulate = Color(0.35, 0.96, 1.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.6, 0.0)
	descent_portal.add_child(lbl)

	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_banner"):
		ui.show_banner("FLOOR %d GUARDIAN SLAIN! — DESCEND AT THE NORTH STAIRS!" % current_floor)

func _descend_to_next_floor():
	if current_floor >= MAX_FLOORS:
		return
	var next_f := current_floor + 1
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_door_open"):
		audio.play_door_open()

	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		player.global_position = Vector3(0.0, 0.0, 4.0)
		player.velocity = Vector3.ZERO
		if player.has_method("heal"):
			player.heal(45)

	_build_floor(next_f)
	var theme: Dictionary = FLOOR_THEMES.get(next_f, FLOOR_THEMES[1])
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_banner"):
		ui.show_banner("DESCENDED TO FLOOR %d: %s" % [next_f, theme["name"].to_upper()])

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
