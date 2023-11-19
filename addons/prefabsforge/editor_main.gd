"""
based on guides: 
https://www.youtube.com/watch?v=qy4nBHMXIPk
https://www.youtube.com/watch?v=42q6vZSvtxc
"""

@tool
extends EditorPlugin
class_name PrefabsForge

var undo_redo = EditorPlugin.new().get_undo_redo()

var selected_objects_old = []#only to restore the selection
var ignore_selection = false

var mesh_current : MeshInstance3D
var mesh_vertices_3d : PackedVector3Array
var mesh_vertices_2d : PackedVector2Array
var point_list = []

var mesh1 : MeshInstance3D
var mesh2 : MeshInstance3D

var point1 = {"placed"=false,
			  "visible"=true,
			  "position_2d"=Vector2(0,0),
			  "position_3d"=Vector3(0,0,0),
			  "mesh"=null,
			  "idx"=null}
			
var point2 = {"placed"=false,
			  "visible"=true,
			  "position_2d"=Vector2(0,0),
			  "position_3d"=Vector3(0,0,0),
			  "mesh"=null,
			  "idx"=null}

var camera
var mouse : Vector2
var event

var in_circle # check if mouse is in the circle
var selection_mode # check if object is in the selection mode, then no sanpping points

func _enter_tree():
	_make_visible(false)
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)
	
func _exit_tree():
	pass
	
func _make_visible(visible):
	pass
		
func _get_plugin_name():
	return "Prefabs Forge"
	
func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")

func _process(delta):
	if event is InputEventMouse:
		mouse=event.position
		
	var distance_point_to_mouse : Array
	if not point1.placed: point1.visible=false
	if not point2.placed: point2.visible=false
	for p in mesh_vertices_2d:
		distance_point_to_mouse.append(mouse.distance_to(p))
		if mouse.distance_to(p) < 12:
			if not point1.placed:
				point1.mesh=mesh_current
				point1.idx=mesh_vertices_2d.find(p)
				point1.visible=true
			if point1.placed and not point2.placed: 
				point2.mesh=mesh_current
				point2.idx=mesh_vertices_2d.find(p)
				point2.visible=true
	
	if point1.idx and point1.mesh: point1.position_3d=update_point(point1.mesh, point1.idx)
	if point2.idx and point2.mesh: point2.position_3d=update_point(point2.mesh, point2.idx)
	
	if point1.position_3d: point1.position_2d=EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(point1.position_3d)
	if point2.position_3d: point2.position_2d=EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(point2.position_3d)
	
	if event is InputEventMouseButton and not selection_mode:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			if mouse.distance_to(point1.position_2d) < 12:
				in_circle=true
				point1.placed=true
			elif mouse.distance_to(point2.position_2d) < 12:
				in_circle=true
				point2.placed=true
			else:
				in_circle=false
			
	if event is InputEventKey:
		selection_mode = Input.is_key_pressed(KEY_SHIFT)
			
	update_points()
	update_overlays()
	
func _forward_3d_gui_input(cam, ev):
	camera=cam
	event=ev
			
func _handles(object):
	#print(object)
	return object is MeshInstance3D # or object is MultiNodeEdit (strangely not implemented or nothing there)
	

func _forward_3d_draw_over_viewport(viewport_control):
	if ignore_selection: ignore_selection=false;
	if point1.visible and not selection_mode:
		viewport_control.draw_circle(point1.position_2d,10,Color(0,0,0))
		viewport_control.draw_circle(point1.position_2d,8,Color(0.5,0.7,0.5))
		
	if point2.visible and not selection_mode:
		viewport_control.draw_circle(point2.position_2d,10,Color(0,0,0))
		viewport_control.draw_circle(point2.position_2d,8,Color(0.7,0.5,0.5))

func _selection_changed():
	var selected_objects = EditorInterface.get_selection().get_transformable_selected_nodes()
	if selected_objects.size()>0 and check_object(selected_objects[-1]):
		selected_objects_old = selected_objects
		mesh_current=selected_objects[-1]
		update_points()
	else:
		if ignore_selection: return
		if in_circle: 
			for s in selected_objects_old:
				EditorInterface.get_selection().add_node(s)
				await get_tree().create_timer(0.1).timeout
			mesh_current=selected_objects_old[-1]
			ignore_selection=true
			return
		else:
			point1.placed=false
			point2.placed=false
			
func update_points():
	if mesh_current == null: return
	if mesh_current.mesh == null: return
	mesh_vertices_3d = PackedVector3Array(mesh_current.mesh.get_faces())
	mesh_vertices_2d = PackedVector2Array([])
	for v in mesh_vertices_3d:
		v = update_point(mesh_current,mesh_vertices_3d.find(v))
		var point_2d = EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(v)
		mesh_vertices_2d.append(point_2d)
		
func update_point(mesh,vertex_index):
	if mesh == null: return
	var mesh_vertices = PackedVector3Array(mesh.mesh.get_faces())
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(0,0,1), mesh.rotation.z)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(1,0,0), mesh.rotation.x)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(0,1,0), mesh.rotation.y)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index] + mesh.position
	return mesh_vertices[vertex_index]
	
func check_object(object):
	return object is MeshInstance3D
