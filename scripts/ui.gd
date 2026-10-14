extends CanvasLayer
## 3D Dungeon Crawler HUD, 3-Card RPG Level-Up Perk Draft, & Mystic Merchant Shop Controller
## Includes a 0.75s Anti-Misclick Safety Lock so combat clicks never accidentally pick a perk or shop item

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
var current_floor_num: int = 1
var max_floors_num: int = 3

var level_up_modal: Control = null
var active_perk_choices: Array = []
var card_buttons: Array[Button] = []
var modal_lock_timer: float = 0.0
const MODAL_SAFETY_LOCK_DURATION: float = 0.75

# Mystic Merchant Shop Modal state
var merchant_modal: Control = null
var merchant_lock_timer: float = 0.0
var merchant_buttons: Array[Button] = []
var merchant_purchase_counts: Dictionary = {
	"elixir": 0,
	"whetstone": 0,
	"conduit": 0,
	"tome": 0
}
const MERCHANT_ITEMS := [
	{
		"id": "elixir",
		"title": "Crimson Draught",
		"tag": "VITALITY",
		"base_cost": 30,
		"cost_step": 10,
		"desc": "Restores +65 HP immediately and permanently increases Max HP by +15.",
		"color": Color(0.35, 0.95, 0.5)
	},
	{
		"id": "whetstone",
		"title": "Runeforged Edge",
		"tag": "WEAPONSMITH",
		"base_cost": 45,
		"cost_step": 15,
		"desc": "Temper your greatsword with abyssal runes: +8 Attack Damage and +6% Crit Chance.",
		"color": Color(1.0, 0.55, 0.25)
	},
	{
		"id": "conduit",
		"title": "Arcane Conduit",
		"tag": "SPELLBLADE",
		"base_cost": 60,
		"cost_step": 20,
		"desc": "Grants +1 Rank to Stormcaller's Arc (Chain Lightning) AND +1 Rank to Crescent Moon Wave.",
		"color": Color(0.3, 0.85, 1.0)
	},
	{
		"id": "tome",
		"title": "Tome of Ascension",
		"tag": "ANCIENT LORE",
		"base_cost": 80,
		"cost_step": 25,
		"desc": "Unseals an immediate 3-Card Ascension Perk Draft as soon as you leave the shop.",
		"color": Color(0.85, 0.5, 1.0)
	}
]

func _ready():
	add_to_group("ui")
	stamina_bar.modulate = Color(0.25, 0.82, 1.0)
	xp_bar.modulate = Color(0.78, 0.45, 1.0)
	boss_bar.modulate = Color(1.0, 0.25, 0.18)
	_build_level_up_modal()
	_build_merchant_modal()
	await get_tree().process_frame
	update_enemies_remaining()

func _process(delta: float):
	if level_up_modal and level_up_modal.visible and modal_lock_timer > 0.0:
		modal_lock_timer = maxf(0.0, modal_lock_timer - delta)
		var sub: Label = level_up_modal.get_node("SubHeaderLabel")
		if modal_lock_timer > 0.0:
			sub.text = "Safety Lock (%.1fs)... Release mouse, then Click SELECT or Press [1], [2], [3]" % modal_lock_timer
			for i in range(card_buttons.size()):
				if is_instance_valid(card_buttons[i]):
					card_buttons[i].disabled = true
					card_buttons[i].text = "WAIT %.1fs..." % modal_lock_timer
		else:
			sub.text = "Click a Card's [SELECT] Button or Press [1], [2], or [3]"
			for i in range(card_buttons.size()):
				if is_instance_valid(card_buttons[i]):
					card_buttons[i].disabled = false
					card_buttons[i].text = "SELECT [%d]" % (i + 1)

	if merchant_modal and merchant_modal.visible and merchant_lock_timer > 0.0:
		merchant_lock_timer = maxf(0.0, merchant_lock_timer - delta)
		if merchant_lock_timer <= 0.0:
			_refresh_merchant_cards()

