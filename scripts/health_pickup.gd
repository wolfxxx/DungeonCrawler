extends Area3D
## 3D Pickup Item (Health Elixir, Soul Gem, or Gold Stack)

@export var pickup_type: String = "health" # "health", "soul_gem", "gold"
@export var amount: int = 30

@onready var visual: Node3D = $Visual
@onready var glow_light: OmniLight3D = $Visual/GlowLight

var time_alive: float = 0.0
var collected: bool = false

func _ready():
	time_alive = randf() * TAU
	if pickup_type == "soul_gem":
		_swap_model("res://models/pickup_soul_gem.glb", Color(0.2, 0.9, 1.0))
	elif pickup_type == "gold":
		_swap_model("res://addons/kaykit_dungeon_remastered/Assets/gltf/coin_stack_small.gltf.glb", Color(1.0, 0.82, 0.2))

func _swap_model(res_path: String, light_col: Color):
	if visual.has_node("Model"):
		visual.get_node("Model").queue_free()
	var scene = load(res_path)
	if scene:
		var inst = scene.instantiate()
		inst.name = "Model"
		visual.add_child(inst)
	if glow_light:
		glow_light.light_color = light_col

func _physics_process(delta: float):
	if collected:
		return
	time_alive += delta * 3.0
	visual.position.y = 0.12 + sin(time_alive) * 0.10
	visual.rotation.y += delta * 1.8

	# Magnetic pull toward nearby player
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < 3.4:
			global_position = global_position.move_toward(player.global_position, delta * 7.5)

func _on_body_entered(body: Node3D):
	if collected:
		return
	if body.is_in_group("player"):
		collected = true
		if pickup_type == "health" and body.has_method("heal"):
			body.heal(amount)
		elif pickup_type == "soul_gem" and body.has_method("collect_soul_gem"):
			body.collect_soul_gem(amount)
		elif pickup_type == "gold" and body.has_method("add_gold"):
			body.add_gold(amount)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual, "scale", Vector3(1.6, 1.6, 1.6), 0.18)
		tween.tween_property(visual, "position:y", 0.9, 0.18)
		if glow_light:
			tween.tween_property(glow_light, "light_energy", 0.0, 0.18)
		tween.chain().tween_callback(queue_free)
