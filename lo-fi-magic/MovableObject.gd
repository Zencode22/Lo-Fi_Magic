extends RigidBody3D

var is_grabbed: bool = false
var grabber: Node3D = null
var grab_point: Vector3 = Vector3.ZERO
var grab_distance: float = 1.5
var grab_force: float = 25.0
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
	freeze = true
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
			if not player_has_moved and (grabber.global_position.distance_to(last_player_position) > 0.1 or grabber.global_transform.basis != last_player_rotation):
				player_has_moved = true
			
			var target_position: Vector3
			
			if player_has_moved:
				var player_forward = -grabber.global_transform.basis.z

				target_position = grabber.global_position + player_forward * grab_distance

				if stay_on_ground:
					target_position.y = get_ground_height_at_position(target_position) + (object_height / 2)
				else:
					target_position.y = grabber.global_position.y + 0.5

				grab_point = target_position
			else:
				target_position = grab_point

			var direction = target_position - global_position
			var distance = direction.length()
			
			if distance > 0.01:
				var force_magnitude
				
				if distance > 1.0:
					force_magnitude = grab_force * distance * mass * 1.5
				else:
					force_magnitude = grab_force * distance * mass * 0.8
				
				var force = direction.normalized() * force_magnitude
				
				if stay_on_ground:
					force.y = 0
				
				apply_central_force(force)
				
				angular_velocity = angular_velocity.lerp(Vector3.ZERO, grab_angular_damp * delta)
				
				if stay_on_ground:
					var current_ground_height = get_ground_height_at_position(global_position)
					var height_above_ground = global_position.y - (current_ground_height + object_height / 2)
					
					if height_above_ground > 0.1:
						var downward_force = Vector3.DOWN * mass * 8.0 * height_above_ground
						apply_central_force(downward_force)
					elif height_above_ground < -0.1:
						var upward_force = Vector3.UP * mass * 4.0 * abs(height_above_ground)
						apply_central_force(upward_force)
				
				if grabber is RigidBody3D:
					var velocity_match = (grabber.linear_velocity - linear_velocity) * mass * 0.3
					if stay_on_ground:
						velocity_match.y = 0
					apply_central_force(velocity_match)
		else:
			release()

func get_ground_height_at_position(position: Vector3) -> float:
	var space_state = get_world_3d().direct_space_state
	var origin = Vector3(position.x, position.y + 10.0, position.z)
	var end = Vector3(position.x, position.y - 10.0, position.z)
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	else:
		return 0.0

func grab(by: Node3D) -> void:
	if not is_grabbed and by != null:
		var distance = global_position.distance_to(by.global_position)
		var in_proximity = distance < 2.5
		
		var can_grab = false
		if players_in_contact.has(by) or in_proximity:
			can_grab = true
		
		if can_grab:
			is_grabbed = true
			grabber = by
			freeze = false
			
			var player_forward = -by.global_transform.basis.z
			grab_point = by.global_position + player_forward * grab_distance
			
			if stay_on_ground:
				grab_point.y = get_ground_height_at_position(grab_point) + (object_height / 2)
			else:
				grab_point.y = by.global_position.y + 0.8
			
			last_player_position = by.global_position 
			last_player_rotation = by.global_transform.basis
			player_has_moved = false
			
			linear_damp = 1.5
			angular_damp = 4.0
			
			var initial_direction = (grab_point - global_position).normalized()
			if stay_on_ground:
				initial_direction.y = 0
			var initial_force = initial_direction * mass * 2.0
			apply_central_impulse(initial_force)

func release() -> void:
	if is_grabbed:
		is_grabbed = false
		grabber = null
		freeze = true
		player_has_moved = false
		linear_damp = original_linear_damp
		angular_damp = original_angular_damp

func can_be_grabbed_by(player: Node3D) -> bool:
	var distance = global_position.distance_to(player.global_position)
	var in_proximity = distance < 2.5
	
	var can_grab = false
	if not is_grabbed:
		if players_in_contact.has(player) or in_proximity:
			can_grab = true
	return can_grab

func set_stay_on_ground(should_stay: bool) -> void:
	stay_on_ground = should_stay
