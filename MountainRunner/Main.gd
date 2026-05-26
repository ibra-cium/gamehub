extends Node2D

const START_SPEED = 400.0
const MAX_SPEED = 1000.0
const SPEED_ACCEL = 12.0

var game_speed = START_SPEED
var score = 0.0
var high_score = 0
var coins = 0
var gems = 0
var game_active = false

# Music & Playlist variables
var playlist_paths = []
var playlist_names = []
var current_song_index = 0
var is_game_paused = false
var bg_music_player = AudioStreamPlayer.new()
var sfx_muted = false
var music_muted = false

var pause_btn: Button
var pause_overlay: ColorRect
var music_panel: PanelContainer
var music_label: Label
var music_play_pause_btn: Button
var music_next_btn: Button
var music_dropdown: OptionButton
var sfx_mute_btn: Button
var music_mute_btn: Button

@onready var player = $Player
@onready var spawn_timer = $SpawnTimer
@onready var parallax_bg = $ParallaxBackground
@onready var score_label = $UI/HUD/ScoreLabel
@onready var high_score_label = $UI/HUD/HighScoreLabel
@onready var coins_label = $UI/HUD/CoinsLabel
@onready var gems_label = $UI/HUD/GemsLabel
@onready var psych_label = $UI/HUD/PsychLabel
@onready var shield_status_label = $UI/HUD/ShieldStatusLabel
@onready var magnet_status_label = $UI/HUD/MagnetStatusLabel
@onready var start_screen = $UI/StartScreen
@onready var game_over_screen = $UI/GameOverScreen
@onready var final_score_label = $UI/GameOverScreen/FinalScoreLabel
@onready var start_high_score_label = $UI/StartScreen/StartHighScoreLabel
@onready var game_over_title = $UI/GameOverScreen/GameOverLabel
@onready var respawn_button = $UI/GameOverScreen/RespawnButton
@onready var restart_button = $UI/GameOverScreen/RestartButton
@onready var camera = $Camera2D
@onready var rain_particles = $RainParticles

var obstacle_scene = preload("res://Obstacle.tscn")
var coin_scene = preload("res://Coin.tscn")
var gem_scene = preload("res://Gem.tscn")
var powerup_scene = preload("res://Powerup.tscn")

const SAVE_PATH = "user://highscore.save"

# Audio assets preloads
var sound_coin = preload("res://assets/audio/coin.wav")
var sound_gem = preload("res://assets/audio/gem.wav")
var sound_powerup = preload("res://assets/audio/powerup.wav")
var sound_death = preload("res://assets/audio/death.wav")
var sound_warning = preload("res://assets/audio/warning.wav")
var sound_game_over = preload("res://assets/audio/game_over.wav")

func play_sound(stream: AudioStream):
	if sfx_muted:
		return
	var player_node = AudioStreamPlayer.new()
	add_child(player_node)
	player_node.stream = stream
	player_node.finished.connect(player_node.queue_free)
	player_node.play()

# Camera shake variables
var shake_intensity = 0.0
var shake_duration = 0.0

# Glitch weather/threat alert tracking variables
var transitioned_250 = false
var transitioned_500 = false
var target_sky_color = Color.WHITE
var target_mtn_back = Color.WHITE
var target_mtn_mid = Color.WHITE
var target_mtn_front = Color.WHITE
var target_rain_color = Color(0.45, 0.6, 0.8, 0.4)

# Psychological messages that show up randomly
var psych_messages = [
	"Why are you running?",
	"Are you running from your responsibilities?",
	"The mountains know what you did.",
	"Did you remember to lock your front door?",
	"Wealth increases, yet you feel empty.",
	"Everything is fine. Keep running.",
	"Behind you. (Just kidding)",
	"You cannot outrun the simulation.",
	"Shiny coins won't fill the void.",
	"Your progress is being monitored.",
	"Is this game actually fun for you?",
	"The rocks are stationary. You are the one moving.",
	"Did you hear that sound?"
]

