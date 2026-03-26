extends CanvasLayer


@onready var panel: Panel = $Panel
@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton
@onready var closeButton: Button = $Panel/VSplitContainer/HSplitContainer/CloseButton

var _talkCallback
var _currentObject

func _ready():
	
	panel.visible = false
	
	closeButton.pressed.connect(onClose)
	runButton.pressed.connect(onRun)
	
	if OS.has_feature("web"):
		_talkCallback = JavaScriptBridge.create_callback(talk)
		JavaScriptBridge.get_interface("window").godotTalk = _talkCallback

func talk(args): # test function to see that the python -> JavaScript -> Godot bridge works
	var msg = str(args[0])
	if msg.begins_with("__select__:"):
		var index = int(msg.split(":")[1])
		_currentObject.selectNode(index)
	elif msg.begins_with("__swap__:"):
		# format: __swap__:i:j
		var parts = msg.split(":")
		_currentObject.queueSwap(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__commit__"):
		_currentObject.commitSort()
	else:
		outputRCT.append_text(msg + "\n")


func onClose() -> void:
	if _currentObject:
		_currentObject.saveScript(inputCE.text)
		# Run silently on close
		_currentObject.runSavedScript()

	panel.visible = false
	_currentObject = null


func open(objectName: String, interactable):
	_currentObject = interactable
	
	outputRCT.clear()
	outputRCT.append_text("--- %s ---\n" % objectName)
	
	inputCE.text = interactable.savedScript
	
	panel.visible = true
	

func onRun():
	if _currentObject:
		_currentObject.saveScript(inputCE.text)
	_executeCode(inputCE.text, false)

# Called by interactable for silent background run
func runScript(code: String, interactable):
	_currentObject = interactable
	_executeCode(code, true)

func _executeCode(code: String, silent: bool):
	if not silent:
		outputRCT.clear()
		outputRCT.append_text("Running...\n")

	var nodesStr = "["
	for n in _currentObject.dataNodes:
		nodesStr += '{"name": "%s", "value": %d},' % [n["name"], n["value"]]
	nodesStr += "]"

	var wrapped = """
import sys, io

class GodotOutput(io.TextIOBase):
	def write(self, s):
		if s.strip():
			talk(str(s))
		return len(s)

sys.stdout = GodotOutput()
sys.stderr = GodotOutput()

dataNodes = """ + nodesStr + """

def read(index):
	if index < 0 or index >= len(dataNodes):
		talk("Error: index " + str(index) + " out of range")
		return None
	node = dataNodes[index]
	result = node["name"] + " = " + str(node["value"])
	talk(result)
	return node["value"]

def select(index):
	if index < 0 or index >= len(dataNodes):
		talk("Error: index " + str(index) + " out of range")
		return None
	talk("__select__:" + str(index))
	node = dataNodes[index]
	talk("Selected: " + node["name"] + " (value: " + str(node["value"]) + ")")
	return node["value"]

def swap(i, j):
	talk("__swap__:" + str(i) + ":" + str(j))
	dataNodes[i], dataNodes[j] = dataNodes[j], dataNodes[i]

def commitSort():
	talk("__commit__")

""" + code

	JavaScriptBridge.eval("window._pendingCode = %s;" % JSON.stringify(wrapped))
	JavaScriptBridge.eval("""
		(async () => {
			try {
				await runPythonFromGodot();
			} catch(e) {
				if (window.godotTalk) window.godotTalk("Error: " + e.message);
			}
		})();
	""")