func _input(event: InputEvent):
	# Handle Merchant Modal input when open
	if merchant_modal and merchant_modal.visible:
		if merchant_lock_timer > 0.0:
			if event is InputEventMouseButton:
				get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			var kc = event.keycode
			var pkc = event.physical_keycode
			if kc == KEY_ESCAPE or pkc == KEY_ESCAPE or kc == KEY_F or pkc == KEY_F:
				close_merchant_shop()
				get_viewport().set_input_as_handled()
			elif kc == KEY_1 or pkc == KEY_1 or kc == KEY_KP_1:
				_on_merchant_buy_pressed(0)
				get_viewport().set_input_as_handled()
			elif kc == KEY_2 or pkc == KEY_2 or kc == KEY_KP_2:
				_on_merchant_buy_pressed(1)
				get_viewport().set_input_as_handled()
			elif kc == KEY_3 or pkc == KEY_3 or kc == KEY_KP_3:
				_on_merchant_buy_pressed(2)
				get_viewport().set_input_as_handled()
			elif kc == KEY_4 or pkc == KEY_4 or kc == KEY_KP_4:
				_on_merchant_buy_pressed(3)
				get_viewport().set_input_as_handled()
		return

	if not level_up_modal or not level_up_modal.visible:
		# Allow pressing TAB at any time to open a queued level-up draft even mid-combat
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
			var player = get_tree().get_first_node_in_group("player")
			if player and player.get("pending_level_ups") > 0 and player.has_method("_trigger_next_level_up_draft"):
				player._trigger_next_level_up_draft()
				get_viewport().set_input_as_handled()
		return

	# Absorb all clicks/keys while the 0.75s anti-misclick safety lock is active
	if modal_lock_timer > 0.0:
		if event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var kc = event.keycode
		var pkc = event.physical_keycode
		if (kc == KEY_1 or pkc == KEY_1 or kc == KEY_KP_1 or pkc == KEY_KP_1) and active_perk_choices.size() >= 1:
			_on_perk_card_chosen(0)
			get_viewport().set_input_as_handled()
		elif (kc == KEY_2 or pkc == KEY_2 or kc == KEY_KP_2 or pkc == KEY_KP_2) and active_perk_choices.size() >= 2:
			_on_perk_card_chosen(1)
			get_viewport().set_input_as_handled()
		elif (kc == KEY_3 or pkc == KEY_3 or kc == KEY_KP_3 or pkc == KEY_KP_3) and active_perk_choices.size() >= 3:
			_on_perk_card_chosen(2)
			get_viewport().set_input_as_handled()

func is_level_up_open() -> bool:
	return (level_up_modal != null and level_up_modal.visible) or (merchant_modal != null and merchant_modal.visible)

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
	var relic_str = "None" if relics.is_empty() else ", ".join(relics.slice(max(0, relics.size() - 3), relics.size()))
	stats_label.text = "Gold: %d  |  ATK: %d  |  Builds: %s" % [gold, atk, relic_str]

func set_floor_info(f_num: int, max_f: int):
	current_floor_num = f_num
	max_floors_num = max_f
	update_enemies_remaining()

func set_chamber_title(title: String):
	chamber_label.text = "FLOOR %d/%d  •  %s" % [current_floor_num, max_floors_num, title]
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
	if enemy_count > 0:
		score_label.text = "Floor %d/%d  |  Enemies Remaining: %d" % [current_floor_num, max_floors_num, enemy_count]
		score_label.modulate = Color(0.95, 0.85, 0.55)
	elif current_floor_num < max_floors_num:
		score_label.text = "Floor %d Cleared! Enter Descent Portal at North Stairs" % current_floor_num
		score_label.modulate = Color(0.35, 0.95, 1.0)

# ============================================================================
# MYSTIC DUNGEON MERCHANT SHOP MODAL
# ============================================================================

func _build_merchant_modal():
	merchant_modal = Control.new()
	merchant_modal.name = "MerchantModal"
	merchant_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	merchant_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	merchant_modal.visible = false
	add_child(merchant_modal)

	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.03, 0.02, 0.06, 0.84)
	merchant_modal.add_child(dimmer)

	var header = Label.new()
	header.name = "HeaderLabel"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 48.0
	header.offset_bottom = 92.0
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 32)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.28))
	header.text = "MYSTIC DUNGEON MERCHANT — TRADE GOLD FOR RELICS"
	merchant_modal.add_child(header)

	var gold_lbl = Label.new()
	gold_lbl.name = "GoldBalanceLabel"
	gold_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gold_lbl.offset_top = 96.0
	gold_lbl.offset_bottom = 132.0
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 22)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	gold_lbl.text = "YOUR GOLD: 0"
	merchant_modal.add_child(gold_lbl)

	var hbox = HBoxContainer.new()
	hbox.name = "ShopCardsContainer"
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.offset_left = -560.0
	hbox.offset_top = -155.0
	hbox.offset_right = 560.0
	hbox.offset_bottom = 175.0
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	merchant_modal.add_child(hbox)

	var close_btn = Button.new()
	close_btn.name = "CloseShopButton"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.offset_left = -180.0
	close_btn.offset_top = -95.0
	close_btn.offset_right = 180.0
	close_btn.offset_bottom = -45.0
	close_btn.text = "LEAVE MERCHANT [F / ESC]"
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_merchant_shop)
	merchant_modal.add_child(close_btn)

func open_merchant_shop():
	if victory_shown:
		return
	if level_up_modal and level_up_modal.visible:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player or player.get("is_dead"):
		return

	merchant_lock_timer = 0.45
	_refresh_merchant_cards()
	merchant_modal.visible = true
	merchant_modal.modulate.a = 0.0
	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(merchant_modal, "modulate:a", 1.0, 0.2)
	get_tree().paused = true

func close_merchant_shop():
	if not merchant_modal or not merchant_modal.visible:
		return
	merchant_modal.visible = false
	get_tree().paused = false
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("pending_level_ups") > 0 and player.has_method("_trigger_next_level_up_draft"):
		player.call_deferred("_trigger_next_level_up_draft")

