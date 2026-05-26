extends Area2D

var speed = 400.0

@onready var sprite = $Sprite2D

func _ready():
	body_entered.connect(_on_body_entered)
	# Subtle floating bobbing animation
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -8.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 8.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)

func setup_coin(current_speed: float, y_pos: float):
	speed = current_speed
	position.y = y_pos

func _process(delta):
	# Magnetic attraction logic
	var main = get_parent()
	if main and main.has_node("Player"):
		var player = main.get_node("Player")
		if player and not player.is_dead and player.has_magnet:
			var dist = global_position.distance_to(player.global_position)
			if dist < 350.0: # Attraction radius: 350px
				var pull_speed = lerp(speed * 2.5, speed * 0.5, dist / 350.0)
				var dir = (player.global_position - global_position).normalized()
				global_position += dir * pull_speed * delta
				return # Skip normal scrolling
				
	# Normal scrolling
	position.x -= speed * delta
	if position.x < -100:
		queue_free()

func _on_body_entered(body):
	if body.name == "Player":
		if get_parent().has_method("collect_coin"):
			get_parent().collect_coin()
		queue_free()
