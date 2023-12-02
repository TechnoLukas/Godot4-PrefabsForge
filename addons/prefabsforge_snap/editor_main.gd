"""
based on guides: 
https://www.youtube.com/watch?v=qy4nBHMXIPk
https://www.youtube.com/watch?v=42q6vZSvtxc
"""

@tool
extends EditorPlugin
class_name PrefabsForge

var undo_redo = EditorPlugin.new().get_undo_redo() #

var selected_objects_old = [] #only to restore the selection (has only MeshInstances inside)
var meshes_in_scene = []
var global_position: Vector3
var ignore_selection = false #controls selection

class MeshC:
	var instance: MeshInstance3D = null
	var origin: Node3D = null
	var vertices_3d : PackedVector3Array
	var vertices_2d : PackedVector2Array

var mesh_current: MeshC = MeshC.new()

class Point:
	var origin: Node3D = null
	var placed: bool = false
	var visible: bool = true
	var position_2d = null
	var position_3d = null
	var mesh: MeshInstance3D = null
	var idx = null

var point1: Point = Point.new()
var point2: Point = Point.new()

var mouse : Vector2 #stores mouse position
var event

var in_circle # check if mouse is in the circle
var multi_selection_mode # check if object is in the multi selection mode, then no snapping points (selection with SHIFT)

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
	if mesh_current.vertices_2d.size()==0: return;
	for p in mesh_current.vertices_2d:
		distance_point_to_mouse.append(mouse.distance_to(p))
		if mouse.distance_to(p) < 12: #detect if user hovers pouse position
			if not point1.placed:
				point1.origin=mesh_current.origin
				point1.mesh=mesh_current.instance
				point1.idx=mesh_current.vertices_2d.find(p)
				point1.visible=true
				
			if point1.placed and not point2.placed: 
				point2.origin=mesh_current.origin
				point2.mesh=mesh_current.instance
				point2.idx=mesh_current.vertices_2d.find(p)
				point2.visible=true
	
	if point1.idx != null and point1.mesh != null: point1.position_3d=update_point(point1.mesh, point1.origin, point1.idx) #recalculate points position
	if point2.idx != null and point2.mesh != null: point2.position_3d=update_point(point2.mesh, point2.origin, point2.idx) #recalculate points position
	
	if point1.position_3d != null: point1.position_2d=EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(point1.position_3d)
	if point2.position_3d != null: point2.position_2d=EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(point2.position_3d)

	
	if event is InputEventMouseButton and not multi_selection_mode:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT: 
			if point1.position_2d != null and mouse.distance_to(point1.position_2d) < 12: #detects if user clicked on first point
				in_circle=true
				point1.placed=true
			elif point2.position_2d != null and mouse.distance_to(point2.position_2d) < 12: #detects if user clicked on second point
				in_circle=true
				point2.placed=true
				
				#Final point
				undo_redo.create_action("PrefabsForge Snap") 
				for o in selected_objects_old:
					undo_redo.add_undo_property(o, "position", o.position) #saving UNDO action before we moved something
					o.global_position=point1.position_3d+(o.global_position-point2.position_3d) # main snap
					undo_redo.add_do_property(o, "position", o.position) #saving REDO after before we moved something
				undo_redo.commit_action()
				reset_points()
				
			else:
				in_circle=false
			
	if event is InputEventKey:
		multi_selection_mode = Input.is_key_pressed(KEY_SHIFT)
	
	update_points() #recalculate of points lists
	update_overlays() #update draw method

	
func _forward_3d_gui_input(cam, ev): # listen to all events
	event=ev # save all events so we can acces them in "procces"
			
func _handles(object): #checking if correct node #MUST for 3d plugins
	if object is Node3D:
		return object is MeshInstance3D or not object.scene_file_path.is_empty()
	else:
		return object is MeshInstance3D # or object is MultiNodeEdit (strangely not implemented or nothing there)
	