func _get_merchant_item_cost(index: int) -> int:
	var item: Dictionary = MERCHANT_ITEMS[index]
	var id: String = item["id"]
	var count: int = merchant_purchase_counts.get(id, 0)
	return int(item["base_cost"]) + count * int(item["cost_step"])

func _refresh_merchant_cards():
	var player = get_tree().get_first_node_in_group("player")
	var current_gold: int = player.gold if player else 0

	var gold_lbl: Label = merchant_modal.get_node("GoldBalanceLabel")
	gold_lbl.text = "YOUR GOLD: %d   •   Click [BUY] or Press [1]–[4]   •   Press [F] or [ESC] to Close" % current_gold

	var hbox: HBoxContainer = merchant_modal.get_node("ShopCardsContainer")
	for c in hbox.get_children():
		c.queue_free()
	merchant_buttons.clear()

	for i in range(MERCHANT_ITEMS.size()):
		var item: Dictionary = MERCHANT_ITEMS[i]
		var cost: int = _get_merchant_item_cost(i)
		var can_afford: bool = current_gold >= cost
		var card = _create_merchant_card(i, item, cost, can_afford)
		hbox.add_child(card)

func _create_merchant_card(index: int, item: Dictionary, cost: int, can_afford: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(255, 315)

	var style = StyleBoxFlat.new()
	var accent: Color = item.get("color", Color(1.0, 0.85, 0.3))
	style.bg_color = Color(0.08, 0.08, 0.14, 0.96)
	style.border_color = accent if can_afford else Color(0.35, 0.35, 0.42, 0.85)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var badge = Label.new()
	badge.text = "[ KEY %d ]  •  %s" % [index + 1, item.get("tag", "MERCHANT")]
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", accent.lightened(0.25))
	vbox.add_child(badge)

	var title_lbl = Label.new()
	title_lbl.text = item.get("title", "Upgrade")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
	vbox.add_child(title_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "COST: %d GOLD" % cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 16)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25) if can_afford else Color(1.0, 0.4, 0.4))
	vbox.add_child(cost_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl = Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.98))
	vbox.add_child(desc_lbl)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 42)
	if merchant_lock_timer > 0.0:
		btn.text = "WAIT..."
		btn.disabled = true
	elif not can_afford:
		btn.text = "NEED %d GOLD" % cost
		btn.disabled = true
	else:
		btn.text = "BUY [%d] — %dG" % [index + 1, cost]
		btn.disabled = false
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func():
		if merchant_lock_timer <= 0.0:
			_on_merchant_buy_pressed(index)
	)
	vbox.add_child(btn)
	merchant_buttons.append(btn)

	return panel

func _on_merchant_buy_pressed(index: int):
	if merchant_lock_timer > 0.0 or index < 0 or index >= MERCHANT_ITEMS.size():
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("buy_merchant_item"):
		return
	var item: Dictionary = MERCHANT_ITEMS[index]
	var id: String = item["id"]
	var cost: int = _get_merchant_item_cost(index)
	if player.buy_merchant_item(id, cost):
		merchant_purchase_counts[id] = merchant_purchase_counts.get(id, 0) + 1
		_refresh_merchant_cards()

# ============================================================================
# 3-CARD RPG LEVEL-UP PERK SELECTION MODAL
# ============================================================================

func _build_level_up_modal():
	level_up_modal = Control.new()
	level_up_modal.name = "LevelUpModal"
	level_up_modal.process_mode = Node.PROCESS_MODE_ALWAYS
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
	sub.name = "SubHeaderLabel"
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 132.0
	sub.offset_bottom = 165.0
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	sub.text = "Click a Card's [SELECT] Button or Press [1], [2], or [3]"
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
	if victory_shown:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_dead"):
		return

	active_perk_choices = choices
	card_buttons.clear()
	modal_lock_timer = MODAL_SAFETY_LOCK_DURATION

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
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
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
	btn.text = "WAIT 0.8s..."
	btn.disabled = true
	btn.custom_minimum_size = Vector2(0, 44)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func():
		if modal_lock_timer <= 0.0:
			_on_perk_card_chosen(index)
	)
	vbox.add_child(btn)
	card_buttons.append(btn)

	return panel

func _on_perk_card_chosen(index: int):
	if modal_lock_timer > 0.0:
		return
	if index < 0 or index >= active_perk_choices.size():
		return
	var chosen: Dictionary = active_perk_choices[index]
	active_perk_choices.clear()
	card_buttons.clear()
	level_up_modal.visible = false
	get_tree().paused = false

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_level_perk"):
		player.apply_level_perk(chosen)

func show_victory():
	if victory_shown:
		return
	victory_shown = true
	if level_up_modal and level_up_modal.visible:
		level_up_modal.visible = false
		active_perk_choices.clear()
		card_buttons.clear()
		get_tree().paused = false
	if merchant_modal and merchant_modal.visible:
		merchant_modal.visible = false
		get_tree().paused = false

	score_label.text = "Victory! All 3 Dungeon Floors Cleansed!"
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
