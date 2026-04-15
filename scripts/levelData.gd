extends Resource
class_name LevelData

@export var levelId: String
@export var levelName: String
@export var areaIndex: int  # 0=green, 1=yellow, 2=blue, 3=purple
@export var position: Vector2  # Position on the map
@export var requiredLevelId: String = ""  # Empty string means it's unlocked by default
@export var scenePath: String  # Path to the level scene

# Room tracking
@export var totalRooms: int = 1  # How many rooms are in this level

var isUnlocked: bool = false
var completedRooms: Array[int] = []  # Indices of completed rooms (0-based)

# Computed properties
func isMinimumComplete() -> bool:
	# Level is "minimally complete" if at least 1 room is done
	return completedRooms.size() >= 1

func isFullyComplete() -> bool:
	# Level is "fully complete" if all rooms are done
	return completedRooms.size() >= totalRooms

func getRoomCompletionRatio() -> float:
	if totalRooms == 0:
		return 0.0
	return float(completedRooms.size()) / float(totalRooms)

func isRoomCompleted(roomIndex: int) -> bool:
	return completedRooms.has(roomIndex)

func completeRoom(roomIndex: int):
	if not completedRooms.has(roomIndex):
		completedRooms.append(roomIndex)
		completedRooms.sort()  # Keep sorted for easier debugging
