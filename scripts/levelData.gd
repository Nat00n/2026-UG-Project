extends Resource
class_name LevelData

@export var levelId: String
@export var levelName: String
@export var areaIndex: int  # 0=green, 1=yellow, 2=blue, 3=purple
@export var position: Vector2  # Position on the map
@export var requiredLevelId: String = ""  # Empty string means it's unlocked by default
@export var scenePath: String  # Path to the level scene

var isUnlocked: bool = false
var isCompleted: bool = false
