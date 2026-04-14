extends Node

var levels: Dictionary = {}  # levelId -> LevelData
var completedLevels: Array[String] = []
var pendingSavedData: Dictionary = {}  # CRITICAL: Store loaded data before levels are registered

const SAVE_KEY = "level_progression"

func _ready():
	print("\n=== LEVEL PROGRESSION MANAGER ===")
	loadProgression()

func registerLevel(levelData: LevelData):
	print("\n[ProgressionMgr] registerLevel called for: ", levelData.levelId)
	print("  pendingSavedData keys: ", pendingSavedData.keys())
	
	levels[levelData.levelId] = levelData
	
	# CRITICAL: Apply any saved data for this level
	if pendingSavedData.has("roomCompletion"):
		print("  roomCompletion exists in pending data")
		print("  roomCompletion keys: ", pendingSavedData["roomCompletion"].keys())
		
		if pendingSavedData["roomCompletion"].has(levelData.levelId):
			var savedRooms = pendingSavedData["roomCompletion"][levelData.levelId]
			
			# CRITICAL: Can't directly assign to Resource Array property
			# Must clear and append instead
			levelData.completedRooms.clear()
			for room in savedRooms:
				levelData.completedRooms.append(room)
			
			print("  ✓ Applied saved data to ", levelData.levelId, ": ", levelData.completedRooms)
		else:
			print("  ✗ No saved data found for ", levelData.levelId)
	else:
		print("  ✗ No roomCompletion in pending data")
	
	print("  Final completedRooms: ", levelData.completedRooms)
	print("  isMinimumComplete: ", levelData.isMinimumComplete())
	print("  isFullyComplete: ", levelData.isFullyComplete())
	
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
	
	print("  Total completed: ", level.completedRooms.size(), "/", level.totalRooms)
	print("  Next levels unlocked: ", _getUnlockedLevelsList())

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
	print("\n[ProgressionMgr] updateLevelStates called")
	
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
				print("  o Unlocked ", levelId, " (required ", level.requiredLevelId, " is minimum complete)")
			else:
				print("  x ", levelId, " still locked (required ", level.requiredLevelId, " not complete)")
	
	print("  Unlocked levels: ", _getUnlockedLevelsList())

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
	print("\n[ProgressionMgr] Saving progression...")
	print("  Data: ", jsonStr)
	
	JavaScriptBridge.eval("""
		localStorage.setItem('%s', %s);
	""" % [SAVE_KEY, JSON.stringify(jsonStr)])
	
	# Verify it was saved
	var verification = JavaScriptBridge.eval("""
		localStorage.getItem('%s')
	""" % SAVE_KEY)
	
	if verification:
		print("  o Saved successfully")
	else:
		print("  x Save failed!")

func loadProgression():
	print("\n[ProgressionMgr] Loading progression...")
	
	var dataStr = JavaScriptBridge.eval("""
		localStorage.getItem('%s') || 'null';
	""" % SAVE_KEY)
	
	print("  Raw data: ", dataStr)
	
	if dataStr == "null" or dataStr == null:
		print("  No saved data found - starting fresh")
		pendingSavedData = {}  # Clear pending data
		updateLevelStates()
		return
	
	var json = JSON.new()
	var parseResult = json.parse(dataStr)
	
	if parseResult != OK:
		print("  x Parse error: ", json.get_error_message())
		pendingSavedData = {}
		updateLevelStates()
		return
	
	var data = json.data
	print("  Parsed data: ", data)
	
	# CRITICAL: Store this data so it can be applied when levels are registered
	pendingSavedData = data
	
	if data.has("completedLevels"):
		# Can't directly assign untyped Array to Array[String]
		completedLevels.clear()
		for levelId in data["completedLevels"]:
			completedLevels.append(levelId)
		print("  Completed levels: ", completedLevels)
	
	# Apply to any levels that are already registered
	if data.has("roomCompletion"):
		print("  Room completion data found:")
		for levelId in data["roomCompletion"]:
			if levelId in levels:
				var savedRooms = data["roomCompletion"][levelId]
				
				# CRITICAL: Can't directly assign to Resource Array
				levels[levelId].completedRooms.clear()
				for room in savedRooms:
					levels[levelId].completedRooms.append(room)
				
				print("    ", levelId, ": ", levels[levelId].completedRooms, " (applied immediately)")
			else:
				print("    ", levelId, ": will be applied when level registers")
	
	# Update level states after loading
	updateLevelStates()
	
	print("  o Load complete")

func resetProgression():
	print("\n[ProgressionMgr] Resetting all progression...")
	
	completedLevels.clear()
	pendingSavedData.clear()  # Clear pending data
	
	for levelId in levels:
		levels[levelId].completedRooms.clear()
	
	JavaScriptBridge.eval("""
		localStorage.removeItem('%s');
	""" % SAVE_KEY)
	
	updateLevelStates()
	print("  o Reset complete")

func getUnlockedLevelsInArea(areaIndex: int) -> Array[LevelData]:
	var areaLevels: Array[LevelData] = []
	for levelId in levels:
		var level = levels[levelId]
		if level.areaIndex == areaIndex and level.isUnlocked:
			areaLevels.append(level)
	return areaLevels
