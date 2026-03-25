extends Node2D

func getInteractables() -> Array:
	var result = []
	for child in get_children():
		if child is Area2D:
			result.append(child)
	return result
