@tool
extends Control

@onready var import_path_button : Button = $menu/VBoxContainer/HBoxContainer/import_path_button
@onready var export_path_button : Button = $menu/VBoxContainer/HBoxContainer2/export_path_button
@onready var import_filedialog : FileDialog = $menu/import_filedialog
@onready var export_filedialog : FileDialog = $menu/export_filedialog
@onready var import_file_label : Label = $menu/VBoxContainer/HBoxContainer/import_path_label
@onready var export_file_label : Label = $menu/VBoxContainer/HBoxContainer2/export_path_label
@onready var import_path_clear_button : Button = $menu/VBoxContainer/HBoxContainer/import_path_clear
@onready var export_path_clear_button : Button = $menu/VBoxContainer/HBoxContainer2/export_path_clear
@onready var export_button : Button = $menu/VBoxContainer/export_button

func _ready(): 
	pass
		
