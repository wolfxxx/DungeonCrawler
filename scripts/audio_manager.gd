extends Node
## Global Audio Manager - plays ElevenLabs sound effects, voice lines, and looping dungeon music

func _ready():
	add_to_group("audio_manager")
	var music = get_node_or_null("MusicDungeon")
	if music and music.stream:
		if music.stream is AudioStreamMP3:
			music.stream.loop = true
		if not music.playing:
			music.play()

func play_sound(sound_name: String, pitch_min: float = 0.94, pitch_max: float = 1.06):
	var player = get_node_or_null(sound_name) as AudioStreamPlayer
	if player and player.stream:
		player.pitch_scale = randf_range(pitch_min, pitch_max)
		player.play()

func play_attack():
	play_sound("PlayerAttack", 0.9, 1.12)

func play_special():
	play_sound("PlayerSpecial", 0.95, 1.05)

func play_dash():
	play_sound("PlayerDash", 0.95, 1.08)

func play_enemy_hit():
	play_sound("EnemyHit", 0.9, 1.1)

func play_enemy_death():
	play_sound("EnemyDeath", 0.88, 1.08)

func play_player_hit():
	play_sound("PlayerHit", 0.92, 1.05)

func play_pickup():
	play_sound("Pickup", 0.96, 1.06)

func play_gold():
	play_sound("PickupGold", 0.95, 1.15)

func play_chest():
	play_sound("ChestOpen", 0.98, 1.02)

func play_barrel_break():
	play_sound("BarrelBreak", 0.9, 1.1)

func play_door_open():
	play_sound("DoorOpen", 0.96, 1.04)

func play_boss_roar():
	play_sound("BossRoar", 0.95, 1.02)

func play_fireball():
	play_sound("Fireball", 0.92, 1.1)

func play_victory():
	play_sound("Victory", 1.0, 1.0)

func play_game_over():
	play_sound("GameOver", 1.0, 1.0)

func play_vo(vo_node: String):
	var player = get_node_or_null(vo_node) as AudioStreamPlayer
	if player and player.stream:
		player.pitch_scale = 1.0
		player.play()
