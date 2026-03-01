extends Node3D

signal music_started
signal music_stopped
signal layer_activated(layer_name: String, value: float)

@export var background_music_event: String = "event:/Music/BackgroundLoop"
@export var auto_play: bool = true

var is_playing: bool = false
var current_volume: float = 1.0
var layers: Dictionary = {}

func _ready() -> void:
	if auto_play:
		play_background_music()

# ============================================================================
# PLACEHOLDER VERSION - No FMOD functionality
# When you have FMOD music ready, replace this entire file with:
# ============================================================================
#
# extends Node3D
#
# signal music_started
# signal music_stopped
# signal layer_activated(layer_name: String, value: float)
#
# @export var background_music_event: String = "event:/Music/BackgroundLoop"
# @export var auto_play: bool = true
#
# var is_playing: bool = false
# var current_volume: float = 1.0
# var layers: Dictionary = {}
#
# func _ready() -> void:
#     if auto_play:
#         play_background_music()
#
# func play_background_music(event_path: String = background_music_event) -> void:
#     if not has_node("FmodEventEmitter3D"):
#         create_music_emitter()
#     
#     var emitter = $FmodEventEmitter3D
#     if emitter:
#         # Make sure to set the event path before playing
#         if emitter.has_method("set_event_name"):
#             emitter.set_event_name(event_path)
#         elif "event_name" in emitter:
#             emitter.event_name = event_path
#         
#         emitter.play()
#         is_playing = true
#         music_started.emit()
#
# func stop_music() -> void:
#     if has_node("FmodEventEmitter3D"):
#         $FmodEventEmitter3D.stop()
#         is_playing = false
#         music_stopped.emit()
#
# func set_parameter(parameter_name: String, value: float) -> void:
#     if has_node("FmodEventEmitter3D"):
#         var emitter = $FmodEventEmitter3D
#         if emitter.has_method("set_parameter"):
#             emitter.set_parameter(parameter_name, value)
#         
#         if parameter_name.begins_with("Layer_"):
#             layers[parameter_name] = value
#             layer_activated.emit(parameter_name, value)
#
# func activate_layer(parameter_name: String, value: float = 1.0) -> void:
#     set_parameter(parameter_name, value)
#
# func deactivate_layer(parameter_name: String) -> void:
#     set_parameter(parameter_name, 0.0)
#
# func set_master_volume(value: float) -> void:
#     current_volume = clamp(value, 0.0, 1.0)
#     set_parameter("MasterVolume", current_volume)
#
# func reset_all_layers() -> void:
#     for layer in layers.keys():
#         set_parameter(layer, 0.0)
#     layers.clear()
#
# func create_music_emitter() -> void:
#     var emitter = FmodEventEmitter3D.new()
#     emitter.name = "FmodEventEmitter3D"
#     add_child(emitter)
#
# func is_layer_active(layer_parameter: String) -> bool:
#     return layers.get(layer_parameter, 0.0) > 0.0
#
# func get_layer_value(layer_parameter: String) -> float:
#     return layers.get(layer_parameter, 0.0)
# ============================================================================
# END OF PLACEHOLDER
# ============================================================================

func play_background_music(event_path: String = background_music_event) -> void:
	print("🎵 [PLACEHOLDER] Music would play: ", event_path)
	is_playing = true
	music_started.emit()

func stop_music() -> void:
	print("🎵 [PLACEHOLDER] Music would stop")
	is_playing = false
	music_stopped.emit()

func set_parameter(parameter_name: String, value: float) -> void:
	print("🎵 [PLACEHOLDER] Parameter set: ", parameter_name, " = ", value)
	
	if parameter_name.begins_with("Layer_"):
		layers[parameter_name] = value
		layer_activated.emit(parameter_name, value)

func activate_layer(parameter_name: String, value: float = 1.0) -> void:
	set_parameter(parameter_name, value)

func deactivate_layer(parameter_name: String) -> void:
	set_parameter(parameter_name, 0.0)

func set_master_volume(value: float) -> void:
	current_volume = clamp(value, 0.0, 1.0)
	set_parameter("MasterVolume", current_volume)

func reset_all_layers() -> void:
	print("🎵 [PLACEHOLDER] Resetting all layers")
	for layer in layers.keys():
		set_parameter(layer, 0.0)
	layers.clear()

func create_music_emitter() -> void:
	print("🎵 [PLACEHOLDER] Would create FMOD emitter")
	# No actual emitter created in placeholder

func is_layer_active(layer_parameter: String) -> bool:
	return layers.get(layer_parameter, 0.0) > 0.0

func get_layer_value(layer_parameter: String) -> float:
	return layers.get(layer_parameter, 0.0)
