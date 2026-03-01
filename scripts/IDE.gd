extends Control

@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton

func _ready():
	
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
				window.godotAPI = {
					
				talk: function(msg) {
						godotInstance.call('talk', msg);
					},
					
				};
			""")


func _on_button_pressed():
	
	outputRCT.clear()
	outputRCT.append_text("run pressed")
	
	var code = inputCE.get_text()
	JavaScriptBridge.eval("""
        (async () => {
			await runPythonFromGodot(`""" + code + """`);
        })();
	""")
	
func talk(msg):
	outputRCT.append_text("talk :")
	outputRCT.append_text("\n"+str(msg))
	
	
	
