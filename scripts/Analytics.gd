extends Node # Analytics Script - Autoload
# Collects behavioural data about player interactions for dissertation evaluation
# Each task is tracked from first open through to completion (or abandonment)
# Data is sent via HTTP POST to a Google Apps Script web app, which writes to a spreadsheet

const ENDPOINT = "https://script.google.com/macros/s/AKfycbyP0ddm45X65XxTMScwj61E5wlZVcLniCa-wUqQnX9capkiMh1oDVC3H2t2vQZIFLqY/exec"

var objectLevelMap: Dictionary = {}  # Maps objectID -> levelId for attaching level context to events
var taskDataMap: Dictionary = {}     # Stores one data record per task object across the session

### Registration

func registerObject(objectId: String, levelId: String):
	# Called by the Level script when connecting object signals, records which level each object belongs to
	objectLevelMap[objectId] = levelId

func startTask(interactable):
	# Initialises the data record for an object on first open. Subsequent calls are returned
	# so the record is not overwritten if the player reopens the same task
	if taskDataMap.has(interactable.objectID):
		return
	taskDataMap[interactable.objectID] = {
		"username": Global.username,
		"level": objectLevelMap.get(interactable.objectID, "unknown"),
		"task": interactable.taskName,
		"runNumber": 0,          # How many times the player pressed Run
		"revealedCode": false,   # Whether the example solution was revealed
		"aiTipsRequested": 0,    # Number of AI hint requests
		"complete": false        # Whether the task was verified as correct
	}

### Event Recording

func recordRun(interactable):
	# Increments the run counter each time the player executes their code
	var objectId = interactable.objectID
	if not taskDataMap.has(objectId):
		startTask(interactable)
	taskDataMap[objectId]["runNumber"] += 1
	sendEvent("taskRun", objectId)

func recordComplete(objectId: String):
	# Marks the task as successfully completed and dispatches a completion event
	if not taskDataMap.has(objectId):
		return
	taskDataMap[objectId]["complete"] = true
	sendEvent("taskComplete", objectId)

func recordRevealedCode(interactable):
	# Flags that the player chose to view the example solution for this task
	var objectId = interactable.objectID
	if not taskDataMap.has(objectId):
		startTask(interactable)
	taskDataMap[objectId]["revealedCode"] = true

func recordAiTip(interactable):
	# Increments the AI tip counter each time the player requests a hint
	var objectId = interactable.objectID
	if not taskDataMap.has(objectId):
		startTask(interactable)
	taskDataMap[objectId]["aiTipsRequested"] += 1

### Analytical Event Saving

func sendEvent(eventType: String, objectId: String):
	# Serialises the task record alongside event type and elapsed time, then sends it
	# to the Google Apps Script endpoint using a fire-and-forget
	if not taskDataMap.has(objectId):
		return
	var body = taskDataMap[objectId].duplicate()
	body["event"] = eventType
	var elapsed = int(Time.get_unix_time_from_system() - Global.startTime)
	body["elapsedTime"] = "%02d:%02d" % [elapsed / 60, elapsed % 60]
	JavaScriptBridge.eval("window._pendingAnalytics = %s;" % JSON.stringify(body))
	JavaScriptBridge.eval("""
		fetch('%s', {
			method: 'POST',
			mode: 'no-cors',
			headers: { 'Content-Type': 'text/plain' },
			body: JSON.stringify(window._pendingAnalytics)
		}).catch(function(err) {
			console.error('Analytics error:', err);
		});
	""" % ENDPOINT)
