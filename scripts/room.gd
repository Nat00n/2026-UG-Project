extends Node2D

@onready var interactable: Area2D = $Interactable
@onready var popupRef: CanvasLayer  # remove this if you had it as a var

func _ready():
	var popup = get_parent().get_node("IDE")
	interactable._popup = popup
	print("popup set: ", popup)
