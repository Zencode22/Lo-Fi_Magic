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

func _ready() -> void:
	sleeping = false
	freeze = true  # Start frozen by default
	can_sleep = false
	original_linear_damp = linear_damp
	original_angular_damp = angular_damp
	
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
		if grabber.grabbed_object == self and Input.is_action_pressed("grab"):
			if freeze:
				freeze = false
			
			var player_moved = false
			var player_rotated = false
			
			if last_player_position.distance_to(grabber.global_position) > 0.01:
				player_moved = true
				last_player_position = grabber.global_position
			
			if last_player_rotation != grabber.global_transform.basis:
				player_rotated = true
				last_player_rotation = grabber.global_transform.basis
			
			if player_moved or player_rotated:
				var player_forward = -grabber.global_transform.basis.z
				var target_position = grabber.global_position + player_forward * grab_distance

				if stay_on_ground:
					target_position.y = get_ground_height_at_position(target_position) + (object_height / 2)
				else:
					target_position.y = grabber.global_position.y + 0.5

				grab_point = target_position

				var direction = grab_point - global_position
				var distance = direction.length()
				
				if distance > 0.01:
					var force_magnitude
					
					if distance > 1.0:
						force_magnitude = grab_force * distance * mass * 2.0
					else:
						force_magnitude = grab_force * distance * mass * 1.2
					
					var force = direction.normalized() * force_magnitude
					
					if stay_on_ground:
						force.y = 0
					
					apply_central_force(force)

					if grabber is RigidBody3D:
						var velocity_match = (grabber.linear_velocity - linear_velocity) * mass * 0.5
						if stay_on_ground:
							velocity_match.y = 0
						apply_central_force(velocity_match)
			
			angular_velocity = angular_velocity.lerp(Vector3.ZERO, grab_angular_damp * delta)
			
			if stay_on_ground:
				var current_ground_height = get_ground_height_at_position(global_position)
				var height_above_ground = global_position.y - (current_ground_height + object_height / 2)
				
				if height_above_ground > 0.1:
					var downward_force = Vector3.DOWN * mass * 12.0 * height_above_ground
					apply_central_force(downward_force)
				elif height_above_ground < -0.1:
					var upward_force = Vector3.UP * mass * 6.0 * abs(height_above_ground)
					apply_central_force(upward_force)
		else:
			release()

func grab(by: Node3D) -> void:
	if not is_grabbed and by != null:
		var distance = global_position.distance_to(by.global_position)
		var in_proximity = distance < 1.5
		
		var can_grab = false
		if players_in_contact.has(by) or in_proximity:
			can_grab = true
		
		if can_grab:
			is_grabbed = true
			grabber = by
			freeze = false  # Unfreeze when grabbed
			can_sleep = false
			
			last_player_position = by.global_position
			last_player_rotation = by.global_transform.basis
			
			var player_forward = -by.global_transform.basis.z
			grab_point = by.global_position + player_forward * grab_distance
			
			if stay_on_ground:
				grab_point.y = get_ground_height_at_position(grab_point) + (object_height / 2)
			else:
				grab_point.y = by.global_position.y + 0.8
			
			linear_damp = 2.0
			angular_damp = 6.0
			
			var initial_direction = (grab_point - global_position).normalized()
			if stay_on_ground:
				initial_direction.y = 0
			var initial_force = initial_direction * mass * 15.0
			apply_central_impulse(initial_force)

func can_be_grabbed_by(player: Node3D) -> bool:
	var distance = global_position.distance_to(player.global_position)
	var in_proximity = distance < 1.5
	
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
		freeze = true  # Freeze immediately when released
		can_sleep = true
		player_has_moved = false
		linear_damp = original_linear_damp
		angular_damp = original_angular_damp

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