var death_messages = [
	"Your reality collapsed. The coins remain.",
	"A rock has claimed your backpack.",
	"You fell. Nobody saw it.",
	"Your running contract has been terminated.",
	"Another failed attempt in the void.",
	"You ran into a warning sign. It warned you.",
	"The mountain has claimed another soul.",
	"Is this the best you can do? Honestly?"
]

func _ready():
	_setup_inputs()
	
	player.collided.connect(_on_player_collided)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Connect UI buttons
	$UI/StartScreen/StartButton.pressed.connect(start_game)
	restart_button.pressed.connect(start_game)
	respawn_button.pressed.connect(respawn_with_gem)
	
	load_high_score()
	
	# Initialize background music player and playlist
	add_child(bg_music_player)
	bg_music_player.finished.connect(_on_bg_music_finished)
	load_playlist()
	_setup_music_and_pause_ui()
	
	show_start_screen()
	
	# Start playing music automatically if playlist is loaded
	if playlist_paths.size() > 0:
		play_song_at_index(0)

func _setup_inputs():
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		InputMap.action_add_event("jump", ev)
		var ev2 = InputEventKey.new()
		ev2.physical_keycode = KEY_UP
		InputMap.action_add_event("jump", ev2)
		var ev3 = InputEventKey.new()
		ev3.physical_keycode = KEY_W
		InputMap.action_add_event("jump", ev3)
		
	if not InputMap.has_action("slide"):
		InputMap.add_action("slide")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_DOWN
		InputMap.action_add_event("slide", ev)
		var ev2 = InputEventKey.new()
		ev2.physical_keycode = KEY_S
		InputMap.action_add_event("slide", ev2)

func _process(delta):
	# Handle camera shake processing (runs even if game is paused/ended to complete the shake)
	if shake_duration > 0.0:
		shake_duration -= delta
		if shake_duration <= 0.0:
			camera.offset = Vector2.ZERO
		else:
			camera.offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)

	if not game_active:
		return
		
	game_speed = min(game_speed + SPEED_ACCEL * delta, MAX_SPEED)
	score += (game_speed * 0.05) * delta
	score_label.text = "SCORE: %d m" % int(score)
	
	# Scroll Parallax Background
	parallax_bg.scroll_offset.x -= game_speed * delta

	# Background transitions & glitch alerts based on score
	if score > 500:
		target_sky_color = Color(0.9, 0.4, 0.4, 1.0) # Crimson sky
		target_mtn_back = Color(0.5, 0.1, 0.1, 1.0)
		target_mtn_mid = Color(0.4, 0.1, 0.1, 1.0)
		target_mtn_front = Color(0.3, 0.05, 0.05, 1.0)
		target_rain_color = Color(0.9, 0.4, 0.4, 0.5) # Translucent red rain
		if not transitioned_500:
			transitioned_500 = true
			shake_camera(15.0, 0.8)
			trigger_threat_alert("CRITICAL ERROR: VOID TEMPERATURE RISING")
			play_sound(sound_warning)
	elif score > 250:
		target_sky_color = Color(0.6, 0.5, 0.8, 1.0) # Cyber purple sky
		target_mtn_back = Color(0.3, 0.2, 0.5, 1.0)
		target_mtn_mid = Color(0.2, 0.15, 0.4, 1.0)
		target_mtn_front = Color(0.15, 0.1, 0.3, 1.0)
		target_rain_color = Color(0.7, 0.5, 0.9, 0.45) # Translucent purple rain
		if not transitioned_250:
			transitioned_250 = true
			shake_camera(10.0, 0.6)
			trigger_threat_alert("WARNING: SIMULATION INTEGRITY DEGRADING")
			play_sound(sound_warning)
	else:
		target_sky_color = Color.WHITE
		target_mtn_back = Color.WHITE
		target_mtn_mid = Color.WHITE
		target_mtn_front = Color.WHITE
		target_rain_color = Color(0.45, 0.6, 0.8, 0.4) # Normal translucent blue rain

	# Smoothly interpolate colors (lerp) for visual elegance
	parallax_bg.get_node("Sky/Sprite2D").modulate = parallax_bg.get_node("Sky/Sprite2D").modulate.lerp(target_sky_color, 2.0 * delta)
	parallax_bg.get_node("MtnBack/Sprite2D").modulate = parallax_bg.get_node("MtnBack/Sprite2D").modulate.lerp(target_mtn_back, 2.0 * delta)
	parallax_bg.get_node("MtnMid/Sprite2D").modulate = parallax_bg.get_node("MtnMid/Sprite2D").modulate.lerp(target_mtn_mid, 2.0 * delta)
	parallax_bg.get_node("MtnFront/Sprite2D").modulate = parallax_bg.get_node("MtnFront/Sprite2D").modulate.lerp(target_mtn_front, 2.0 * delta)
	rain_particles.color = rain_particles.color.lerp(target_rain_color, 2.0 * delta)

	# Update Powerup Status Labels in HUD
	if player.has_shield:
		shield_status_label.text = "SHIELD: ACTIVE"
		shield_status_label.modulate = Color(0.2, 0.9, 0.4) # Neon Green
	else:
		shield_status_label.text = "SHIELD: INACTIVE"
		shield_status_label.modulate = Color(0.5, 0.5, 0.5, 0.5)

	if player.has_magnet:
		magnet_status_label.text = "MAGNET: %.1fs" % player.magnet_timer
		magnet_status_label.modulate = Color(1.0, 0.7, 0.2) # Neon Amber/Orange
	else:
		magnet_status_label.text = "MAGNET: INACTIVE"
		magnet_status_label.modulate = Color(0.5, 0.5, 0.5, 0.5)

	if int(score) % 75 == 0 and int(score) > 0 and randf() < 0.1:
		trigger_psych_message()

