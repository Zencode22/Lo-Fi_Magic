extends RigidBody3D

var is_grabbed: bool = false
var grabber: Node3D = null
var grab_point: Vector3 = Vector3.ZERO
var grab_distance: float = 1.5
var grab_force: float = 80.0
var grab_angular_damp: float = 8.0

var players_in_contact: Array[Node3D] = []

var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0

var player_has_moved: bool = false
var last_player_position: Vector3 = Vector3.ZERO
var last_player_rotation: Basis = Basis.IDENTITY

var ground_height: float = 0.0
var object_height: float = 1.0
var stay_on_ground: bool = true

var local_grab_offset: Vector3 = Vector3.ZERO
var initial_player_basis: Basis = Basis.IDENTITY

var initial_grab_height: float = 0.0
var locked_vertical_position: float = 0.0
var is_height_locked: bool = false

var gravity: float = 9.8

func _ready() -> void:
	sleeping = false
	freeze = true
	can_sleep = false
	original_linear_damp = linear_damp
	original_angular_damp = angular_damp

	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	
	collision_layer = 0xFFFFFFFF
	collision_mask = 0xFFFFFFFF
	
	add_to_group("movable")
	calculate_object_height()

func calculate_object_height() -> void:
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is BoxShape3D:
			object_height = collision_shape.shape.size.y
		elif collision_shape.shape is SphereShape3D:
			object_height = collision_shape.shape.radius * 2
		elif collision_shape.shape is CapsuleShape3D:
			object_height = collision_shape.shape.height
		else:
			object_height = 1.0

func _physics_process(delta: float) -> void:
	if is_grabbed and grabber:
		if grabber.grabbed_object == self:
			if freeze:
				freeze = false

			apply_central_force(Vector3(0, -gravity * mass * 1.5, 0))

			var current_player_basis = grabber.global_transform.basis
			var desired_position = grabber.global_position + (current_player_basis * local_grab_offset)
			
			desired_position.y = global_position.y

			var position_diff = desired_position - global_position
			
			var distance_threshold = 0.2

			var target_speed = 8.0
			var max_distance = 3.0

			var distance = position_diff.length()
			var distance_factor = clamp(distance / max_distance, 0.1, 1.0)

			var player_to_object = (global_position - grabber.global_position).normalized()
			var player_forward = grabber.global_transform.basis.z
			var is_pushing = player_to_object.dot(player_forward) > 0.3
			
			var base_force_multiplier = 18.0
			var push_boost_multiplier = 5.0

			var current_force_multiplier = base_force_multiplier
			if is_pushing:
				current_force_multiplier = base_force_multiplier * push_boost_multiplier
				angular_damp = 4.0
			else:
				angular_damp = 6.0
			
			var force_magnitude = target_speed * mass * distance_factor * current_force_multiplier

			if distance > distance_threshold:
				var force_direction = position_diff.normalized()
				var force = force_direction * force_magnitude
				apply_central_force(force)

				if is_pushing:
					apply_central_force(Vector3(0, mass * 3.0, 0))

					if linear_velocity.length() < target_speed * 0.3:
						var extra_boost = force_direction * mass * 8.0
						apply_central_force(extra_boost)
			else:
				var damping_force = -linear_velocity * mass * 8.0
				apply_central_force(damping_force)

			linear_velocity.y = clamp(linear_velocity.y, -3.0, 1.0)

			angular_velocity = angular_velocity.lerp(Vector3.ZERO, 15.0 * delta)

			last_player_position = grabber.global_position
		else:
			release()

func grab(by: Node3D) -> void:
	if not is_grabbed and by != null:
		var distance = global_position.distance_to(by.global_position)
		var in_proximity = distance < 2.0
		var can_grab = false
		
		if players_in_contact.has(by) or in_proximity:
			can_grab = true
		
		if can_grab:
			is_grabbed = true
			grabber = by
			freeze = false
			can_sleep = false

			initial_player_basis = by.global_transform.basis
			last_player_position = by.global_position

			initial_grab_height = global_position.y

			var world_offset = global_position - by.global_position
			local_grab_offset = initial_player_basis.inverse() * world_offset

			grab_point = global_position

			linear_damp = 0.5
			angular_damp = 6.0

func can_be_grabbed_by(player: Node3D) -> bool:
	if player is RigidBody3D:
		if abs(player.linear_velocity.y) > 0.5:
			return false
	
	var distance = global_position.distance_to(player.global_position)
	var in_proximity = distance < 2.0
	var can_grab = false
	
	if not is_grabbed:
		if players_in_contact.has(player) or in_proximity:
			can_grab = true
	return can_grab

func get_ground_height_at_position(_pos: Vector3) -> float:
	var space_state = get_world_3d().direct_space_state
	var origin = Vector3(_pos.x, _pos.y + 10.0, _pos.z)
	var end = Vector3(_pos.x, _pos.y - 10.0, _pos.z)
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	else:
		return _pos.y 

func release() -> void:
	if is_grabbed:
		is_grabbed = false
		grabber = null
		freeze = true
		can_sleep = true
		player_has_moved = false
		linear_damp = original_linear_damp
		angular_damp = original_angular_damp
		last_player_position = Vector3.ZERO
		last_player_rotation = Basis.IDENTITY
		grab_point = Vector3.ZERO
		local_grab_offset = Vector3.ZERO
		initial_player_basis = Basis.IDENTITY
		initial_grab_height = 0.0

func set_stay_on_ground(should_stay: bool) -> void:
	stay_on_ground = should_stay

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if not players_in_contact.has(body):
			players_in_contact.append(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		if players_in_contact.has(body):
			players_in_contact.erase(body)
