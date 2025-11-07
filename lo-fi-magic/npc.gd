extends RigidBody3D

@export_group("Idle Anim")
@export_enum("PlayerAnims/Idle", "NPC_Anims/Idle2", "NPC_Anims/Idle3", "NPC_Anims/Idle4", "NPC_Anims/Idle5", "NPC_Anims/Idle6") var IdleAnim_Name: String = "Idle"
#@export var IdleAnim: String
@export_group("Appearance")
@export var HeadTex: StandardMaterial3D
@export var BodyTex: StandardMaterial3D


@onready var AP: AnimationPlayer = $NPC_Character/AnimationPlayer
@onready var HeadMesh: MeshInstance3D = $NPC_Character/Armature_TempChar/Skeleton3D/Temp_Head
@onready var BodyMesh: MeshInstance3D = $NPC_Character/Armature_TempChar/Skeleton3D/Temp_Body

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if (HeadTex != null):
		HeadMesh.set_surface_override_material(0, HeadTex)
	if (BodyTex != null):
		BodyMesh.set_surface_override_material(0, BodyTex)
	AP.play(IdleAnim_Name)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (!AP.is_playing()):
		AP.play(IdleAnim_Name)
	pass
	
func Play_Anim(AnimPathName: String) -> void:
	AP.Play(AnimPathName)
