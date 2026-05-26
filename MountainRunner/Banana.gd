extends Area2D

var speed = 400.0

@onready var sprite = $Sprite2D

func _ready():
	body_entered.connect(_on_body_entered)
	# Subtle floating bobbing animation
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -8.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 8.0, 0.4).as_relative().set_trans(Tween.TRANS_SINE)

func setup_banana(current_speed: float, y_pos: float):
	speed = current_speed
	position.y = y_pos

func _process(delta):
	position.x -= speed * delta
	if position.x < -100:
		queue_free()

func _on_body_entered(body):
	if body.name == "Player":
		if get_parent().has_method("collect_banana"):
			get_parent().collect_banana()
		queue_free()