func start_game():
	get_tree().call_group("obstacles", "queue_free")
	get_tree().call_group("coins", "queue_free")
	get_tree().call_group("gems", "queue_free")
	get_tree().call_group("powerups", "queue_free")
	
	score = 0.0
	coins = 0
	gems = 0
	game_speed = START_SPEED
	game_active = true
	
	# Reset pause state
	get_tree().paused = false
	is_game_paused = false
	if pause_overlay:
		pause_overlay.hide()
	if pause_btn:
		pause_btn.show()
	
	transitioned_250 = false
	transitioned_500 = false
	target_sky_color = Color.WHITE
	target_mtn_back = Color.WHITE
	target_mtn_mid = Color.WHITE
	target_mtn_front = Color.WHITE
	target_rain_color = Color(0.45, 0.6, 0.8, 0.4)
	rain_particles.color = Color(0.45, 0.6, 0.8, 0.4)
	
	coins_label.text = "COINS: 0"
	gems_label.text = "GEMS: 0"
	psych_label.text = ""
	
	parallax_bg.get_node("Sky/Sprite2D").modulate = Color.WHITE
	parallax_bg.get_node("MtnBack/Sprite2D").modulate = Color.WHITE
	parallax_bg.get_node("MtnMid/Sprite2D").modulate = Color.WHITE
	parallax_bg.get_node("MtnFront/Sprite2D").modulate = Color.WHITE
	
	player.global_position = Vector2(150, 450)
	player.velocity = Vector2.ZERO
	player.stop_slide()
	player.is_dead = false
	player.deactivate_shield()
	player.has_magnet = false
	player.magnet_timer = 0.0
	player.play_run_animation()
	
	camera.offset = Vector2.ZERO
	shake_duration = 0.0
	
	start_screen.hide()
	game_over_screen.hide()
	$UI/HUD.show()
	
	spawn_timer.start(randf_range(1.5, 2.5))

