extends Node

var levels: Dictionary = {}  # levelId -> LevelData
var completedLevels: Array[String] = []
var pendingSavedData: Dictionary = {}  # Store loaded data before levels are registered

const SAVE_KEY = "level_progression"

func _ready():
	loadProgression()

func registerLevel(levelData: LevelData):
	
	levels[levelData.levelId] = levelData
	
	# Apply any saved data for this level
	if pendingSavedData.has("roomCompletion"):
		if pendingSavedData["roomCompletion"].has(levelData.levelId):
			var savedRooms = pendingSavedData["roomCompletion"][levelData.levelId]
			levelData.completedRooms.clear()
			for room in savedRooms:
				levelData.completedRooms.append(room)
	
	updateLevelStates()

func completeRoom(levelId: String, roomIndex: int):
	if levelId not in levels:
		return

	var level = levels[levelId]
	level.completeRoom(roomIndex)

	# Award points for this first-time completion and submit
	Global.gameScore += 1
	if level.isFullyComplete():
		Global.gameScore += 3
	Global.submitScore()

	if level.isMinimumComplete() and not completedLevels.has(levelId):
		completedLevels.append(levelId)

	updateLevelStates()
	saveProgression()

func _getUnlockedLevelsList() -> Array:
	var unlocked = []
	for levelId in levels:
		if levels[levelId].isUnlocked:
			unlocked.append(levelId)
	return unlocked

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
			level.isUnlocked = true
		else:
			level.isUnlocked = false
	
	# Second pass: unlock levels whose requirements are met
	for levelId in levels:
		var level = levels[levelId]
		if level.requiredLevelId != "":
			var requiredLevel = levels.get(level.requiredLevelId)
			if requiredLevel and requiredLevel.isMinimumComplete():
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
	
	var jsonStr = JSON.stringify(saveData)
	
	JavaScriptBridge.eval("""
		localStorage.setItem('%s', %s);
	""" % [SAVE_KEY, JSON.stringify(jsonStr)])

func loadProgression():
	
	var dataStr = JavaScriptBridge.eval("""
		localStorage.getItem('%s') || 'null';
	""" % SAVE_KEY)
	
	if dataStr == "null" or dataStr == null:
		pendingSavedData = {}  # Clear pending data
		updateLevelStates()
		return
	
	var json = JSON.new()
	var parseResult = json.parse(dataStr)
	
	if parseResult != OK:
		pendingSavedData = {}
		updateLevelStates()
		return
	
	var data = json.data
	
	# Store this data so it can be applied when levels are registered
	pendingSavedData = data
	
	if data.has("completedLevels"):
		# Can't directly assign untyped Array to Array[String]
		completedLevels.clear()
		for levelId in data["completedLevels"]:
			completedLevels.append(levelId)
	
	# Apply to any levels that are already registered
	if data.has("roomCompletion"):
		for levelId in data["roomCompletion"]:
			if levelId in levels:
				var savedRooms = data["roomCompletion"][levelId]
				
				# Can't directly assign to Resource Array
				levels[levelId].completedRooms.clear()
				for room in savedRooms:
					levels[levelId].completedRooms.append(room)
	
	# Update level states after loading
	updateLevelStates()

func resetProgression():

	completedLevels.clear()
	pendingSavedData.clear()  # Clear pending data
	
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
