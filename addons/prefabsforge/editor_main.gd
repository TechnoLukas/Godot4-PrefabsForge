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
var ignore_selection = false #controls selection

var mesh_current : MeshInstance3D
var mesh_current_origin 
var mesh_vertices_3d : PackedVector3Array # list of 3d point of current mesh
var mesh_vertices_2d : PackedVector2Array # list of 2d point of current mesh

var point1 = {"placed"=false,
			  "visible"=true,
			  "position_2d"=null,
			  "position_3d"=null,
			  "mesh"=null,
			  "idx"=null}
			
var point2 = {"placed"=false,
			  "visible"=true,
			  "position_2d"=null,
			  "position_3d"=null,
			  "mesh"=null,
			  "idx"=null}

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
	if mesh_vertices_2d.size()==0: return;
	for p in mesh_vertices_2d:
		distance_point_to_mouse.append(mouse.distance_to(p))
		if mouse.distance_to(p) < 12: #detect if user hovers pouse position
			if not point1.placed:
				point1.mesh=mesh_current
				point1.idx=mesh_vertices_2d.find(p)
				point1.visible=true
				
			if point1.placed and not point2.placed: 
				point2.mesh=mesh_current
				point2.idx=mesh_vertices_2d.find(p)
				point2.visible=true
	
	if point1.idx != null and point1.mesh != null: point1.position_3d=update_point(point1.mesh, point1.idx) #recalculate points position
	if point2.idx != null and point2.mesh != null: point2.position_3d=update_point(point2.mesh, point2.idx) #recalculate points position
	
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
					o.position=point1.position_3d+(o.position-point2.position_3d) # main snap
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
	return object is MeshInstance3D or not object.scene_file_path.is_empty() # or object is MultiNodeEdit (strangely not implemented or nothing there)
	
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
		if not selected_objects[-1].scene_file_path.is_empty(): # Detects if selected object is a scene
			mesh_current_origin=selected_objects[-1]
			mesh_current=selected_objects[-1].get_children()[0]
		else:
			mesh_current=selected_objects[-1] #making the last item in the selection as current mesh
		
		update_points()
	else:
		if ignore_selection: return
		if in_circle: #if user clicked on the circle but mouse did not hit the mesh, we don't want to loose everything, so we need to restore it
			for s in selected_objects_old: # VERY GLITCHY
				EditorInterface.get_selection().add_node(s)
				await get_tree().create_timer(0.1).timeout #timer in cuurent situation is must, without it, it doesn't work
			mesh_current=selected_objects_old[-1] # restoring the current mesh
			ignore_selection=true
			return
		else:
			reset_points()
			
func update_points(): # recalculates all possible snap points of selected mesh
	if mesh_current == null: return
	if mesh_current.mesh == null: return
	mesh_vertices_3d = PackedVector3Array(mesh_current.mesh.get_faces())
	mesh_vertices_2d = PackedVector2Array([])
	for v in mesh_vertices_3d:
		v = update_point(mesh_current,mesh_vertices_3d.find(v))
		var point_2d = EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(v)
		mesh_vertices_2d.append(point_2d)

		
func update_point(mesh,vertex_index): #calculates point position knowing its mesh and index
	if mesh == null: return
	var object_origin
	object_origin=mesh_current_origin
	#object_origin=mesh
	
	var mesh_vertices = PackedVector3Array(mesh.mesh.get_faces())
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(0,0,1), object_origin.rotation.z)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(1,0,0), object_origin.rotation.x)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index].rotated(Vector3(0,1,0), object_origin.rotation.y)
	mesh_vertices[vertex_index] = mesh_vertices[vertex_index] + object_origin.position
	return mesh_vertices[vertex_index]
	
func reset_points(): #stops visualising points

	mesh_current = null 
	mesh_vertices_3d = PackedVector3Array([])
	mesh_vertices_2d = PackedVector2Array([])
	
	point1 = {"placed"=false,
			  "visible"=true,
			  "position_2d"=null,
			  "position_3d"=null,
			  "mesh"=null,
			  "idx"=null}
			
	point2 = {"placed"=false,
			  "visible"=true,
			  "position_2d"=null,
			  "position_3d"=null,
			  "mesh"=null,
			  "idx"=null}

