extends CharacterBody2D

signal collided

const JUMP_FORCE = -650.0
const GRAVITY = 1800.0

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var anim_player = $AnimationPlayer
@onready var shield_bubble = $ShieldBubble

var is_sliding = false
var is_dead = true
var is_invulnerable = false
var is_ziplining = false
var default_collision_height = 96.0
var default_collision_y = 0.0

# Powerup & Double Jump Variables
var jump_count = 0
var has_shield = false
var has_magnet = false
var magnet_timer = 0.0

# Sound preloads
var sound_jump = preload("res://assets/audio/jump.wav")
var sound_double_jump = preload("res://assets/audio/double_jump.wav")
var sound_slide = preload("res://assets/audio/slide.wav")
var sound_shield_break = preload("res://assets/audio/shield_break.wav")

func play_sound(stream: AudioStream):
	var main = get_parent()
	if main and "sfx_muted" in main and main.sfx_muted:
		return
	var player_node = AudioStreamPlayer.new()
	add_child(player_node)
	player_node.stream = stream
	player_node.finished.connect(player_node.queue_free)
	player_node.play()

func _ready():
	anim_player.play("idle")
	shield_bubble.hide()

func _process(delta):
	if is_dead:
		return
		
	# Manage magnet timer
	if has_magnet:
		magnet_timer -= delta
		if magnet_timer <= 0.0:
			has_magnet = false
			
	# Rotate active shield bubble for a cool effect
	if has_shield:
		shield_bubble.rotation += 2.0 * delta

func _physics_process(delta):
	# If ziplining, bypass physics
	if is_ziplining:
		velocity = Vector2.ZERO
		sprite.frame = 14
		return

	# If dead, only apply gravity and move
	if is_dead:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.y = 0
		move_and_slide()
		global_position.x = 150
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
		jump_count = 0 # Reset jump count on floor

	# Handle Jump (with Double Jump check)
	if Input.is_action_just_pressed("jump") and not is_sliding:
		if is_on_floor() or jump_count < 2:
			velocity.y = JUMP_FORCE
			jump_count += 1
			anim_player.play("jump")
			if jump_count == 1:
				play_sound(sound_jump)
			else:
				play_sound(sound_double_jump)

	# Handle Slide
	if Input.is_action_pressed("slide") and is_on_floor():
		if not is_sliding:
			start_slide()
	elif is_sliding:
		if not Input.is_action_pressed("slide"):
			stop_slide()

	# Move the character
	move_and_slide()
	
	# Keep player at fixed X coordinate
	global_position.x = 150

	# Fallback run animation if landed
	if is_on_floor() and not is_sliding and anim_player.current_animation == "":
		play_run_animation()

func start_slide():
	is_sliding = true
	anim_player.play("slide")
	play_sound(sound_slide)
	# Shrink collision box and offset it downwards
	if collision_shape.shape is CapsuleShape2D:
		collision_shape.shape.height = 40.0
		collision_shape.position.y = 30.0

func stop_slide():
	is_sliding = false
	play_run_animation()
	# Restore collision box
	if collision_shape.shape is CapsuleShape2D:
		collision_shape.shape.height = default_collision_height
		collision_shape.position.y = default_collision_y

func play_run_animation():
	if not is_dead and is_on_floor():
		anim_player.play("run")

func activate_shield():
	has_shield = true
	shield_bubble.show()

func deactivate_shield():
	has_shield = false
	shield_bubble.hide()

func break_shield():
	deactivate_shield()
	play_sound(sound_shield_break)
	make_invulnerable(1.2) # Temporary invulnerability so they don't immediately die
	
	# Shake camera
	var main = get_parent()
	if main.has_method("shake_camera"):
		main.shake_camera(12.0, 0.4)
		main.psych_label.text = "SHIELD BROKEN"
		main.psych_label.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(main.psych_label, "modulate:a", 0.0, 1.5).set_delay(0.5)

func activate_magnet(duration: float):
	has_magnet = true
	magnet_timer = duration

func make_invulnerable(duration: float):
	is_invulnerable = true
	# Flashing effect
	var flash_loops = int(duration / 0.2)
	var tween = create_tween().set_loops(flash_loops)
	tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	
	await get_tree().create_timer(duration).timeout
	is_invulnerable = false
	sprite.modulate.a = 1.0

func die():
	collided.emit()
