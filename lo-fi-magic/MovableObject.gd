extends RigidBody3D

var is_grabbed: bool = false
var grabber: Node3D = null
var grab_point: Vector3 = Vector3.ZERO
var grab_distance: float = 1.0
var grab_force: float = 15.0
var grab_angular_damp: float = 5.0

var players_in_contact: Array[Node3D] = []

var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0

func _ready() -> void:
	sleeping = false
	freeze = true
	original_linear_damp = linear_damp
	original_angular_damp = angular_damp
	
	# Nuclear option - collide with everything
	collision_layer = 0xFFFFFFFF
	collision_mask = 0xFFFFFFFF
	
	add_to_group("movable")

func _physics_process(delta: float) -> void:
	if is_grabbed and grabber:
		if grabber.grabbed_object == self and Input.is_action_pressed("grab"):
			# Calculate target position in front of the player at chest height
			var camera = grabber.get_node_or_null("TwistPivot/PitchPivot/Camera3D")
			var target_position
			
			if camera:
				# Use camera forward direction, but keep it at a reasonable height
				var camera_forward = -camera.global_transform.basis.z
				target_position = grabber.global_position + camera_forward * grab_distance
				# Keep the object at a consistent height (chest level)
				target_position.y = grabber.global_position.y + 0.5
			else:
				# Fallback to player forward direction
				target_position = grabber.global_position + grabber.global_transform.basis.z * -grab_distance
				target_position.y = grabber.global_position.y + 0.5
			
			var direction = target_position - global_position
			var distance = direction.length()
			
			if distance > 0.1:
				# Use different force calculations based on distance
				var force_magnitude
				if distance > 1.0:
					# Far away - use stronger force
					force_magnitude = grab_force * distance * mass * 2.0
				else:
					# Close - use gentler force for fine control
					force_magnitude = grab_force * distance * mass * 0.5
				
				var force = direction.normalized() * force_magnitude
				apply_central_force(force)
				
				# Damp angular velocity more smoothly
				angular_velocity = angular_velocity.lerp(Vector3.ZERO, grab_angular_damp * delta)
				
				# Counteract gravity based on distance - fixed ternary
				var gravity_factor = 1.0 - clamp(distance / grab_distance, 0.0, 1.0)
				var anti_gravity = Vector3.UP * mass * 4.0 * gravity_factor
				apply_central_force(anti_gravity)
		else:
			release()

func grab(by: Node3D) -> void:
	if not is_grabbed and by != null:
		# TEMPORARY: Use proximity instead of contact for testing
		var distance = global_position.distance_to(by.global_position)
		var in_proximity = distance < 2.0
		
		# Fixed boolean expression - no more ternary operator issues
		var can_grab = false
		if players_in_contact.has(by) or in_proximity:
			can_grab = true
		
		if can_grab:
			is_grabbed = true
			grabber = by
			freeze = false
			grab_point = global_position
			linear_damp = 0.5
			angular_damp = 2.0

func release() -> void:
	if is_grabbed:
		is_grabbed = false
		grabber = null
		freeze = true
		linear_damp = original_linear_damp
		angular_damp = original_angular_damp
# Add a method to check if a player can grab this object
func can_be_grabbed_by(player: Node3D) -> bool:
	# TEMPORARY: Use proximity instead of contact for testing
	var distance = global_position.distance_to(player.global_position)
	var in_proximity = distance < 2.0
	
	# Fixed boolean expression - no more ternary operator issues
	var can_grab = false
	if not is_grabbed:
		if players_in_contact.has(player) or in_proximity:
			can_grab = true
	return can_grab
