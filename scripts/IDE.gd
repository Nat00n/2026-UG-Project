extends CanvasLayer


@onready var panel: Panel = $Panel
@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var guideBox: RichTextLabel = $Panel/VSplitContainer/GuideBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton
@onready var closeButton: Button = $Panel/VSplitContainer/HSplitContainer/CloseButton
@onready var aiButton: Button = $Panel/VSplitContainer/HSplitContainer/AIButton
@onready var editorTabButton: Button = $Panel/VSplitContainer/HSplitContainer/EditorTabButton
@onready var guideTabButton: Button = $Panel/VSplitContainer/HSplitContainer/GuideTabButton

var _talkCallback
var _aiCallback
var _currentObject
var _executingObject
var _llmReady := false
var _llmReadyCallback
var _llmProgressCallback
var _onEditorTab := true

func _ready():
	panel.visible = false

	closeButton.pressed.connect(onClose)
	runButton.pressed.connect(onRun)
	aiButton.pressed.connect(onAITips)
	editorTabButton.pressed.connect(_showEditorTab)
	guideTabButton.pressed.connect(_showGuideTab)

	_setupSyntaxHighlighting()
	_showEditorTab()

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

	# Sort
	if msg.begins_with("__swap__:"):
		var parts = msg.split(":")
		target.queueSwap(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__pivot__:"):
		target.queuePivot(int(msg.split(":")[1]))
	elif msg.begins_with("__commit__"):
		target.commitSort()
	elif msg.begins_with("__move__:"):
		var parts = msg.split(":")
		target.queueMove(int(parts[1]), int(parts[2]))

	# Search
	elif msg.begins_with("__check__:"):
		target.queueCheck(int(msg.split(":")[1]))
	elif msg.begins_with("__commitSelect__:"):
		target.queueSelect(int(msg.split(":")[1]))
		target.commitSearch()
	elif msg.begins_with("__select__:"):
		target.selectNode(int(msg.split(":")[1]))

	# Graph
	elif msg.begins_with("__visit__:"):
		target.queueVisit(int(msg.split(":")[1]))
	elif msg.begins_with("__path__:"):
		var parts = msg.split(":")[1].split(",")
		var pathIds = []
		for p in parts:
			if p.strip_edges() != "":
				pathIds.append(int(p))
		target.queuePath(pathIds)
		target.startPathAnimation()

	# Coin change
	elif msg.begins_with("__addcoin__:"):
		target.addCoinToStack(int(msg.split(":")[1]))
	elif msg.begins_with("__removecoin__:"):
		target.removeCoinFromStack(int(msg.split(":")[1]))
	elif msg.begins_with("__commitchange__:"):
		var parts = msg.split(":")[1].split(",")
		var coinList = []
		for p in parts:
			if p.strip_edges() != "":
				coinList.append(int(p))
		target.commitChange(coinList)

	# Knapsack
	elif msg.begins_with("__cell__:"):
		var parts = msg.split(":")
		target.queueCellFill(int(parts[1]), int(parts[2]), int(parts[3]))
	elif msg.begins_with("__backtrack__:"):
		var parts = msg.split(":")
		target.queueBacktrack(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__taken__:"):
		var parts = msg.split(":")
		target.queueTaken(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__skipped__:"):
		var parts = msg.split(":")
		target.queueSkipped(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__knapsack__:"):
		var parts = msg.split(":")[1].split(",")
		var indices = []
		for p in parts:
			if p.strip_edges() != "":
				indices.append(int(p))
		target.commitKnapsack(indices)

	# Default output
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
	_showEditorTab()
	panel.visible = true

func _setupSyntaxHighlighting():
	var highlighter = CodeHighlighter.new()

	# Keywords
	var keywords = ["False", "None", "True", "and", "as", "assert", "async", "await",
		"break", "class", "continue", "def", "del", "elif", "else", "except",
		"finally", "for", "from", "global", "if", "import", "in", "is",
		"lambda", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"]
	for kw in keywords:
		highlighter.add_keyword_color(kw, Color.html("#569CD6"))

	# Built-ins
	var builtins = ["print", "len", "range", "int", "str", "float", "list",
		"dict", "set", "tuple", "type", "enumerate", "zip", "map",
		"filter", "sorted", "reversed", "min", "max", "sum", "abs"]
	for b in builtins:
		highlighter.add_keyword_color(b, Color.html("#DCDCAA"))

	# Colors
	highlighter.number_color = Color.html("#B5CEA8")
	highlighter.symbol_color = Color.html("#D4D4D4")
	highlighter.function_color = Color.html("#DCDCAA")
	highlighter.member_variable_color = Color.html("#9CDCFE")

	# Strings
	highlighter.add_color_region('"', '"', Color.html("#CE9178"))
	highlighter.add_color_region("'", "'", Color.html("#CE9178"))

	# Comments
	highlighter.add_color_region("#", "", Color.html("#6A9955"), true)

	inputCE.syntax_highlighter = highlighter

func _showEditorTab():
	_onEditorTab = true
	inputCE.visible = true
	outputRCT.visible = true
	guideBox.visible = false
	editorTabButton.add_theme_color_override("font_color", Color.WHITE)
	guideTabButton.remove_theme_color_override("font_color")
	runButton.visible = true
	aiButton.visible = true

func _showGuideTab():
	_onEditorTab = false
	inputCE.visible = false
	outputRCT.visible = false
	guideBox.visible = true
	guideTabButton.add_theme_color_override("font_color", Color.WHITE)
	editorTabButton.remove_theme_color_override("font_color")
	runButton.visible = false
	aiButton.visible = false
	_populateGuide()

func _populateGuide():
	guideBox.clear()
	if _currentObject == null:
		return
	
	if _currentObject.taskName.strip_edges() != "":
		guideBox.append_text("[b]%s[/b]\n\n" % _currentObject.taskName)
	
	var base = _currentObject._getBaseGuide()
	if base.strip_edges() != "":
		guideBox.append_text(base + "\n\n")
	
	if _currentObject.taskGuide.strip_edges() != "":
		guideBox.append_text("[b]Your Task:[/b]\n" + _currentObject.taskGuide)


func onLLMReady(args):
	_llmReady = true
	aiButton.disabled = false
	aiButton.text = "= AI Tips ="

func onLLMProgress(args):
	aiButton.text = "= AI Loading ="

func onAITips():
	
	if _currentObject == null or not _llmReady:
		return

	aiButton.disabled = true
	aiButton.text = "= AI Thinking... ="

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
	aiButton.text = "= AI Tips ="

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
		
	if target.has_method("resetDisplay"):
		target.resetDisplay()

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
