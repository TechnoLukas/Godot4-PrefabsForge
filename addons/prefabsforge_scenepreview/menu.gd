@tool
extends Control

#@onready var container = $Panel/ScrollContainer/GridContainer

@onready var container = $Panel/VBoxContainer/ScrollContainer/GridContainer
@onready var dropdown : Tree = $Panel/VBoxContainer/Tree
# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func _on_resized():
	await ready #TODO
	if size.x/300 > 0:
		container.columns=int(size.x/300)
	else:
		container.columns=1
