extends Area2D

var speed = 400.0
var type = "rock"

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	body_entered.connect(_on_body_entered)

func setup_obstacle(obstacle_type: String, current_speed: float):
	type = obstacle_type
	speed = current_speed
	
	if not is_inside_tree():
		await ready
		
	if type == "rock":
		sprite.texture = load("res://assets/rock.png")
		var shape = RectangleShape2D.new()
		shape.size = Vector2(48, 48)
		collision_shape.shape = shape
		collision_shape.position = Vector2(0, 8)
		position.y = 520 - 24
	elif type == "branch":
		sprite.texture = load("res://assets/branch.png")
		var shape = RectangleShape2D.new()
		shape.size = Vector2(32, 80)
		collision_shape.shape = shape
		collision_shape.position = Vector2(0, 0)
		position.y = 420
	elif type == "boulder":
		sprite.texture = load("res://assets/boulder.png")
		var shape = RectangleShape2D.new()
		shape.size = Vector2(48, 48)
		collision_shape.shape = shape
		collision_shape.position = Vector2(0, 8)
		position.y = 520 - 24
	elif type == "bird":
		sprite.texture = load("res://assets/bird.png")
		var shape = RectangleShape2D.new()
		shape.size = Vector2(48, 32)
		collision_shape.shape = shape
		collision_shape.position = Vector2(0, 0)
		position.y = randf_range(340, 420) # Random flight height
		# Increase bird speed (flies faster than running pace)
		speed = current_speed * 1.25
		
		# Wing flapping animation via scale tweening
		var tween = create_tween().set_loops()
		tween.tween_property(sprite, "scale:y", 0.35, 0.15)
		tween.tween_property(sprite, "scale:y", 0.65, 0.15)

func _process(delta):
	# Rolling effect for the boulder
	if type == "boulder":
		sprite.rotation -= (speed * delta) * 0.04
		
	position.x -= speed * delta
	if position.x < -100:
		queue_free()

func _on_body_entered(body):
	if body.name == "Player":
		if body.has_shield:
			body.break_shield()
			queue_free()
		elif not body.is_invulnerable:
			if body.has_method("die"):
				body.die()
			else:
				body.collided.emit()
