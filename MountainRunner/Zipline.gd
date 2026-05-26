extends Node2D

var speed = 400.0
var cable_length = 700.0
var cable_start_y = 310.0
var cable_end_y = 470.0

@onready var line = $Line2D
@onready var handle = $Handle
@onready var handle_area = $Handle/Area2D

var attached_player = null
var progress = 0.0
var sliding = false

func _ready():
	handle_area.body_entered.connect(_on_handle_body_entered)
	
	# Draw the cable line dynamically
	line.clear_points()
	line.add_point(Vector2(0, cable_start_y))
	line.add_point(Vector2(cable_length, cable_end_y))
	handle.position = Vector2(0, cable_start_y)

func setup_zipline(current_speed: float):
	speed = current_speed
	position.y = 0

func _process(delta):
	if sliding:
		# Slide the handle along the cable
		progress += (speed * 0.9 * delta) / cable_length
		if progress >= 1.0:
			release_player()
		else:
			var current_y = lerp(cable_start_y, cable_end_y, progress)
			handle.position = Vector2(progress * cable_length, current_y)
			if attached_player:
				# Position player below the handle (hanging)
				attached_player.global_position = handle.global_position + Vector2(0, 50)
				
	# Move the whole zipline node leftward
	position.x -= speed * delta
	
	# Free when the entire node goes off screen left (including platform)
	if position.x < -cable_length - 500:
		queue_free()

func _on_handle_body_entered(body):
	if body.name == "Player" and not sliding and not body.is_dead and not body.is_ziplining:
		attached_player = body
		attached_player.is_ziplining = true
		attached_player.anim_player.play("idle")
		attached_player.sprite.frame = 14 # Arms up hanging frame
		sliding = true
		
		# Notify Main that background transition is starting
		var main = get_parent()
		if main.has_method("start_zipline_transition"):
			main.start_zipline_transition()

func release_player():
	sliding = false
	if attached_player:
		attached_player.is_ziplining = false
		attached_player.velocity = Vector2(speed, -250) # Give them a tiny leap forward!
		attached_player.play_run_animation()
		attached_player = null
	
	# Notify Main that transition is complete
	var main = get_parent()
	if main.has_method("complete_zipline_transition"):
		main.complete_zipline_transition()
