extends Control

@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton

func _ready():
	
	if OS.has_feature("web"):
		var callback = JavaScriptBridge.create_callback(talk)
		JavaScriptBridge.eval("window.godotTalk = null;", true)
		JavaScriptBridge.eval("window.godotTalk = arguments[0];", callback)
		
		
		
func _on_button_pressed():
	
	outputRCT.clear()
	outputRCT.append_text("run pressed \n")
	
	var code = inputCE.get_text()
	JavaScriptBridge.eval("""
        (async () => {
			await runPythonFromGodot(`""" + code + """`);
        })();
	""")
	
func talk(args):
	var msg = args[0]
	outputRCT.append_text("talk : \n")
	outputRCT.append_text(str(msg))
	
	
	
