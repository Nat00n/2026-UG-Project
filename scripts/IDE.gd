extends CanvasLayer # IDE Script
# The in-game code editor popup. Opens when the player interacts with any puzzle object
# Provides a two-tab interface, a Task Guide (instructions + reference) and a Code Editor (syntax-highlighted CodeEdit, output console, Run button, and AI hint button)
# Python execution is handled by Pyodide running in the browser, communication between Godot and JavaScript uses JavaScriptBridge.
# The AI hint feature uses WebLLM (in-browser LLM)

@onready var panel: Panel = $Panel
@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var guideContainer: HBoxContainer = $Panel/VSplitContainer/GuideContainer
@onready var guideTaskColumn: VBoxContainer = $Panel/VSplitContainer/GuideContainer/TaskScrollContainer/TaskColumn
@onready var guideTaskText: RichTextLabel = $Panel/VSplitContainer/GuideContainer/TaskScrollContainer/TaskColumn/TaskText
@onready var showExampleButton: Button = $Panel/VSplitContainer/GuideContainer/TaskScrollContainer/TaskColumn/ShowExampleButton
@onready var exampleCodeLabel: RichTextLabel = $Panel/VSplitContainer/GuideContainer/TaskScrollContainer/TaskColumn/ExampleCode
@onready var guideDataColumn: RichTextLabel = $Panel/VSplitContainer/GuideContainer/DataColumn
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton
@onready var closeButton: Button = $Panel/VSplitContainer/HSplitContainer/CloseButton
@onready var aiButton: Button = $Panel/VSplitContainer/HSplitContainer/AIButton
@onready var editorTabButton: Button = $Panel/VSplitContainer/HSplitContainer/EditorTabButton
@onready var guideTabButton: Button = $Panel/VSplitContainer/HSplitContainer/GuideTabButton

var _talkCallback        # JavaScriptBridge callback for receiving output from Python
var _aiCallback          # JavaScriptBridge callback for receiving the AI hint response
var _currentObject       # The InteractableObject currently open in the IDE
var _executingObject     # The object whose script is currently running (may differ during silent runs)
var _llmReady := false
var _llmReadyCallback    # Notified by JavaScript when the WebLLM model finishes loading
var _llmProgressCallback # Notified with loading progress updates
var _onEditorTab := true
var _lastTabPerObject := {}  # Remembers which tab was active per object for UX continuity

const maxOutputLines = 400 # limits lines for the outputbox, helps with memory issues

### Ready

func _ready():
	panel.visible = false

	closeButton.pressed.connect(onClose)
	runButton.pressed.connect(onRun)
	aiButton.pressed.connect(onAITips)
	editorTabButton.pressed.connect(_showEditorTab)
	guideTabButton.pressed.connect(_showGuideTab)
	showExampleButton.pressed.connect(_onShowExamplePressed)
	inputCE.text_changed.connect(_onCodeChanged)

	_setupSyntaxHighlighting()
	_setupExampleButton()
	_showEditorTab()

	if OS.has_feature("web"):
		# Register Godot functions as global JavaScript callbacks so Pyodide and WebLLM can call back into Godot
		_talkCallback = JavaScriptBridge.create_callback(talk)
		JavaScriptBridge.get_interface("window").godotTalk = _talkCallback

		_aiCallback = JavaScriptBridge.create_callback(onAIResponse)
		JavaScriptBridge.get_interface("window").godotAIResponse = _aiCallback

		_llmReadyCallback = JavaScriptBridge.create_callback(onLLMReady)
		JavaScriptBridge.get_interface("window").godotLLMReady = _llmReadyCallback

		_llmProgressCallback = JavaScriptBridge.create_callback(onLLMProgress)
		JavaScriptBridge.get_interface("window").godotLoadProgress = _llmProgressCallback

### Message Router (talk)

func talk(args):
	# Central dispatcher: receives all messages from the player's running Python script
	# (via window.godotTalk) and routes them to the appropriate object method or output box
	var msg = str(args[0])
	var target = _executingObject if _executingObject else _currentObject
	if target == null:
		return

	# Sort messages
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
	elif msg.begins_with("__split__:"):
		var parts = msg.split(":")
		target.queueHighlightSplit(int(parts[1]), int(parts[2]), int(parts[3]))

	# Search messages
	elif msg.begins_with("__check__:"):
		target.queueCheck(int(msg.split(":")[1]))
	elif msg.begins_with("__commitSelect__:"):
		target.queueSelect(int(msg.split(":")[1]))
		target.commitSearch()

	# Graph messages
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

	# Coin change messages
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

	# Knapsack messages
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

	else:
		# Unrecognised prefix, treated as plain print() output and display in the console
		_appendOutput(msg + "\n")

### Open / Close

