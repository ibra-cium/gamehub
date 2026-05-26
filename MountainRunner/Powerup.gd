extends Area2D

var speed = 400.0
var type = "shield" # "shield" or "magnet"

@onready var sprite = $Sprite2D

func _ready():
	body_entered.connect(_on_body_entered)
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -6.0, 0.45).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 6.0, 0.45).as_relative().set_trans(Tween.TRANS_SINE)

func setup_powerup(powerup_type: String, current_speed: float, y_pos: float):
	type = powerup_type
	speed = current_speed
	position.y = y_pos
	
	if not is_inside_tree():
		await ready
		
	if type == "shield":
		sprite.texture = load("res://assets/powerup_shield.png")
	elif type == "magnet":
		sprite.texture = load("res://assets/powerup_magnet.png")

func _process(delta):
	position.x -= speed * delta
	if position.x < -100:
		queue_free()

func _on_body_entered(body):
	if body.name == "Player":
		if type == "shield" and body.has_method("activate_shield"):
			body.activate_shield()
		elif type == "magnet" and body.has_method("activate_magnet"):
			body.activate_magnet(10.0) # Active for 10 seconds
			
		var main = get_parent()
		if main.has_method("play_sound") and "sound_powerup" in main:
			main.play_sound(main.sound_powerup)
		if main.has_method("trigger_psych_message"):
			main.psych_label.text = "POWERUP ACQUIRED: " + type.to_upper()
			main.psych_label.modulate.a = 1.0
			var tween = create_tween()
			tween.tween_property(main.psych_label, "modulate:a", 0.0, 2.0).set_delay(1.0)
			
		queue_free()