func show_start_screen():
	game_active = false
	player.is_dead = true
	player.anim_player.play("idle")
	start_screen.show()
	game_over_screen.hide()
	$UI/HUD.hide()
	if pause_btn:
		pause_btn.hide()
	start_high_score_label.text = "HIGH SCORE: %d m" % high_score

func show_game_over_screen():
	play_sound(sound_game_over)
	game_active = false
	spawn_timer.stop()
	
	if pause_btn:
		pause_btn.hide()
	
	if int(score) > high_score:
		high_score = int(score)
		save_high_score()
		
	var random_death_msg = death_messages[randi() % death_messages.size()]
	game_over_title.text = "YOU CRASHED"
	final_score_label.text = "%s\n\nSCORE: %d m\nCOINS: %d\nHIGH SCORE: %d m" % [random_death_msg, int(score), coins, high_score]
	
	if gems > 0:
		respawn_button.text = "RESPAWN (Costs 1 Gem) [%d left]" % gems
		respawn_button.show()
	else:
		respawn_button.hide()
		
	$UI/HUD.hide()
	game_over_screen.show()

func respawn_with_gem():
	if gems <= 0:
		return
		
	gems -= 1
	
	get_tree().call_group("obstacles", "queue_free")
	game_active = true
	
	player.global_position = Vector2(150, 450)
	player.velocity = Vector2.ZERO
	player.stop_slide()
	player.is_dead = false
	player.play_run_animation()
	player.make_invulnerable(2.5)
	
	game_over_screen.hide()
	
	coins_label.text = "COINS: %d" % coins
	gems_label.text = "GEMS: %d" % gems
	$UI/HUD.show()
	
	psych_label.text = "Reality reconstructed."
	var tween = create_tween()
	psych_label.modulate.a = 1.0
	tween.tween_property(psych_label, "modulate:a", 0.0, 2.0).set_delay(1.0)
	
	spawn_timer.start(1.5)

func collect_coin():
	play_sound(sound_coin)
	coins += 1
	coins_label.text = "COINS: %d" % coins
	score += 10.0
	
	if randf() < 0.15:
		trigger_psych_message()

func collect_gem():
	play_sound(sound_gem)
	gems += 1
	gems_label.text = "GEMS: %d" % gems
	score += 50.0
	
	psych_label.text = "★ JACKPOT RESPAWN ACQUIRED ★"
	var tween = create_tween()
	psych_label.modulate.a = 1.0
	tween.tween_property(psych_label, "modulate:a", 0.0, 3.0).set_delay(1.5)

func trigger_psych_message():
	psych_label.modulate = Color.WHITE
	var msg = psych_messages[randi() % psych_messages.size()]
	psych_label.text = msg
	var tween = create_tween()
	psych_label.modulate.a = 1.0
	tween.tween_property(psych_label, "modulate:a", 0.0, 3.0).set_delay(1.5)

func _on_player_collided():
	if game_active:
		play_sound(sound_death)
		player.is_dead = true
		player.anim_player.play("idle")
		show_game_over_screen()