func onClose() -> void:
	if _currentObject:
		_currentObject.saveScript(inputCE.text)
		_lastTabPerObject[_currentObject] = _onEditorTab  # Remember which tab was active
	panel.visible = false
	_currentObject = null

func open(objectName: String, interactable):
	_currentObject = interactable
	Analytics.startTask(_currentObject)
	outputRCT.clear()
	_appendOutput("--- %s ---\n" % objectName)
	inputCE.text = interactable.savedScript

	# Restore the last-used tab for returning players, default to Guide for first open
	if _lastTabPerObject.has(interactable):
		if _lastTabPerObject[interactable]:
			_showEditorTab()
		else:
			_showGuideTab()
	else:
		_showGuideTab()

	panel.visible = true

### Syntax Highlighting

func _setupSyntaxHighlighting():
	# Configures the CodeHighlighter with Dracula-inspired colours for Python keywords,
	# builtins, numbers, strings, and comments
	var highlighter = CodeHighlighter.new()

	var keywords = ["False", "None", "True", "and", "as", "assert", "async", "await",
		"break", "class", "continue", "def", "del", "elif", "else", "except",
		"finally", "for", "from", "global", "if", "import", "in", "is",
		"lambda", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"]
	for kw in keywords:
		highlighter.add_keyword_color(kw, Color.html("#FF79C6"))

	var builtins = ["print", "len", "range", "int", "str", "float", "list",
		"dict", "set", "tuple", "type", "enumerate", "zip", "map",
		"filter", "sorted", "reversed", "min", "max", "sum", "abs"]
	for b in builtins:
		highlighter.add_keyword_color(b, Color.html("#8BE9FD"))

	highlighter.number_color = Color.html("#BD93F9")
	highlighter.symbol_color = Color.html("#F8F8F2")
	highlighter.function_color = Color.html("#50FA7B")
	highlighter.member_variable_color = Color.html("#F8F8F2")
	highlighter.add_color_region('"', '"', Color.html("#F1FA8C"))
	highlighter.add_color_region("'", "'", Color.html("#F1FA8C"))
	highlighter.add_color_region("#", "", Color.html("#6272A4"), true)

	inputCE.syntax_highlighter = highlighter

### Tab System

func _showEditorTab():
	_onEditorTab = true
	inputCE.visible = true
	outputRCT.visible = true
	guideContainer.visible = false
	aiButton.visible = true
	runButton.visible = true
	_setActiveTab(editorTabButton, guideTabButton)

func _showGuideTab():
	_onEditorTab = false
	inputCE.visible = false
	outputRCT.visible = false
	guideContainer.visible = true
	aiButton.visible = false
	runButton.visible = false
	_setActiveTab(guideTabButton, editorTabButton)
	_populateGuide()

func _setActiveTab(activeButton: Button, inactiveButton: Button):
	# Styles the active tab with a filled background and the inactive one as transparent
	var activeStyle = StyleBoxFlat.new()
	activeStyle.bg_color = Color(0.25, 0.25, 0.25)
	activeStyle.corner_radius_top_left = 4; activeStyle.corner_radius_top_right = 4
	activeStyle.corner_radius_bottom_left = 4; activeStyle.corner_radius_bottom_right = 4
	activeButton.add_theme_stylebox_override("normal", activeStyle)
	activeButton.add_theme_stylebox_override("hover", activeStyle)
	var inactiveStyle = StyleBoxEmpty.new()
	inactiveButton.add_theme_stylebox_override("normal", inactiveStyle)
	inactiveButton.add_theme_stylebox_override("hover", inactiveStyle)

func _populateGuide():
	# Fills both guide columns from the current object's exported fields and getBaseGuide()
	guideTaskText.clear()
	guideDataColumn.clear()
	showExampleButton.visible = false
	exampleCodeLabel.visible = false
	if _currentObject == null:
		return
	if _currentObject.taskName.strip_edges() != "":
		guideTaskText.append_text("[b][font_size=28]%s[/font_size][/b]\n\n" % _currentObject.taskName)
	if _currentObject.taskGuide.strip_edges() != "":
		guideTaskText.append_text("[b][color=#FFDD88]Your Task:[/color][/b]\n")
		guideTaskText.append_text(_currentObject.taskGuide + "\n")
	if _currentObject.exampleCode.strip_edges() != "":
		showExampleButton.visible = true
		exampleCodeLabel.text = ""
	var base = _currentObject.getBaseGuide()
	if base.strip_edges() != "":
		guideDataColumn.append_text("[b][font_size=22][color=#88DDFF]Reference[/color][/font_size][/b]\n\n")
		guideDataColumn.append_text(base)

func _onShowExamplePressed():
	# Reveals the example solution and records the reveal event for analytics
	if _currentObject == null:
		return
	Analytics.recordRevealedCode(_currentObject)
	showExampleButton.visible = false
	exampleCodeLabel.clear()
	exampleCodeLabel.append_text("[b][color=#90EE90]Example Solution:[/color][/b]\n\n")
	exampleCodeLabel.append_text("[code]%s[/code]" % _currentObject.exampleCode)
	exampleCodeLabel.visible = true

func _setupExampleButton():
	# Applies green border styling to the Show Example button to distinguish it visually
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.23, 0.23, 0.23)
	for side in ["border_width_left","border_width_right","border_width_top","border_width_bottom"]:
		normal_style.set(side, 2)
	normal_style.border_color = Color.html("#90EE90")
	for r in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		normal_style.set(r, 8)
	showExampleButton.add_theme_stylebox_override("normal", normal_style)

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.3, 0.3)
	hover_style.border_color = Color.html("#B0FFB0")
	showExampleButton.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.15, 0.15)
	showExampleButton.add_theme_stylebox_override("pressed", pressed_style)

	guideTaskColumn.add_theme_constant_override("separation", 20)

