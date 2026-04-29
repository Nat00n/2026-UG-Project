extends Node

const ENDPOINT = "https://script.google.com/macros/s/AKfycbyP0ddm45X65XxTMScwj61E5wlZVcLniCa-wUqQnX9capkiMh1oDVC3H2t2vQZIFLqY/exec"

var objectLevelMap: Dictionary = {}
var taskDataMap: Dictionary = {}

func registerObject(objectId: String, levelId: String):
	objectLevelMap[objectId] = levelId

func startTask(interactable):
	if taskDataMap.has(interactable.objectID):
		return
	taskDataMap[interactable.objectID] = {
		"username": Global.username,
		"level": objectLevelMap.get(interactable.objectID, "unknown"),
		"task": interactable.taskName,
		"runNumber": 0,
		"revealedCode": false,
		"aiTipsRequested": 0,
		"complete": false
	}

func recordRun(interactable):
	var objectId = interactable.objectID
	if not taskDataMap.has(objectId):
		startTask(interactable)
	taskDataMap[objectId]["runNumber"] += 1
	sendEvent("taskRun", objectId)

func recordComplete(objectId: String):
	if not taskDataMap.has(objectId):
		return
	taskDataMap[objectId]["complete"] = true
	sendEvent("taskComplete", objectId)

func recordRevealedCode(interactable):
	var objectId = interactable.objectID
	if not taskDataMap.has(objectId):
		startTask(interactable)
	taskDataMap[objectId]["revealedCode"] = true

func recordAiTip(interactable):
	var objectId = interactable.objectID
	if not taskDataMap.has(objectId):
		startTask(interactable)
	taskDataMap[objectId]["aiTipsRequested"] += 1

func sendEvent(eventType: String, objectId: String):
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
