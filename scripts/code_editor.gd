extends Control

const pythonSubset = preload("res://scripts/pythonSubset.gd")

@onready var inputCE: CodeEdit = $VSplitContainer/CodeEdit
@onready var outputRCT: RichTextLabel = $VSplitContainer/RichTextLabel


func _on_button_pressed() -> void:
	var code = inputCE
	var interpret = pythonSubset.new()
	var result = interpret.run(code)
	var outputRCT = str(result)
	
