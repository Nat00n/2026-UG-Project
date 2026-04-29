extends Node2D # Room Script
# Thin container node, Each Room holds one or more InteractableObject children
# Exposes getInteractables() so the Level and RoomManager can enumerate objects
# without knowing the concrete child types
 
func getInteractables() -> Array:
	var result = []
	for child in get_children():
		if child is Area2D:
			result.append(child)
	return result
 
func onShow():
	# Called by RoomManager each time this room becomes visible
	# Re-loads saved scripts so player code is always up to date when switching rooms
	for interactable in getInteractables():
		interactable._loadScript()