func _forward_3d_draw_over_viewport(viewport_control): #main draw method
	if point1.position_2d == null and point2.position_2d == null: return
	if ignore_selection: ignore_selection=false;
	if point1.visible and not multi_selection_mode:
		viewport_control.draw_circle(point1.position_2d,10,Color(0,0,0)) #outline
		viewport_control.draw_circle(point1.position_2d,8,Color(0.5,0.7,0.5)) #main cicle
		
	if point2.visible and not multi_selection_mode:
		viewport_control.draw_circle(point2.position_2d,10,Color(0,0,0)) #outline
		viewport_control.draw_circle(point2.position_2d,8,Color(0.7,0.5,0.5)) #main cicle

func _selection_changed():
	var selected_objects = EditorInterface.get_selection().get_transformable_selected_nodes()
	var everything_ok = true
	
	for o in selected_objects: 
		if o.scene_file_path.is_empty():
			if not _handles(o): #we must check every object in the selection so there would be no errors
				everything_ok=false
	if (selected_objects.size()>0 and everything_ok): #checking if everything is ok
		selected_objects_old = selected_objects
		mesh_current.origin=selected_objects[-1] # setting mesh parent (origin), from it we will calculate all shifts and rotations
		if not selected_objects[-1].scene_file_path.is_empty(): # Detects if selected object is a scene
			meshes_in_scene = []
			get_all_children(selected_objects[-1])
			
			var global_vertex_list : PackedVector3Array
			for m in meshes_in_scene:
				for fi in range(m.mesh.get_faces().size()):
					global_vertex_list.append(update_point(m, m, fi))					

			var faces_array = []
			faces_array.resize(Mesh.ARRAY_MAX)
			faces_array[Mesh.ARRAY_VERTEX] = global_vertex_list
			
			var new_mesh_instance= MeshInstance3D.new()
			new_mesh_instance.mesh = ArrayMesh.new()
			
			new_mesh_instance.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, faces_array)
			new_mesh_instance.position=selected_objects[-1].position
			mesh_current.instance=new_mesh_instance
		else:
			mesh_current.instance=selected_objects[-1] #making the last item in the selection as current mesh
		update_points()
	else:
		if ignore_selection: return
		if in_circle: #if user clicked on the circle but mouse did not hit the mesh, we don't want to loose everything, so we need to restore it
			for s in selected_objects_old: # VERY GLITCHY
				EditorInterface.get_selection().add_node(s)
				#await get_tree().create_timer(0.1).timeout #timer in cuurent situation is must, without it, it doesn't work
			mesh_current.instance=selected_objects_old[-1] # restoring the current mesh
			ignore_selection=true
			return
		else:
			reset_points()
			
func update_points(): # recalculates all possible snap points of selected mesh
	if mesh_current.instance == null: return
	if mesh_current.instance.mesh == null: return
	mesh_current.vertices_3d = PackedVector3Array(mesh_current.instance.mesh.get_faces())
	mesh_current.vertices_2d = PackedVector2Array([])
	for v in mesh_current.vertices_3d:
		v = update_point(mesh_current.instance,mesh_current.origin,mesh_current.vertices_3d.find(v))
		var point_2d = EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(v)
		mesh_current.vertices_2d.append(point_2d)

		
func update_point(mesh,mesh_origin,vertex_index): #calculates point position knowing its mesh and index
	if mesh == null: return
	var mesh_vertices = PackedVector3Array(mesh.mesh.get_faces())
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(0,0,1), mesh_origin.global_rotation.z)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(1,0,0), mesh_origin.global_rotation.x)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(0,1,0), mesh_origin.global_rotation.y)

	mesh_vertices[vertex_index] = mesh_vertices[vertex_index] + mesh_origin.global_position - mesh_origin.get_owner().global_position
	
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(0,1,0), -mesh_origin.get_owner().global_rotation.y)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(1,0,0), -mesh_origin.get_owner().global_rotation.x)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(0,0,1), -mesh_origin.get_owner().global_rotation.z)
	return mesh_vertices[vertex_index]
	
func reset_points(): #stops visualising points
	mesh_current= MeshC.new()	
	point1 = Point.new()
	point2 = Point.new()
	
func get_all_children(in_node,arr:=[]):
	arr.push_back(in_node)
	if in_node is MeshInstance3D:
		meshes_in_scene.append(in_node)
	for child in in_node.get_children():
		if child.scene_file_path.is_empty():
			arr = get_all_children(child,arr)
	return arr

