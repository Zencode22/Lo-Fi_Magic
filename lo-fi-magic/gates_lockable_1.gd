extends Node3D

@onready var animation_player = $AnimationPlayer

func _ready() -> void:
	TokenTracker.all_tokens_collected.connect(_on_all_tokens_collected)
	
func _process(_delta: float) -> void:
	pass

func _on_all_tokens_collected(token_set: String) -> void:
	if token_set == "set_1" and animation_player:
		animation_player.play("Opening")