func _on_spawn_timer_timeout():
	if not game_active:
		return
		
	# Determine spawn:
	# 60% obstacle
	# 28% coins
	# 11% powerup (shield or magnet)
	# 1% gem (Jackpot)
	var roll = randf()
	if roll < 0.60:
		var obs = obstacle_scene.instantiate()
		obs.add_to_group("obstacles")
		add_child(obs)
		obs.position.x = 1250
		
		# Select from rock, boulder, branch, bird
		var r = randf()
		var type = "rock"
		if r < 0.35:
			type = "rock"
		elif r < 0.60:
			type = "boulder"
		elif r < 0.85:
			type = "branch"
		else:
			type = "bird"
		obs.setup_obstacle(type, game_speed)
	elif roll < 0.88:
		# Spawn row of 3 coins
		var spawn_y = 520 - 30
		var h_type = randf()
		if h_type > 0.6:
			spawn_y = 440
		elif h_type > 0.3:
			spawn_y = 350
			
		for i in range(3):
			var c = coin_scene.instantiate()
			c.add_to_group("coins")
			add_child(c)
			c.position.x = 1250 + (i * 60)
			c.setup_coin(game_speed, spawn_y)
	elif roll < 0.99:
		# Spawn a power-up (shield or magnet)
		var p = powerup_scene.instantiate()
		p.add_to_group("powerups")
		add_child(p)
		p.position.x = 1250
		var p_type = "shield" if randf() < 0.5 else "magnet"
		
		# Select a height for the powerup
		var spawn_y = 490
		var r_y = randf()
		if r_y > 0.6:
			spawn_y = 350
		elif r_y > 0.3:
			spawn_y = 440
		p.setup_powerup(p_type, game_speed, spawn_y)
	else:
		# Spawn a special respawn Gem!
		var g = gem_scene.instantiate()
		g.add_to_group("gems")
		add_child(g)
		g.position.x = 1250
		var spawn_y = 350 if randf() > 0.5 else 440
		g.setup_gem(game_speed, spawn_y)
			
	# Restart spawn timer
	var min_time = clamp(1.8 - (game_speed / MAX_SPEED), 0.7, 1.8)
	var max_time = clamp(2.8 - (game_speed / MAX_SPEED), 1.2, 2.8)
	spawn_timer.start(randf_range(min_time, max_time))

func save_high_score():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score)

func load_high_score():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_32()

func shake_camera(intensity: float, duration: float):
	shake_intensity = intensity
	shake_duration = duration

func trigger_threat_alert(msg: String):
	psych_label.text = "▲ " + msg + " ▲"
	psych_label.modulate = Color(1.0, 0.1, 0.1, 1.0)
	
	# Rapid flash/glitch effect using Tween
	var tween = create_tween()
	for i in range(6):
		tween.tween_property(psych_label, "modulate:a", 0.1, 0.05)
		tween.tween_property(psych_label, "modulate:a", 1.0, 0.05)
		
	# Keep for a bit then fade out
	tween.tween_property(psych_label, "modulate:a", 0.0, 2.0).set_delay(1.5)

# --- MUSIC PLAYER & GAME PAUSE IMPLEMENTATION ---

func load_playlist():
	playlist_paths.clear()
	playlist_names.clear()
	
	# In exported projects (especially HTML5/Web), DirAccess cannot list remapped virtual resources.
	# We use a hardcoded fallback list of your tracks to ensure music works on all platforms.
	var tracks = [
		"Heartless.mp3",
		"Maula Mere Maula.mp3",
		"Meri Kahani.mp3",
		"Mitwa.mp3",
		"আবর দখ হল  Abar dekha hole  lyrical demo.mp3"
	]
	
	for track in tracks:
		playlist_paths.append("res://musics/" + track)
		playlist_names.append(track.get_basename())
		
	print("Loaded %d music tracks into playlist." % playlist_paths.size())

