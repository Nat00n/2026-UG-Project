extends Node

var levels: Dictionary = {}  # levelId : LevelData
var completedLevels: Array[String] = []

const SAVE_KEY = "level_progression"

func _ready():
	loadProgression()

func registerLevel(levelData: LevelData):
	levels[levelData.levelId] = levelData
	updateLevelStates()

func completeLevel(levelId: String):
	if levelId in levels:
		levels[levelId].isCompleted = true
		if not completedLevels.has(levelId):
			completedLevels.append(levelId)
		updateLevelStates()
		saveProgression()

func isLevelUnlocked(levelId: String) -> bool:
	if levelId in levels:
		return levels[levelId].isUnlocked
	return false

func isLevelCompleted(levelId: String) -> bool:
	return completedLevels.has(levelId)

func updateLevelStates():
	# First pass: mark all levels as locked
	for levelId in levels:
		var level = levels[levelId]
		if level.requiredLevelId == "":
			# No requirement means it's the starting level
			level.isUnlocked = true
		else:
			level.isUnlocked = false
	
	# Second pass: unlock levels whose requirements are met
	for levelId in levels:
		var level = levels[levelId]
		if level.requiredLevelId != "" and isLevelCompleted(level.requiredLevelId):
			level.isUnlocked = true

func saveProgression():
	var saveData = {
		"completedLevels": completedLevels
	}
	JavaScriptBridge.eval("""
		localStorage.setItem('%s', JSON.stringify(%s));
	""" % [SAVE_KEY, JSON.stringify(saveData)])

func loadProgression():
	var dataStr = JavaScriptBridge.eval("""
		localStorage.getItem('%s') || 'null';
	""" % SAVE_KEY)
	
	if dataStr != "null":
		var json = JSON.new()
		var parseResult = json.parse(dataStr)
		if parseResult == OK:
			var data = json.data
			if data.has("completedLevels"):
				completedLevels = data["completedLevels"]
	
	updateLevelStates()

func resetProgression():
	completedLevels.clear()
	JavaScriptBridge.eval("""
		localStorage.removeItem('%s');
	""" % SAVE_KEY)
	updateLevelStates()

func getUnlockedLevelsInArea(areaIndex: int) -> Array[LevelData]:
	var areaLevels: Array[LevelData] = []
	for levelId in levels:
		var level = levels[levelId]
		if level.areaIndex == areaIndex and level.isUnlocked:
			areaLevels.append(level)
	return areaLevels
