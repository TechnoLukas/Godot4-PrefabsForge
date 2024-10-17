@tool
extends Control

@onready var rotate_x : Button = $menu/VBoxContainer/HBoxContainer/rotate_x
@onready var rotate_y : Button = $menu/VBoxContainer/HBoxContainer/rotate_y
@onready var rotate_z : Button = $menu/VBoxContainer/HBoxContainer/rotate_z
@onready var rotation_angle : SpinBox = $menu/VBoxContainer/rotation_angle
@onready var arrange_x : Button = $menu/VBoxContainer/HBoxContainer2/arrange_x
@onready var arrange_y : Button = $menu/VBoxContainer/HBoxContainer2/arrange_y
@onready var arrange_z : Button = $menu/VBoxContainer/HBoxContainer2/arrange_z
@onready var arrange_on_grid_vertically : Button = $menu/VBoxContainer/HBoxContainer4/arrange_on_grid_vertically
@onready var arrange_on_grid_horizontally : Button = $menu/VBoxContainer/HBoxContainer4/arrange_on_grid_horizontally
@onready var arrangement_shift : SpinBox = $menu/VBoxContainer/arrangement_shift

func _ready(): 
	pass
		