func _setup_music_and_pause_ui():
	# Ensure the UI CanvasLayer processes when the game is paused
	$UI.process_mode = Node.PROCESS_MODE_ALWAYS

	# Move High Score Label down slightly to fit the Pause button above it
	high_score_label.position.y = 80.0

	# 1. GAME PAUSE BUTTON
	pause_btn = Button.new()
	pause_btn.text = "⏸ PAUSE GAME"
	pause_btn.name = "GamePauseButton"
	pause_btn.custom_minimum_size = Vector2(140, 40)
	pause_btn.position = Vector2(1152 - 172, 24) # Top right corner (above high score label at y=80)
	$UI/HUD.add_child(pause_btn)
	pause_btn.pressed.connect(_on_pause_btn_pressed)
	pause_btn.hide() # Hidden by default until start_game

	# 2. PAUSE OVERLAY
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.08, 0.09, 0.12, 0.8) # Glassy dark overlay
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.name = "PauseOverlay"
	$UI.add_child(pause_overlay)
	
	# Center container for Pause menu content
	var pause_box = VBoxContainer.new()
	pause_box.set_anchors_preset(Control.PRESET_CENTER)
	pause_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_overlay.add_child(pause_box)
	
	var pause_title = Label.new()
	pause_title.text = "GAME PAUSED"
	var title_settings = LabelSettings.new()
	title_settings.font_size = 48
	title_settings.font_color = Color(0.9, 0.3, 0.3)
	title_settings.outline_size = 8
	title_settings.outline_color = Color.BLACK
	pause_title.label_settings = title_settings
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(pause_title)
	
	var pause_sub = Label.new()
	pause_sub.text = "The simulation is currently suspended."
	var sub_settings = LabelSettings.new()
	sub_settings.font_size = 20
	sub_settings.font_color = Color(0.7, 0.75, 0.8)
	pause_sub.label_settings = sub_settings
	pause_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(pause_sub)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	pause_box.add_child(spacer)
	
	var resume_btn = Button.new()
	resume_btn.text = "RESUME RUN"
	resume_btn.custom_minimum_size = Vector2(220, 50)
	resume_btn.add_theme_font_size_override("font_size", 22)
	pause_box.add_child(resume_btn)
	resume_btn.pressed.connect(_on_resume_pressed)

	# 3. MUSIC PLAYER PANEL (Floats above overlays at the bottom center, widened to 640px to fit audio toggles)
	music_panel = PanelContainer.new()
	music_panel.name = "MusicPlayerPanel"
	music_panel.custom_minimum_size = Vector2(640, 60)
	music_panel.position = Vector2((1152 - 640) / 2.0, 648.0 - 80)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.1, 0.14, 0.85) # Dark translucent
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	style_box.content_margin_left = 16
	style_box.content_margin_right = 16
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	style_box.shadow_color = Color(0, 0, 0, 0.4)
	style_box.shadow_size = 6
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.2, 0.25, 0.35, 0.5)
	music_panel.add_theme_stylebox_override("panel", style_box)
	
	$UI.add_child(music_panel) # Direct child of UI so it stays visible on overlays
	
	var music_layout = HBoxContainer.new()
	music_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	music_panel.add_child(music_layout)
	
	var note_icon = Label.new()
	note_icon.text = "🎵 "
	var icon_settings = LabelSettings.new()
	icon_settings.font_size = 20
	note_icon.label_settings = icon_settings
	music_layout.add_child(note_icon)
	
	music_label = Label.new()
	music_label.text = "Not Playing"
	music_label.custom_minimum_size = Vector2(180, 0)
	music_label.clip_text = true
	var label_settings = LabelSettings.new()
	label_settings.font_size = 14
	label_settings.font_color = Color(0.1, 0.8, 1.0) # Cyber Cyan
	music_label.label_settings = label_settings
	music_layout.add_child(music_label)
	
	music_play_pause_btn = Button.new()
	music_play_pause_btn.text = "⏸"
	music_play_pause_btn.custom_minimum_size = Vector2(40, 40)
	music_play_pause_btn.add_theme_font_size_override("font_size", 16)
	music_layout.add_child(music_play_pause_btn)
	music_play_pause_btn.pressed.connect(_on_music_play_pause_pressed)
	
	music_next_btn = Button.new()
	music_next_btn.text = "⏭"
	music_next_btn.custom_minimum_size = Vector2(40, 40)
	music_next_btn.add_theme_font_size_override("font_size", 16)
	music_layout.add_child(music_next_btn)
	music_next_btn.pressed.connect(play_next_song)
	
	music_dropdown = OptionButton.new()
	music_dropdown.name = "MusicDropdown"
	music_dropdown.custom_minimum_size = Vector2(160, 40)
	music_dropdown.add_theme_font_size_override("font_size", 12)
	music_layout.add_child(music_dropdown)
	
	# Populate dropdown
	for i in range(playlist_names.size()):
		music_dropdown.add_item(playlist_names[i])
		
	music_dropdown.item_selected.connect(_on_music_selected)

	# Spacer between music player and volume toggles
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(8, 0)
	music_layout.add_child(spacer2)

	# SFX Mute Button
	sfx_mute_btn = Button.new()
	sfx_mute_btn.text = "🔊 SFX"
	sfx_mute_btn.custom_minimum_size = Vector2(65, 40)
	sfx_mute_btn.add_theme_font_size_override("font_size", 12)
	music_layout.add_child(sfx_mute_btn)
	sfx_mute_btn.pressed.connect(_on_sfx_mute_pressed)

	# Music Mute Button
	music_mute_btn = Button.new()
	music_mute_btn.text = "🔊 Music"
	music_mute_btn.custom_minimum_size = Vector2(75, 40)
	music_mute_btn.add_theme_font_size_override("font_size", 12)
	music_layout.add_child(music_mute_btn)
	music_mute_btn.pressed.connect(_on_music_mute_pressed)

	_update_music_hud()

