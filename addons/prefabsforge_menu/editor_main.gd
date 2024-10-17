"""
based on guides: 
https://www.youtube.com/watch?v=qy4nBHMXIPk
https://www.youtube.com/watch?v=42q6vZSvtxc
"""

@tool
extends EditorPlugin
class_name PrefabsForge_Menu



const menu = preload("res://addons/prefabsforge_menu/menu.tscn")
var undo_redo = EditorPlugin.new().get_undo_redo()

var menu_instance
var selected_objects=[]
var visualise_middle_st = false
var editor_objects=[]
var free_to_rotate=true

var originpoint_2d : Vector2
var originpoint_3d : Vector3

func _enter_tree():
	menu_instance = menu.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, menu_instance)
	_make_visible(false)
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)
	menu_instance.rotate_x.pressed.connect(rotate_x)
	menu_instance.rotate_y.pressed.connect(rotate_y)
	menu_instance.rotate_z.pressed.connect(rotate_z)
	menu_instance.arrange_x.pressed.connect(arrange_x)
	menu_instance.arrange_y.pressed.connect(arrange_y)
	menu_instance.arrange_z.pressed.connect(arrange_z)
	menu_instance.arrange_on_grid_vertically.pressed.connect(arrange_on_grid_vertically)
	menu_instance.arrange_on_grid_horizontally.pressed.connect(arrange_on_grid_horizontally)
	

func _exit_tree():
	if menu_instance:
		remove_control_from_docks(menu_instance)
		menu_instance.free()
	
func _make_visible(visible):
	if menu_instance:
		menu_instance.visible=true
		
func _get_plugin_name():
	return "Prefabs Forge"
	
func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")

func _handles(object):
	return object is Node3D
	
func _forward_3d_gui_input(camera, event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_LEFT and event.shift_pressed:
			if free_to_rotate: rotate_x()
		if event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_DOWN) and event.shift_pressed:
			if free_to_rotate: rotate_y()
		if event.pressed and event.keycode == KEY_RIGHT and event.shift_pressed:
			if free_to_rotate: rotate_z()

func _selection_changed():
	selected_objects = EditorInterface.get_selection().get_transformable_selected_nodes()
	for o in selected_objects:
		if not _handles(o):
			selected_objects = []
	originpoint_3d = Vector3()
	for o in selected_objects:
		originpoint_3d += o.global_position
	originpoint_3d=originpoint_3d/selected_objects.size()
	
	
# ----------------------------------------------------------------------------------------------------------------- 
func save_undo(object):
	undo_redo.add_undo_property(object, "position", object.position) #saving UNDO action before we moved something
	undo_redo.add_undo_property(object, "rotation", object.rotation)
	
func save_redo(object):
	undo_redo.add_do_property(object, "position", object.position) #saving UNDO action before we moved something
	undo_redo.add_do_property(object, "rotation", object.rotation)

func rotate(angle, vector):
	free_to_rotate=false # blocks the function, so it wont be stacked
	undo_redo.create_action("PrefabsForge Rotate")
	for so in selected_objects:
		save_undo(so)
		var des = originpoint_3d + (originpoint_3d-so.global_position).rotated(vector,deg_to_rad(180-angle)) #rotating vector
		var pos_vec = (Vector3(1,1,1)-vector)*des # inverse des vector
		so.global_position=(so.global_position*vector)+pos_vec
		Vector3(so.global_position.x,des.y,des.z)
		so.global_rotate(vector,-deg_to_rad(angle))
		save_redo(so)	
	undo_redo.commit_action()	
	free_to_rotate=true
	
func arrange(vector):
	undo_redo.create_action("PrefabsForge Arrange")
	for o in selected_objects.slice(1,selected_objects.size()):
		save_undo(o)
		var inverse_vector = Vector3(1.0,1.0,1.0)-vector #inverse vector
		o.global_position=(o.global_position*vector)+(selected_objects[0].global_position*inverse_vector)
		save_redo(o)
	undo_redo.commit_action()

func rotate_x(angle=menu_instance.rotation_angle.value):
	if not selected_objects.is_empty():
		rotate(angle, Vector3(1,0,0))
		
func rotate_y(angle=menu_instance.rotation_angle.value):
	if not selected_objects.is_empty():
		rotate(angle, Vector3(0,1,0))
			
func rotate_z(angle=menu_instance.rotation_angle.value):
	if not selected_objects.is_empty():
		rotate(angle, Vector3(0,0,1))
		
func arrange_x():
	if not selected_objects.is_empty():
		arrange(Vector3(1,0,0))
	
func arrange_y():
	if not selected_objects.is_empty():
		arrange(Vector3(0,1,0))
	
func arrange_z():
	if not selected_objects.is_empty():
		arrange(Vector3(0,0,1))

func arrange_on_grid_vertically():
	undo_redo.create_action("PrefabsForge Arrange On Grid")
	arrange_on_grid(Vector3(0,0,1))
	undo_redo.commit_action()
	
func arrange_on_grid_horizontally():
	undo_redo.create_action("PrefabsForge Arrange On Grid")
	arrange_on_grid(Vector3(0,1,0))
	undo_redo.commit_action()

func arrange_on_grid(vector):
	var sqrt_len = ceil(sqrt(selected_objects.size()))
	var i = 0
	var step = menu_instance.arrangement_shift.value #5
	var reverse_vector = Vector3(1,1,1) - vector
	undo_redo.create_action("PrefabsForge Arrange On Grid")
	for x in range(sqrt_len):
		for y in range(sqrt_len):
			if i > selected_objects.size()-1:
				undo_redo.commit_action()
				return
			undo_redo.add_undo_property(selected_objects[i], "position", selected_objects[i].position) #saving UNDO action before we moved something
			selected_objects[i].global_position=Vector3(x*step,y*step,y*step)*reverse_vector
			undo_redo.add_do_property(selected_objects[i], "position", selected_objects[i].position) #saving UNDO action before we moved something			
			i+=1
	undo_redo.commit_action()
			
		
