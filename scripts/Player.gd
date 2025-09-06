# player.gd
extends CharacterBody3D

@export var cam_distance : float = 4.0
@export var cam_height   : float = 1.6
@export var cam_smooth   : float = 0.1   # lower = smoother

func _process(delta: float) -> void:
	var desired_pos = global_transform.origin
	desired_pos.y += cam_height

	var cam_target = desired_pos - cam.global_transform.basis.z * cam_distance
	cam.global_transform.origin = cam.global_transform.origin.lerp(cam_target, cam_smooth)
	cam.look_at(desired_pos, Vector3.UP)

# -- TUNABLE PARAMETERS -------------------------------------------------
@export_range(0, 20, 0.1) var speed : float = 8.0
@export_range(0, 10, 0.1) var jump_impulse : float = 4.5
@export_range(0, 30, 0.1) var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

# -- NODE REFERENCES ----------------------------------------------------
@onready var cam   : Camera3D               = $Camera3D
@onready var ray   : RayCast3D              = $RayCast3D
@onready var sfx   : AudioStreamPlayer3D    = $AudioStreamPlayer3D

# -----------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	func _handle_interaction() -> void:
	# Fire when the player presses the "interact" key
	if Input.is_action_just_pressed("interact"):
		if ray.is_colliding():
			var target = ray.get_collider()
			# We expect the target to implement a `collect_sound(player)` method
			if target.has_method("collect_sound"):
				target.collect_sound(self)
				# Optional feedback sound
				sfx.stream = preload("res://assets/audio/pickup.wav")
				sfx.play()
	_handle_interaction()

# -----------------------------------------------------------------------
func _handle_movement(delta: float) -> void:
	var input_dir = Vector3.ZERO

	# Gather input from the four movement actions
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.z = Input.get_action_strength("move_back")  - Input.get_action_strength("move_forward")
	input_dir = input_dir.normalized()

	# Transform local direction to global space (relative to camera yaw)
	var cam_yaw = cam.global_transform.basis.get_euler().y
	var direction = Vector3(
		input_dir.x * cos(cam_yaw) - input_dir.z * sin(cam_yaw),
		0,
		input_dir.x * sin(cam_yaw) + input_dir.z * cos(cam_yaw)
	)

	# Apply horizontal velocity
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	# Jump handling
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_impulse
		sfx.stream = preload("res://assets/audio/jump.wav")   # optional
		sfx.play()

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Clamp small residual fall velocities
		velocity.y = min(velocity.y, 0)

	# Move the character
	move_and_slide()
