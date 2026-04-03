extends CanvasLayer


@onready var panel: Panel = $Panel
@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton
@onready var closeButton: Button = $Panel/VSplitContainer/HSplitContainer/CloseButton
@onready var aiButton: Button = $Panel/VSplitContainer/HSplitContainer/AIButton

var _talkCallback
var _aiCallback
var _currentObject
var _executingObject
var _llmReady := false
var _llmReadyCallback
var _llmProgressCallback

func _ready():
	
	panel.visible = false
	
	closeButton.pressed.connect(onClose)
	runButton.pressed.connect(onRun)
	aiButton.pressed.connect(onAITips)
	
	if OS.has_feature("web"):
		_talkCallback = JavaScriptBridge.create_callback(talk)
		JavaScriptBridge.get_interface("window").godotTalk = _talkCallback
		
		_aiCallback = JavaScriptBridge.create_callback(onAIResponse)
		JavaScriptBridge.get_interface("window").godotAIResponse = _aiCallback
		
		_llmReadyCallback = JavaScriptBridge.create_callback(onLLMReady)
		JavaScriptBridge.get_interface("window").godotLLMReady = _llmReadyCallback

		_llmProgressCallback = JavaScriptBridge.create_callback(onLLMProgress)
		JavaScriptBridge.get_interface("window").godotLoadProgress = _llmProgressCallback

func talk(args):
	var msg = str(args[0])
	var target = _executingObject if _executingObject else _currentObject
	if target == null:
		return

	if msg.begins_with("__select__:"):
		target.selectNode(int(msg.split(":")[1]))
	elif msg.begins_with("__swap__:"):
		var parts = msg.split(":")
		target.queueSwap(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__commit__"):
		target.commitSort()
	elif msg.begins_with("__commitSelect__:"):
		target.commitSelect(int(msg.split(":")[1]))
	else:
		outputRCT.append_text(msg + "\n")


func onClose() -> void:
	if _currentObject:
		_currentObject.saveScript(inputCE.text)

	panel.visible = false
	_currentObject = null


func open(objectName: String, interactable):
	_currentObject = interactable
	
	outputRCT.clear()
	outputRCT.append_text("--- %s ---\n" % objectName)
	
	inputCE.text = interactable.savedScript
	
	panel.visible = true
	

func onLLMReady(args):
	_llmReady = true
	aiButton.disabled = false
	aiButton.text = "AI Tips"

func onLLMProgress(args):
	aiButton.text = "AI Loading"

func onAITips():
	
	if _currentObject == null or not _llmReady:
		return

	aiButton.disabled = true
	aiButton.text = "AI Thinking..."

	var playerCode = inputCE.text
	var task = _currentObject.taskDescription
	var nodeCount = _currentObject.dataNodes.size()

	# Build a prompt describing the context
	var prompt = """
You are a Python tutor inside an educational game. 
The player is working on the following task: %s
The data they are working with has %d nodes, each with a name and a value from 1-10.
They have access to these custom functions: read(index), select(index), swap(i, j), commitSort().

Here is the player's current code:
%s

Give a short, encouraging summary of what is working well, then suggest one specific improvement.
Keep the response under 100 words. Do not rewrite the full code, just give guidance.
""" % [task, nodeCount, playerCode if playerCode.strip_edges() != "" else "(empty)"]

	JavaScriptBridge.eval("window._pendingAIPrompt = %s;" % JSON.stringify(prompt))
	JavaScriptBridge.eval("""
		(async () => {
			try {
				await runAITips();
			} catch(e) {
				window.godotAIResponse("Error: " + e.message);
			}
		})();
	""")
	
	talk(["Ai thinking"])

func onAIResponse(args):
	
	var msg = str(args[0])
	aiButton.disabled = false
	aiButton.text = "AI Tips"

	# Show AI response in output box with distinct colour
	outputRCT.push_color(Color.html("#DCDCAA"))
	outputRCT.append_text("\n AI Tips:\n")
	outputRCT.pop()
	outputRCT.push_color(Color.html("#9CDCFE"))
	outputRCT.append_text(msg + "\n")
	outputRCT.pop()

func onRun():
	if _currentObject:
		_currentObject.saveScript(inputCE.text)
	_executeCode(inputCE.text, _currentObject, false)

# Called by interactable for silent background run
func runScript(code: String, interactable):
	_executeCode(code, interactable, true)

func _buildPreamble() -> String:
	return """
import sys, io

class GodotOutput(io.TextIOBase):
	def write(self, s):
		if s.strip():
			talk(str(s))
		return len(s)

sys.stdout = GodotOutput()
sys.stderr = GodotOutput()

array = """ + _currentObject.getArrayString() + """

def select(index):
	if index < 0 or index >= len(array):
		talk("Error: index " + str(index) + " out of range")
		return None
	talk("__select__:" + str(index))
	talk("Selected index " + str(index) + " (value: " + str(array[index]) + ")")
	return array["index"]

""" + _currentObject.getPreambleFunctions()

func _executeCode(code: String, target, silent: bool):
	_executingObject = target
	
	if not silent:
		outputRCT.clear()
		outputRCT.append_text("Running...\n")

	var wrapped = _buildPreamble() + "\n" + code

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
	await get_tree().create_timer(0.1).timeout
	_executingObject = null
