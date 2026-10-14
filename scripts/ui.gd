extends CanvasLayer
## 3D Dungeon Crawler HUD & 3-Card RPG Level-Up Perk Draft Controller

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var stamina_label: Label = $StaminaBar/StaminaLabel
@onready var xp_bar: ProgressBar = $XPBar
@onready var xp_label: Label = $XPBar/XPLabel
@onready var score_label: Label = $Score
@onready var stats_label: Label = $StatsLabel
@onready var chamber_label: Label = $ChamberLabel
@onready var boss_panel: Control = $BossPanel
@onready var boss_name_lbl: Label = $BossPanel/BossName
@onready var boss_bar: ProgressBar = $BossPanel/BossBar
@onready var banner_label: Label = $BannerLabel

var victory_shown: bool = false
var level_up_modal: Control = null
var active_perk_choices: Array = []

func _ready():
	add_to_group("ui")
	stamina_bar.modulate = Color(0.25, 0.82, 1.0)
	xp_bar.modulate = Color(0.78, 0.45, 1.0)
	boss_bar.modulate = Color(1.0, 0.25, 0.18)
	_build_level_up_modal()
	await get_tree().process_frame
	update_enemies_remaining()

func _unhandled_input(event: InputEvent):
	if not level_up_modal or not level_up_modal.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1 and active_perk_choices.size() >= 1:
			_on_perk_card_chosen(0)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_2 and active_perk_choices.size() >= 2:
			_on_perk_card_chosen(1)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_3 and active_perk_choices.size() >= 3:
			_on_perk_card_chosen(2)
			get_viewport().set_input_as_handled()

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

func update_xp(level: int, current_xp: int, xp_to_next: int):
	xp_bar.max_value = xp_to_next
	xp_bar.value = current_xp
	xp_label.text = "LVL %d  —  XP: %d / %d" % [level, current_xp, xp_to_next]

func update_stats(gold: int, atk: int, relics: Array):
	var relic_str = "None" if relics.is_empty() else ", ".join(relics)
	stats_label.text = "Gold: %d  |  ATK: %d  |  Builds: %s" % [gold, atk, relic_str]

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

# ============================================================================
# 3-CARD RPG LEVEL-UP PERK SELECTION MODAL
# ============================================================================

func _build_level_up_modal():
	level_up_modal = Control.new()
	level_up_modal.name = "LevelUpModal"
	level_up_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_up_modal.visible = false
	add_child(level_up_modal)

	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.03, 0.03, 0.07, 0.82)
	level_up_modal.add_child(dimmer)

	var header = Label.new()
	header.name = "HeaderLabel"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 80.0
	header.offset_bottom = 130.0
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 34)
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	header.text = "LEVEL UP! — CHOOSE AN ASCENSION PERK"
	level_up_modal.add_child(header)

	var sub = Label.new()
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 132.0
	sub.offset_bottom = 165.0
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	sub.text = "Click a Card or Press [1], [2], or [3]"
	level_up_modal.add_child(sub)

	var hbox = HBoxContainer.new()
	hbox.name = "CardsContainer"
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.offset_left = -470.0
	hbox.offset_top = -150.0
	hbox.offset_right = 470.0
	hbox.offset_bottom = 190.0
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 26)
	level_up_modal.add_child(hbox)

func show_level_up_choices(level: int, choices: Array):
	active_perk_choices = choices
	var header: Label = level_up_modal.get_node("HeaderLabel")
	header.text = "LEVEL %d REACHED! — CHOOSE AN ASCENSION PERK" % level

	var hbox: HBoxContainer = level_up_modal.get_node("CardsContainer")
	for c in hbox.get_children():
		c.queue_free()

	for i in range(choices.size()):
		var perk: Dictionary = choices[i]
		var card = _create_perk_card(i, perk)
		hbox.add_child(card)

	level_up_modal.visible = true
	level_up_modal.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(level_up_modal, "modulate:a", 1.0, 0.22)
	get_tree().paused = true

func _create_perk_card(index: int, perk: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(290, 320)

	var style = StyleBoxFlat.new()
	var accent: Color = perk.get("color", Color(0.4, 0.8, 1.0))
	style.bg_color = Color(0.09, 0.10, 0.16, 0.96)
	style.border_color = accent
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var key_badge = Label.new()
	key_badge.text = "[ KEY %d ]  •  %s" % [index + 1, perk.get("tag", "ASCENSION")]
	key_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_badge.add_theme_font_size_override("font_size", 13)
	key_badge.add_theme_color_override("font_color", accent.lightened(0.25))
	vbox.add_child(key_badge)

	var title_lbl = Label.new()
	title_lbl.text = perk.get("title", "Perk")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
	vbox.add_child(title_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl = Label.new()
	desc_lbl.text = perk.get("desc", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.98))
	vbox.add_child(desc_lbl)

	var btn = Button.new()
	btn.text = "SELECT [%d]" % (index + 1)
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(func(): _on_perk_card_chosen(index))
	vbox.add_child(btn)

	return panel

func _on_perk_card_chosen(index: int):
	if index < 0 or index >= active_perk_choices.size():
		return
	var chosen: Dictionary = active_perk_choices[index]
	level_up_modal.visible = false
	get_tree().paused = false

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_level_perk"):
		player.apply_level_perk(chosen)

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