### AI Hint Feature

func onLLMReady(args):
	# Called by JavaScript once the WebLLM model has finished downloading and initialising
	_llmReady = true
	aiButton.disabled = false
	aiButton.text = "= AI Tips ="

func onLLMProgress(args):
	aiButton.text = "= AI Loading ="

func onAITips():
	# Sends a Socratic tutoring prompt to the in-browser LLM and shows a loading state
	if _currentObject == null:
		return
	var llmReady = JavaScriptBridge.eval("window.llmReady === true")
	if not llmReady:
		aiButton.text = "= AI Loading ="
		return
	Analytics.recordAiTip(_currentObject)
	aiButton.disabled = true
	aiButton.text = "= AI Thinking... ="

	var playerCode = inputCE.text
	var task = _currentObject.taskDescription
	var preamble = _currentObject.getBaseGuide()

	# System prompt instructs the LLM to ask guiding questions rather than write code
	var prompt = """You are a coding tutor in an educational game. 
You must NEVER write code or pseudocode. Only ask questions and give hints.

Task: %s

Available functions and data:
%s

Player's code:
%s

Give one short hint or ask one guiding question to help the player improve their code.  
Keep your response under 50 words.""" % [
		task if task.strip_edges() != "" else "No task provided.",
		preamble.strip_edges(),
		playerCode.strip_edges() if playerCode.strip_edges() != "" else "(empty)"
	]

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
	talk(["AI Thinking..."])

func onAIResponse(args):
	# Displays the LLM's response in the output console with a distinct colour
	var msg = str(args[0])
	aiButton.disabled = false
	aiButton.text = "= AI Tips ="
	outputRCT.push_color(Color.html("#DCDCAA"))
	_appendOutput("\n AI Tips:\n")
	outputRCT.pop()
	outputRCT.push_color(Color.html("#9CDCFE"))
	_appendOutput(msg + "\n")
	outputRCT.pop()

### Code Execution

func onRun():
	if _currentObject:
		_currentObject.saveScript(inputCE.text)
		Analytics.recordRun(_currentObject)
		AudioManager.playSFX("code_run")
	_executeCode(inputCE.text, _currentObject, false)

func _onCodeChanged():
	# Auto-saves the script to the object's savedScript field on every keystroke.
	if _currentObject:
		_currentObject.saveScript(inputCE.text)

func runScript(code: String, interactable):
	# Public entry point for silent background execution
	_executeCode(code, interactable, true)

func _appendOutput(text: String):
	# FIFO system for output text, as to not cause memory issues
	outputRCT.append_text(text)
	
	var lineCount = outputRCT.get_line_count()
	if lineCount > maxOutputLines + 100:
		var linesToRemove = lineCount - maxOutputLines
		var lines = outputRCT.get_parsed_text().split("\n")
		lines = lines.slice(linesToRemove)
		outputRCT.clear()
		outputRCT.append_text("\n".join(lines))
	
	outputRCT.scroll_to_line(outputRCT.get_line_count() - 1)

func _buildPreamble() -> String:
	# Constructs the Python code injected before the player's script
	# Redirects stdout/stderr to the Godot output box and defines the array and task functions
	return """
import sys, io

class GodotOutput(io.TextIOBase):
	def write(self, s):
		if s.strip():
			talk(str(s))
		return len(s)

sys.stdout = GodotOutput()
sys.stderr = GodotOutput()

array = """ + _currentObject.getArrayString() + _currentObject.getPreambleFunctions()

func _executeCode(code: String, target, silent: bool):
	# Resets the object's output display,
	# Builds the full script (preamble + player code),
	# passes it to the JavaScript runPythonFromGodot() function which calls Pyodide,
	# then clears the executing object reference once the async call returns
	_executingObject = target
	if not silent:
		outputRCT.clear()
		_appendOutput("Running...\n")
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
