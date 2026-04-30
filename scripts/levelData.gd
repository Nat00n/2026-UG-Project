extends Resource # Level Data Script
class_name LevelData
# Data container for a single level
# Stored as a Resource so it can be serialised and passed between the progression manager, level selection map, and level scenes

@export var levelId: String         # Unique identifier, e.g. "1-1", "3-1"
@export var levelName: String       # Display name shown in the level selection UI
@export var position: Vector2       # Position of this node on the level selection map
@export var requiredLevelId: String = ""  # ID of the level that must be minimally complete to unlock this one, Empty = always unlocked
@export var scenePath: String       # File path to the level's .tscn scene
@export var totalRooms: int = 1     # Total number of rooms (tasks) in this level

# Runtime state — not exported, populated by LevelProgressionManager from localStorage
var isUnlocked: bool = false
var completedRooms: Array[int] = []  # Sorted list of completed room indices (0-based)

### Computed Properties

func isMinimumComplete() -> bool:
	# A level is considered to have minimum completion to unlock dependents once any single room is complete
	return completedRooms.size() >= 1

func isFullyComplete() -> bool:
	# All rooms must be complete for the star badge and bonus score to be awarded
	return completedRooms.size() >= totalRooms

func isRoomCompleted(roomIndex: int) -> bool:
	return completedRooms.has(roomIndex)

func completeRoom(roomIndex: int):
	# safely ignored if the room is already in the completed list.
	if not completedRooms.has(roomIndex):
		completedRooms.append(roomIndex)
		completedRooms.sort()  # Keep sorted for consistent iteration.
