extends Control

@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton

func _ready():
	
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
				window.godotAPI = {
					
				talk: function(x) {
						godotInstance.exports.talk(x);
					},
					
				};
			""")


func _on_button_pressed():
	
	outputRCT.clear()
	
	var code = inputCE.get_text()
	JavaScriptBridge.eval("""
        (async () => {
			await runPythonFromGodot(`""" + code + """`);
        })();
	""")
	
	
func talk(input):
	outputRCT.append_text(str(input))
	print(input,"talk function")
	
	
	
