"""
based on guides: 
https://www.youtube.com/watch?v=qy4nBHMXIPk
https://www.youtube.com/watch?v=42q6vZSvtxc
"""

@tool
extends EditorPlugin
class_name PrefabsForge_Model2Prefab



const menu = preload("res://addons/prefabsforge_model2prefab/menu.tscn")
var undo_redo = EditorPlugin.new().get_undo_redo()

var menu_instance
var import_path = ""
var export_path = ""

var supported_file_extensions = ["gltf","glb","obj","fbx"]

func _enter_tree():
	menu_instance = menu.instantiate()
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, menu_instance)
	_make_visible(false)
	menu_instance.import_path_button.pressed.connect(_import_path_button_pressed)
	menu_instance.export_path_button.pressed.connect(_export_path_button_pressed)
	menu_instance.import_filedialog.dir_selected.connect(_import_filedialog_selected)
	menu_instance.export_filedialog.dir_selected.connect(_export_filedialog_selected)
	menu_instance.import_path_clear_button.pressed.connect(_import_path_clear_button_pressed)
	menu_instance.export_path_clear_button.pressed.connect(_export_path_clear_button_pressed)
	menu_instance.export_button.pressed.connect(_export_button_pressed)

func _exit_tree():
	if menu_instance:
		remove_control_from_docks(menu_instance)
		menu_instance.free()
	
func _make_visible(visible):
	if menu_instance:
		menu_instance.visible=true
		
func _get_plugin_name():
	return "Prefabs Model2Prefab"
	
func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")

func _import_path_button_pressed():
	menu_instance.import_filedialog.visible=true
	
func _export_path_button_pressed():
	menu_instance.export_filedialog.visible=true
	
func _import_filedialog_selected(dir):
	menu_instance.import_file_label.text=menu_instance.import_filedialog.current_path
	import_path=menu_instance.import_file_label.text
	
func _export_filedialog_selected(dir):
	menu_instance.export_file_label.text=menu_instance.export_filedialog.current_path
	export_path=menu_instance.export_file_label.text
	
func _import_path_clear_button_pressed():
	menu_instance.import_file_label.text="..."
	import_path="res://"
	#menu_instance.import_file_label.text=menu_instance.import_filedialog.current_path
	
func _export_path_clear_button_pressed():
	menu_instance.export_file_label.text="..."
	export_path="res://"
	#menu_instance.export_file_label.text=menu_instance.export_filedialog.current_path
	
func _export_button_pressed():
	for f in DirAccess.get_files_at(import_path):
		var file_extensions = f.split(".")[1]
		if not (file_extensions in supported_file_extensions):
			push_warning("Unsupported File Extension: "+file_extensions)
		else:
			if file_extensions in f and ".import" not in f:
				var model = load(import_path+f)
				print(model)
				var new_scene = model.duplicate();
				
				ResourceSaver.save(new_scene, export_path+"/"+f.replace(file_extensions,"tscn"));
