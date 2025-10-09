extends RigidBody3D

# Grab variables
var is_grabbed: bool = false
var grabber: Node3D = null
var grab_point: Vector3 = Vector3.ZERO
var grab_distance: float = 2.0
var grab_force: float = 15.0
var grab_angular_damp: float = 5.0

# Original values to restore when released
var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	freeze = true
	original_linear_damp = linear_damp
	original_angular_damp = angular_damp

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Physics process for handling grab mechanics
func _physics_process(delta: float) -> void:
	if is_grabbed and grabber:
		if grabber.grabbed_object == self and Input.is_action_pressed("grab"):
			var target_position = grabber.global_position + grabber.global_transform.basis.z * -grab_distance
		
			# Calculate the direction and distance to the target
			var direction = target_position - global_position
			var distance = direction.length()
		
			# Apply force to move the object toward the grab point
			if distance > 0.1:
				var force = direction.normalized() * grab_force * distance
				apply_central_force(force)
				
				# Reduce angular velocity for more stable grabbing
				angular_velocity = angular_velocity.lerp(Vector3.ZERO, grab_angular_damp * delta)
		else:
			# If grab button is not pressed, release the object
			release()

# Method to grab the object
func grab(by: Node3D) -> void:
	if not is_grabbed:
		is_grabbed = true
		grabber = by
		
		# Unfreeze the object when grabbed
		freeze = false
		
		# Store the initial grab point relative to the object
		grab_point = global_position
		
		# Reduce damping while grabbed for more responsive movement
		linear_damp = 0.5
		angular_damp = 2.0
		
		print("Object grabbed: ", name)

# Method to release the object
func release() -> void:
	if is_grabbed:
		is_grabbed = false
		grabber = null
		
		# Restore original damping values
		linear_damp = original_linear_damp
		angular_damp = original_angular_damp
		
		print("Object released: ", name)
