extends RigidBody3D

var is_grabbed: bool = false
var grabber: Node3D = null
var local_grab_offset: Vector3 = Vector3.ZERO

var players_in_contact: Array[Node3D] = []

var previous_position: Vector3
var movement_threshold := 0.02
var stop_threshold := 0.015
var is_drag_sound_playing := false

@onready var drag_emitter = $FmodDragEmitter3D

# Variables for ground tracking
var ground_y: float = 0.0
var has_ground: bool = false
var ground_check_distance: float = 2.0

# FIXED: Simple position locking
var locked_position: Vector3
var position_lock_strength: float = 20.0

func _ready() -> void:
	sleeping = false
	freeze = true
	can_sleep = false
	
	collision_layer = 0xFFFFFFFF
	collision_mask = 0xFFFFFFFF
	previous_position = global_position
	add_to_group("movable")

func _physics_process(delta: float) -> void:
	# Check ground position
	check_ground_position()
	
	if is_grabbed and grabber:
		if grabber.grabbed_object == self:
			if freeze:
				freeze = false
			
			# Calculate target position based on player movement
			var current_player_basis = grabber.global_transform.basis
			var target_position = grabber.global_position + (current_player_basis * local_grab_offset)
			
			# FIXED: Simple ground offset - always maintain 5cm above ground
			if has_ground:
				target_position.y = ground_y + 0.05
			
			# FIXED: Use forces instead of direct position for smoother physics interaction
			var direction = (target_position - global_position).normalized()
			var distance = global_position.distance_to(target_position)
			
			# Strong force to pull toward target, but allows physics to handle collisions
			var pull_force = direction * distance * mass * position_lock_strength
			apply_central_force(pull_force)
			
			# FIXED: Dampen lateral movement when close to target to prevent oscillation
			if distance < 0.1:
				var horizontal_vel = Vector3(linear_velocity.x, 0, linear_velocity.z)
				var damping_force = -horizontal_vel * mass * 5.0
				apply_central_force(damping_force)
			
			# FIXED: Keep object on ground with constant slight downward force
			if has_ground:
				# Apply just enough downward force to maintain contact
				if global_position.y > ground_y + 0.06:
					apply_central_force(Vector3.DOWN * mass * 10.0 * delta)
				elif global_position.y < ground_y + 0.04:
					# Push up slightly if sinking
					apply_central_force(Vector3.UP * mass * 5.0 * delta)
			
		else:
			release()
	
	_handle_drag_audio(delta)

# Function to check and store ground position
func check_ground_position() -> void:
	var space_state = get_world_3d().direct_space_state
	
	# Cast ray downward from slightly above the object
	var ray_origin = global_position + Vector3.UP * 0.5
	var ray_end = ray_origin + Vector3.DOWN * ground_check_distance
	
	var ray_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	ray_query.exclude = [self, grabber] if grabber else [self]
	ray_query.collision_mask = 0xFFFFFFFF
	
	var ray_result = space_state.intersect_ray(ray_query)
	
	if not ray_result.is_empty():
		has_ground = true
		ground_y = ray_result.position.y
	else:
		has_ground = false

func grab(by: Node3D) -> void:
	if not is_grabbed and by != null:
		var can_grab = players_in_contact.has(by) or global_position.distance_to(by.global_position) < 2.0
		
		if can_grab:
			is_grabbed = true
			grabber = by
			freeze = false
			can_sleep = false
			
			# Check ground immediately when grabbed
			check_ground_position()
			
			var initial_player_basis = by.global_transform.basis
			var world_offset = global_position - by.global_position
			local_grab_offset = initial_player_basis.inverse() * world_offset
			
			# Keep offset horizontal only (don't lift object)
			local_grab_offset.y = 0
			
			var grab_distance = 1.5
			local_grab_offset = local_grab_offset.normalized() * grab_distance
			
			# FIXED: Zero out velocity on grab for stable start
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO

func can_be_grabbed_by(player: Node3D) -> bool:
	var distance = global_position.distance_to(player.global_position)
	return not is_grabbed and (players_in_contact.has(player) or distance < 2.0)

func release() -> void:
	if is_grabbed:
		is_grabbed = false
		grabber = null
		freeze = true
		can_sleep = true
		local_grab_offset = Vector3.ZERO
		if is_drag_sound_playing:
			drag_emitter.stop()
			is_drag_sound_playing = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if not players_in_contact.has(body):
			players_in_contact.append(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		if players_in_contact.has(body):
			players_in_contact.erase(body)
			
func _handle_drag_audio(delta: float) -> void:
	var displacement = global_position.distance_to(previous_position)
	var speed = displacement / delta
	
	previous_position = global_position
	
	if is_grabbed and speed > movement_threshold:
		if not is_drag_sound_playing:
			drag_emitter.play()
			is_drag_sound_playing = true
	
	elif not is_grabbed or speed < stop_threshold:
		if is_drag_sound_playing:
			drag_emitter.stop()
			is_drag_sound_playing = false