func _on_pause_btn_pressed():
	if not game_active or is_game_paused:
		return
	is_game_paused = true
	get_tree().paused = true
	pause_overlay.show()

func _on_resume_pressed():
	is_game_paused = false
	get_tree().paused = false
	pause_overlay.hide()

func _on_music_play_pause_pressed():
	if bg_music_player.playing and not bg_music_player.stream_paused:
		bg_music_player.stream_paused = true
		music_play_pause_btn.text = "▶"
		music_label.modulate.a = 0.5
	else:
		bg_music_player.stream_paused = false
		if not bg_music_player.playing:
			play_song_at_index(current_song_index)
		music_play_pause_btn.text = "⏸"
		music_label.modulate.a = 1.0

func _on_music_selected(index: int):
	play_song_at_index(index)

func play_song_at_index(index: int):
	if playlist_paths.size() == 0 or index < 0 or index >= playlist_paths.size():
		return
	current_song_index = index
	var stream = load(playlist_paths[current_song_index])
	if stream:
		bg_music_player.stream = stream
		bg_music_player.stream_paused = false
		bg_music_player.volume_db = -80.0 if music_muted else 0.0
		bg_music_player.play()
		_update_music_hud()
		music_play_pause_btn.text = "⏸"
		music_label.modulate.a = 1.0

func play_next_song():
	if playlist_paths.size() == 0:
		return
	current_song_index = (current_song_index + 1) % playlist_paths.size()
	play_song_at_index(current_song_index)

func _on_bg_music_finished():
	play_next_song()

func _update_music_hud():
	if playlist_names.size() > 0 and music_label:
		music_label.text = playlist_names[current_song_index]
		if music_dropdown:
			music_dropdown.select(current_song_index)

func _on_sfx_mute_pressed():
	sfx_muted = not sfx_muted
	if sfx_muted:
		sfx_mute_btn.text = "🔇 SFX"
		sfx_mute_btn.modulate = Color(1.0, 0.4, 0.4) # Reddish mute indicator
	else:
		sfx_mute_btn.text = "🔊 SFX"
		sfx_mute_btn.modulate = Color.WHITE

func _on_music_mute_pressed():
	music_muted = not music_muted
	if music_muted:
		music_mute_btn.text = "🔇 Music"
		music_mute_btn.modulate = Color(1.0, 0.4, 0.4) # Reddish mute indicator
		bg_music_player.volume_db = -80.0
	else:
		music_mute_btn.text = "🔊 Music"
		music_mute_btn.modulate = Color.WHITE
		bg_music_player.volume_db = 0.0
