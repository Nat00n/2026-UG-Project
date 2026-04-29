extends Node # Level Progression Manager Script - Autoload
# Manages all level unlock and room-completion state for the session
# Progress is persisted to the browser's localStorage as JSON so it survives page reloads
# Because levels register themselves at scene load (after this autoload is ready),
# a pendingSavedData cache is used to apply loaded data to levels that register late

var levels: Dictionary = {}             # levelId (String) -> LevelData resource
var completedLevels: Array[String] = [] # levelIds where at least one room is done
var pendingSavedData: Dictionary = {}   # Holds localStorage data until levels register

const SAVE_KEY = "level_progression"    # localStorage key used for save/load

func _ready():
	loadProgression()

### Level Registration

func registerLevel(levelData: LevelData):
	# Called by LevelSelectionMap when it creates LevelData objects
	# Applies any previously loaded save data for this level immediately
	levels[levelData.levelId] = levelData

	if pendingSavedData.has("roomCompletion"):
		if pendingSavedData["roomCompletion"].has(levelData.levelId):
			var savedRooms = pendingSavedData["roomCompletion"][levelData.levelId]
			levelData.completedRooms.clear()
			for room in savedRooms:
				levelData.completedRooms.append(room)

	updateLevelStates()

### Completion

func completeRoom(levelId: String, roomIndex: int):
	# Marks a room as complete, awards score points, and persists the update
	if levelId not in levels:
		return

	var level = levels[levelId]
	level.completeRoom(roomIndex)

	# Score: +1 per room, +3 bonus when all rooms in a level are done
	Global.gameScore += 1
	if level.isFullyComplete():
		Global.gameScore += 3
	Global.submitScore()

	if level.isMinimumComplete() and not completedLevels.has(levelId):
		completedLevels.append(levelId)

	updateLevelStates()
	saveProgression()

### Query Helpers

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

### Unlock Logic

func updateLevelStates():
	# Two-pass unlock: first lock everything, then unlock levels whose prerequisite is met
	# This ensures consistency even if levels register in arbitrary order
	for levelId in levels:
		var level = levels[levelId]
		level.isUnlocked = (level.requiredLevelId == "")

	for levelId in levels:
		var level = levels[levelId]
		if level.requiredLevelId != "":
			var requiredLevel = levels.get(level.requiredLevelId)
			if requiredLevel and requiredLevel.isMinimumComplete():
				level.isUnlocked = true

### Persistence

func saveProgression():
	# Serialises completed room arrays for every level and writes to localStorage
	var saveData = {
		"completedLevels": completedLevels,
		"roomCompletion": {}
	}
	for levelId in levels:
		var level = levels[levelId]
		if level.completedRooms.size() > 0:
			saveData["roomCompletion"][levelId] = level.completedRooms

	var jsonStr = JSON.stringify(saveData)
	JavaScriptBridge.eval("""
		localStorage.setItem('%s', %s);
	""" % [SAVE_KEY, JSON.stringify(jsonStr)])

func loadProgression():
	# Reads saved data from localStorage and caches it in pendingSavedData
	# Levels that are already registered get the data applied immediately
	var dataStr = JavaScriptBridge.eval("""
		localStorage.getItem('%s') || 'null';
	""" % SAVE_KEY)

	if dataStr == "null" or dataStr == null:
		pendingSavedData = {}
		updateLevelStates()
		return

	var json = JSON.new()
	var parseResult = json.parse(dataStr)

	if parseResult != OK:
		pendingSavedData = {}
		updateLevelStates()
		return

	var data = json.data
	pendingSavedData = data

	if data.has("completedLevels"):
		completedLevels.clear()
		for levelId in data["completedLevels"]:
			completedLevels.append(levelId)

	# Apply saved rooms to any levels that are already registered at load time
	if data.has("roomCompletion"):
		for levelId in data["roomCompletion"]:
			if levelId in levels:
				var savedRooms = data["roomCompletion"][levelId]
				levels[levelId].completedRooms.clear()
				for room in savedRooms:
					levels[levelId].completedRooms.append(room)

	updateLevelStates()

func resetProgression():
	# Clears all in-memory state and removes the localStorage entry. Used for testing.
	completedLevels.clear()
	pendingSavedData.clear()
	for levelId in levels:
		levels[levelId].completedRooms.clear()
	JavaScriptBridge.eval("""
		localStorage.removeItem('%s');
	""" % SAVE_KEY)
	updateLevelStates()

func getUnlockedLevelsInArea(areaIndex: int) -> Array[LevelData]:
	# Returns all unlocked levels belonging to a given area index (unused in current build)
	var areaLevels: Array[LevelData] = []
	for levelId in levels:
		var level = levels[levelId]
		if level.areaIndex == areaIndex and level.isUnlocked:
			areaLevels.append(level)
	return areaLevels
