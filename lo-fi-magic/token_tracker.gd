extends Node

signal all_tokens_collected

var total_tokens := 0
var collected_tokens := 0

func register_token() -> void:
	total_tokens += 1

func collect_token() -> void:
	collected_tokens += 1
	if collected_tokens >= total_tokens:
		all_tokens_collected.emit()
