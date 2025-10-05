extends RigidBody3D

# Grab variables
var is_grabbed: bool = false
var grabber: Node3D = null
var grab_point: Vector3 = Vector3.ZERO
var grab_distance: float = 2.0
var grab_force: float = 10.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Physics process for handling grab mechanics
func _physics_process(delta: float) -> void:
	if is_grabbed and grabber:
		# Only move if the grabber is actually holding this object
		if grabber.grabbed_object == self and Input.is_action_pressed("grab"):
			# Calculate the target position for the object
			var target_position = grabber.global_position + grabber.global_transform.basis.z * -grab_distance
		
# Calculate the direction and distance to the target
			var direction = target_position - global_position
			var distance = direction.length()
		
# Apply force to move the object toward the grab point
			if distance > 0.1:
				var force = direction.normalized() * grab_force * distance
				apply_central_force(force)
			elif not Input.is_action_pressed("grab"):
				release()	

# Method to grab the object
func grab(by: Node3D) -> void:
	if not is_grabbed:
		is_grabbed = true
		grabber = by
		
		# Store the initial grab point relative to the object
		grab_point = global_position
		
		# Reduce linear damping while grabbed for more responsive movement
		linear_damp = 0.5

# Method to release the object
func release() -> void:
	if is_grabbed:
		is_grabbed = false
		grabber = null
		
		# Restore original damping
		linear_damp = 0.0
		print("Object released: ", name)
