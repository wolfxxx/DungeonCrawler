extends Node3D
## 3D Billboard Floating Health Bar for Enemies

@onready var bg_mesh: MeshInstance3D = $BgMesh
@onready var fill_pivot: Node3D = $FillPivot
@onready var fill_mesh: MeshInstance3D = $FillPivot/FillMesh

var bg_mat: StandardMaterial3D
var fill_mat: StandardMaterial3D
var max_width: float = 1.14

func _ready():
	bg_mat = StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.08, 0.1, 0.9)
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.billboard_keep_scale = true
	bg_mesh.material_override = bg_mat

	fill_mat = StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.2, 0.9, 0.3, 1.0)
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.billboard_keep_scale = true
	fill_mesh.material_override = fill_mat

func _process(_delta: float):
	var cam = get_viewport().get_camera_3d()
	if cam:
		look_at(cam.global_position, Vector3.UP)

func update_health(current: int, maximum: int):
	var pct = clampf(float(current) / float(max(1, maximum)), 0.0, 1.0)
	fill_pivot.scale.x = max(0.001, pct)
	fill_pivot.position.x = -(1.0 - pct) * (max_width * 0.5)
	if not fill_mat:
		return
	if pct > 0.6:
		fill_mat.albedo_color = Color(0.2, 0.9, 0.35)
	elif pct > 0.3:
		fill_mat.albedo_color = Color(1.0, 0.75, 0.15)
	else:
		fill_mat.albedo_color = Color(0.95, 0.2, 0.2)
