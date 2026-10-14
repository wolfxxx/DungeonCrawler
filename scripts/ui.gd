extends CanvasLayer
## 3D Dungeon Crawler HUD Controller

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var stamina_label: Label = $StaminaBar/StaminaLabel
@onready var score_label: Label = $Score
@onready var stats_label: Label = $StatsLabel
@onready var chamber_label: Label = $ChamberLabel
@onready var boss_panel: Control = $BossPanel
@onready var boss_name_lbl: Label = $BossPanel/BossName
@onready var boss_bar: ProgressBar = $BossPanel/BossBar
@onready var banner_label: Label = $BannerLabel

var victory_shown: bool = false

func _ready():
	add_to_group("ui")
	stamina_bar.modulate = Color(0.25, 0.82, 1.0)
	boss_bar.modulate = Color(1.0, 0.25, 0.18)
	await get_tree().process_frame
	update_enemies_remaining()

func update_health(current: int, maximum: int):
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HP: " + str(current) + " / " + str(maximum)
	if current < maximum * 0.3:
		health_bar.modulate = Color(1.0, 0.28, 0.28)
	elif current < maximum * 0.6:
		health_bar.modulate = Color(1.0, 0.78, 0.25)
	else:
		health_bar.modulate = Color(0.28, 0.95, 0.4)

func update_stamina(current: float, maximum: float):
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = "STAMINA: " + str(int(round(current))) + "%"

func update_stats(gold: int, atk: int, relics: Array):
	var relic_str = "None" if relics.is_empty() else ", ".join(relics)
	stats_label.text = "Gold: %d  |  ATK: %d  |  Relics: %s" % [gold, atk, relic_str]

func set_chamber_title(title: String):
	chamber_label.text = title
	show_banner(title)

func show_banner(msg: String):
	banner_label.text = msg
	banner_label.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.8)

func show_boss_bar(bname: String, current: int, maximum: int):
	boss_panel.visible = true
	boss_name_lbl.text = bname.to_upper()
	boss_bar.max_value = maximum
	boss_bar.value = current

func update_boss_bar(current: int, maximum: int):
	boss_bar.max_value = maximum
	boss_bar.value = current

func hide_boss_bar():
	boss_panel.visible = false

func update_enemies_remaining():
	var enemy_count = get_tree().get_nodes_in_group("enemies").size()
	score_label.text = "Enemies Remaining: " + str(enemy_count)
	if enemy_count == 0 and not victory_shown:
		show_victory()

func show_victory():
	if victory_shown:
		return
	victory_shown = true
	score_label.text = "Victory! The Catacombs are cleansed!"
	score_label.modulate = Color(0.35, 1.0, 0.45)

	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio:
		audio.play_victory()
		if audio.has_method("play_vo"):
			audio.play_vo("VoVictory")

	await get_tree().create_timer(1.8).timeout
	var game_over_scene = preload("res://scenes/game_over.tscn")
	var game_over = game_over_scene.instantiate()
	game_over.is_victory = true
	get_tree().current_scene.add_child(game_over)
