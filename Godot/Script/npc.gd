extends RigidBody3D

@export_group("Idle Anim")
@export var idle_animation_name: String = "Idle"
@export var animation_library: String = "PlayerAnims"
@export_group("Appearance")
@export var HeadTex: StandardMaterial3D
@export var BodyTex: StandardMaterial3D

@onready var AP: AnimationPlayer = $NPC_Character/AnimationPlayer
@onready var HeadMesh: MeshInstance3D = $NPC_Character/Armature_TempChar/Skeleton3D/Temp_Head
@onready var BodyMesh: MeshInstance3D = $NPC_Character/Armature_TempChar/Skeleton3D/Temp_Body

func _ready() -> void:
	if HeadTex != null:
		HeadMesh.set_surface_override_material(0, HeadTex)
	if BodyTex != null:
		BodyMesh.set_surface_override_material(0, BodyTex)
	
	play_idle_animation()
	
func play_idle_animation() -> void:
	if AP.has_animation(idle_animation_name):
		AP.play(idle_animation_name)
	else:
		var full_path = animation_library + "/" + idle_animation_name
		if AP.has_animation(full_path):
			AP.play(full_path)
		else:
			var common_names = ["Idle", "idle", "Idle1", "Idle2", "Idle3"]
			for anim_name in common_names:
				if AP.has_animation(name):
					AP.play(name)
					return
			
			var animations = AP.get_animation_list()
			if animations.size() > 0:
				AP.play(animations[0])

func _process(_delta: float) -> void:
	if not AP.is_playing():
		play_idle_animation()
	
func Play_Anim(AnimPathName: String) -> void:
	if AP.has_animation(AnimPathName):
		AP.play(AnimPathName)
