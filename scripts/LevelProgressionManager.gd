extends Node

# Singleton for managing level progression
var levels: Dictionary = {}  # levelId -> LevelData
var completedLevels: Array[String] = []  # Levels with at least 1 room complete

const SAVE_KEY = "level_progression"

func _ready():
	loadProgression()

func registerLevel(levelData: LevelData):
	levels[levelData.levelId] = levelData
	updateLevelStates()

func completeRoom(levelId: String, roomIndex: int):
	if levelId in levels:
		var level = levels[levelId]
		level.completeRoom(roomIndex)
		
		# Mark level as completed if this is the first room
		if level.isMinimumComplete() and not completedLevels.has(levelId):
			completedLevels.append(levelId)
		
		updateLevelStates()
		saveProgression()
		
		print("[LevelProgress] Completed room " + str(roomIndex) + " in " + levelId)
		print("  Rooms: " + str(level.completedRooms.size()) + "/" + str(level.totalRooms))

func isLevelUnlocked(levelId: String) -> bool:
	if levelId in levels:
		return levels[levelId].isUnlocked
	return false

func isLevelMinimumComplete(levelId: String) -> bool:
	if levelId in levels:
		return levels[levelId].isMinimumComplete()
	return false

func isLevelFullyComplete(levelId: String) -> bool:
	if levelId in levels:
		return levels[levelId].isFullyComplete()
	return false

func getRoomCompletion(levelId: String) -> Array[int]:
	if levelId in levels:
		return levels[levelId].completedRooms
	return []

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
	# A level is unlocked if the required level has minimum completion (at least 1 room)
	for levelId in levels:
		var level = levels[levelId]
		if level.requiredLevelId != "" and isLevelMinimumComplete(level.requiredLevelId):
			level.isUnlocked = true

func saveProgression():
	var saveData = {
		"completedLevels": completedLevels,
		"roomCompletion": {}
	}
	
	# Save completed rooms for each level
	for levelId in levels:
		var level = levels[levelId]
		if level.completedRooms.size() > 0:
			saveData["roomCompletion"][levelId] = level.completedRooms
	
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
			
			# Load room completion data
			if data.has("roomCompletion"):
				for levelId in data["roomCompletion"]:
					if levelId in levels:
						levels[levelId].completedRooms = data["roomCompletion"][levelId]
	
	updateLevelStates()

func resetProgression():
	completedLevels.clear()
	for levelId in levels:
		levels[levelId].completedRooms.clear()
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
