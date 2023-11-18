"""
based on guides: 
https://www.youtube.com/watch?v=qy4nBHMXIPk
https://www.youtube.com/watch?v=42q6vZSvtxc
"""

@tool
extends EditorPlugin
class_name PrefabsForge_old



const menu = preload("res://addons/prefabsforge/menu.tscn")
var undo_redo = EditorPlugin.new().get_undo_redo()

var menu_instance
var selected_objects=[]
var visualise_middle_st = false
var editor_objects=[]
var free_to_rotate=true

var originpoint_2d : Vector2
var originpoint_3d : Vector3

var snap_p1_3d : Vector3
var snap_p1_placed = false

var snap_p2_3d : Vector3
var snap_p2_placed = false

var mouse : Vector2 = Vector2()

var snap_p1 : Vector2 = Vector2(0,0)
var snap_p2 : Vector2 = Vector2(0,0)

var object1 : Node3D
var object1_shift : Vector3
var object2 : Node3D
var object2_shift : Vector3

var collobject : Node3D

var point_r = 10


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
	menu_instance.decompose.pressed.connect(decompose)
	menu_instance.add_collision.pressed.connect(add_collision)
	menu_instance.arrange_on_grid.pressed.connect(arrange_on_grid)
	

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

func _edit(object):
	update_overlays()

func _forward_3d_draw_over_viewport(viewport_control):
	viewport_control.draw_circle(originpoint_2d,10,Color(1,1,1))
	if snap_p1 != Vector2(): #If vector is empty, we should not draw it
		viewport_control.draw_circle(snap_p1,point_r+3,Color(0.2,0,0))
		viewport_control.draw_circle(snap_p1,point_r,Color(0.7,0.5,0.5))
	if snap_p2 != Vector2():
		viewport_control.draw_circle(snap_p2,point_r+3,Color(0,0.2,0))
		viewport_control.draw_circle(snap_p2,point_r,Color(0.5,0.7,0.5))

func _forward_3d_gui_input(camera, event):
	recalculate_origin()
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_LEFT and event.shift_pressed:
			if free_to_rotate: rotate_x()
		if event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_DOWN) and event.shift_pressed:
			if free_to_rotate: rotate_y()
		if event.pressed and event.keycode == KEY_RIGHT and event.shift_pressed:
			if free_to_rotate: rotate_z()

			
	if event is InputEventMouse:
		mouse=event.position
		if get_mouse_3d_position(camera,mouse) != {}:
			if not snap_p1_placed and not snap_p2_placed:
				snap_p1_3d = recalculate_snap_point(camera,mouse)
			elif snap_p1_placed and not snap_p2_placed:
				snap_p2_3d = recalculate_snap_point(camera,mouse)
				
		if snap_p1_3d != Vector3(): #cheking if it is not empty vector
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if event.is_pressed():
						snap_p1_placed=true
						if get_mouse_3d_position(camera,mouse) != {}:
							collobject = get_mouse_3d_position(camera,mouse).collider
						object1=collobject.get_parent()
						object1_shift=object1.position-snap_p1_3d
			snap_p1 = EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(snap_p1_3d)
		else:
			snap_p1=Vector2()
			
		if snap_p2_3d != Vector3():# or mouse.distance_to(snap_p2)<point_r/2:
			print(snap_p2_3d)
			if event is InputEventMouseButton:
				if get_mouse_3d_position(camera,mouse) != {} :
					collobject = get_mouse_3d_position(camera,mouse).collider
					object2=collobject.get_parent()
					object2_shift=object2.position-snap_p2_3d
				if event.button_index == MOUSE_BUTTON_LEFT:
					if event.is_pressed():
						snap_p2_placed=true
						undo_redo.create_action("PrefabsForge Snap")
						undo_redo.add_undo_property(object2, "position", object2.position) #saving UNDO action before we moved something
						object2.position=(object1.position-object1_shift)+object2_shift	
						undo_redo.add_do_property(object2, "position", object2.position) #saving REDO after before we moved something
						undo_redo.commit_action()
						
						snap_p1_placed=false
						snap_p1_3d=Vector3()
						snap_p2_placed=false
						snap_p2_3d=Vector3()
			snap_p2 = EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(snap_p2_3d)
		else:
			snap_p2=Vector2()
			
	update_overlays()
			

func _selection_changed():
	
	selected_objects = EditorInterface.get_selection().get_transformable_selected_nodes()
	for o in selected_objects:
		if not o is Node3D:
			selected_objects = []
	
	if selected_objects != []: #deduction method works better
		menu_instance.decompose.visible=true
		menu_instance.add_collision.visible=true
		menu_instance.arrange_on_grid.visible=true
	for o in selected_objects:
		if o == EditorInterface.get_edited_scene_root():
			menu_instance.decompose.visible=false
			menu_instance.arrange_on_grid.visible=false
			menu_instance.add_collision.visible=false
		if not o.get_scene_file_path():
			menu_instance.decompose.visible=false
		if o is MeshInstance3D:
			if o.get_child_count()!=0:
				menu_instance.add_collision.visible=false
		else:
			menu_instance.add_collision.visible=false
	
	if selected_objects == [] and mouse.distance_to(snap_p2)>point_r:
		print("clear")
		snap_p1_placed=false
		snap_p1_3d=Vector3()
		snap_p2_placed=false
		snap_p2_3d=Vector3()
		menu_instance.decompose.visible=false
		menu_instance.add_collision.visible=false
	print(selected_objects)
	recalculate_origin()
	update_overlays()
			
func recalculate_origin():
	var poslist = Vector3(0,0,0)
	for i in selected_objects:
		poslist+=i.position
	originpoint_3d=poslist/selected_objects.size()
	originpoint_2d=EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(originpoint_3d)

func recalculate_snap_point(cam:Camera3D,mouse:Vector2):
	var collobject:Node3D = get_mouse_3d_position(cam,mouse).collider
	var object:Node3D = collobject.get_parent()
	var objectmesh = object.mesh
	var objectmesh_new = PackedVector3Array(objectmesh.get_faces())
	
	for i in objectmesh_new.size():
		objectmesh_new.set(i, objectmesh_new[i].rotated(Vector3(0,0,1), object.rotation.z))
		
	for i in objectmesh_new.size():
		objectmesh_new.set(i, objectmesh_new[i].rotated(Vector3(1,0,0), object.rotation.x))
		
	for i in objectmesh_new.size():
		objectmesh_new.set(i, objectmesh_new[i].rotated(Vector3(0,1,0), object.rotation.y))
	
	var mouse_to_vertex_dist :Array = []
	for v in objectmesh_new:
		mouse_to_vertex_dist.append(abs(get_mouse_3d_position(cam,mouse).position-(v+object.position)))
	
	var snap = 0.1
	var dis_to_point = mouse_to_vertex_dist.min().snapped(Vector3(snap,snap,snap))
	var snap_3d
	var result
	
	if dis_to_point == Vector3(0,0,0):
		snap_3d = objectmesh_new[mouse_to_vertex_dist.find(mouse_to_vertex_dist.min())]+object.position
		result=EditorInterface.get_editor_viewport_3d().get_camera_3d().unproject_position(snap_3d)
	else:
		snap_3d = Vector3()
	
	return snap_3d
		
	
	
func get_mouse_3d_position(cam:Camera3D,mouse:Vector2):
	var worldspace = cam.get_world_3d().direct_space_state
	#var plane_corner1 = cam.project_ray_origin(Vector2(0,0))
	#var plane_corner1 = cam.project_ray_origin(Vector2(0,0))
	var start = cam.project_ray_origin(mouse)
	var end = cam.project_position(mouse,10)
	var query := PhysicsRayQueryParameters3D.create(start, end)
	var result = worldspace.intersect_ray(query)
	return result
	
	
	#cam.project_ray_origin
	
	
# ----------------------------------------------------------------------------------------------------------------- 
		
func rotate_x(angle=menu_instance.rotation_angle.value):
	if not selected_objects.is_empty():
		free_to_rotate=false # blocks the function, so it wont be stacked
		undo_redo.create_action("PrefabsForge Rotate")
		for so in selected_objects:
			undo_redo.add_undo_property(so, "position", so.position) #saving UNDO action before we moved something
			undo_redo.add_undo_property(so, "rotation", so.rotation)
			
			var tween = create_tween()
			var des = originpoint_3d + (originpoint_3d-so.position).rotated(Vector3(1,0,0),deg_to_rad(180-angle)) #rotating vector
			#so.position = Vector3(so.position.x,des.y,des.z)
			tween.tween_property(so, "position", Vector3(so.position.x,des.y,des.z), 0.05) #smooth
			so.rotate_x(deg_to_rad(-angle)) #rotating object itself
			
			undo_redo.add_do_property(so, "position", so.position) #saving REDO after before we moved something
			undo_redo.add_do_property(so, "rotation", so.rotation)	
		undo_redo.commit_action()
		await get_tree().create_timer(0.1).timeout		
		free_to_rotate=true
		
		
func rotate_y(angle=menu_instance.rotation_angle.value):
	if not selected_objects.is_empty():
		free_to_rotate=false # blocks the function, so it wont be stacked
		undo_redo.create_action("PrefabsForge Rotate")
		for so in selected_objects:
			undo_redo.add_undo_property(so, "position", so.position) #saving UNDO action before we moved something
			undo_redo.add_undo_property(so, "rotation", so.rotation)
			
			var tween = create_tween()
			var des = originpoint_3d + (originpoint_3d-so.position).rotated(Vector3(0,1,0),deg_to_rad(180-angle)) #rotating vector
			#so.position = Vector3(des.x,so.position.y,des.z)
			tween.tween_property(so, "position", Vector3(des.x,so.position.y,des.z), 0.05) #smooth
			so.rotate_y(deg_to_rad(-angle)) #rotating object itself
			
			undo_redo.add_do_property(so, "position", so.position) #saving REDO after before we moved something
			undo_redo.add_do_property(so, "rotation", so.rotation)
		undo_redo.commit_action()
		await get_tree().create_timer(0.1).timeout		
		free_to_rotate=true
			
func rotate_z(angle=menu_instance.rotation_angle.value):
	if not selected_objects.is_empty():
		free_to_rotate=false # blocks the function, so it wont be stacked
		undo_redo.create_action("PrefabsForge Rotate")
		for so in selected_objects:
			undo_redo.add_undo_property(so, "position", so.position) #saving UNDO action before we moved something
			undo_redo.add_undo_property(so, "rotation", so.rotation)
			
			var tween = create_tween()
			var des = originpoint_3d + (originpoint_3d-so.position).rotated(Vector3(0,0,1),deg_to_rad(180-angle)) #rotating vector
			#so.position = Vector3(des.x,des.y,so.position.z) #not changing Z position because we are rotating around Z
			tween.tween_property(so, "position", Vector3(des.x,des.y,so.position.z), 0.05) #smooth
			so.rotate_z(deg_to_rad(-angle)) #rotating object itself
			
			undo_redo.add_do_property(so, "position", so.position) #saving REDO after before we moved something
			undo_redo.add_do_property(so, "rotation", so.rotation)
		undo_redo.commit_action()
		await get_tree().create_timer(0.1).timeout		
		free_to_rotate=true
		
func arrange_x():
	if not selected_objects.is_empty():
		undo_redo.create_action("PrefabsForge Arrange X")
		for o in selected_objects.slice(1,selected_objects.size()):
			undo_redo.add_undo_property(o, "position", o.position) #saving UNDO action before we moved something
			o.position.y=selected_objects[0].position.y
			o.position.z=selected_objects[0].position.z
			undo_redo.add_do_property(o, "position", o.position) #saving REDO after before we moved something
		undo_redo.commit_action()
	
func arrange_y():
	if not selected_objects.is_empty():
		undo_redo.create_action("PrefabsForge Arrange Y")
		for o in selected_objects.slice(1,selected_objects.size()):
			undo_redo.add_undo_property(o, "position", o.position) #saving UNDO action before we moved something
			o.position.x=selected_objects[0].position.x
			o.position.z=selected_objects[0].position.z
			undo_redo.add_do_property(o, "position", o.position) #saving REDO after before we moved something
		undo_redo.commit_action()
	
func arrange_z():
	if not selected_objects.is_empty():
		undo_redo.create_action("PrefabsForge Arrange Z")
		for o in selected_objects.slice(1,selected_objects.size()):
			undo_redo.add_undo_property(o, "position", o.position) #saving UNDO action before we moved something
			o.position.x=selected_objects[0].position.x
			o.position.y=selected_objects[0].position.y
			undo_redo.add_do_property(o, "position", o.position) #saving REDO after before we moved something
		undo_redo.commit_action()
		
func decompose():
	for o in selected_objects:
		var mainnodeparent = o.get_owner()
		var modelscene =  load(str(o.get_scene_file_path())).instantiate()
		var modelmeshes = []
		
		undo_redo.create_action("PrefabsForge Decompose")
		modelmeshes = findmeshs(modelscene.get_children(),modelmeshes)
		for ms:MeshInstance3D in modelmeshes:
			var newmesh = MeshInstance3D.new()
			newmesh.mesh=ms.mesh
			EditorInterface.get_edited_scene_root().add_child(newmesh)
			newmesh.set_owner(EditorInterface.get_edited_scene_root())
			newmesh.position=o.position
			newmesh.rotation=o.rotation
			newmesh.name=o.name+"_mesh"
			
			#o.queue_free()
			o.call_deferred("queue_free")
		undo_redo.commit_action()
		print(modelmeshes)

func findmeshs(children,meshes): #Function that goes through every child of every sub child to find MeshInstance3D
	for i in children:
		if i.get_child_count() != 0:
			meshes = findmeshs(i.get_children(),meshes)
		else:
			if i is MeshInstance3D:
				meshes.append(i)
				return meshes
				
func add_collision():
	for o in selected_objects:
		o.create_trimesh_collision()
		o.get_child(0).get_child(0).set_meta("_edit_lock_", true)

func arrange_on_grid():
	var sqrt_len = ceil(sqrt(selected_objects.size()))
	var i = 0
	var step = 5
	undo_redo.create_action("PrefabsForge Arrange On Grid")
	for x in range(sqrt_len):
		for y in range(sqrt_len):
			if i > selected_objects.size()-1:
				undo_redo.commit_action()
				return
			undo_redo.add_undo_property(selected_objects[i], "position", selected_objects[i].position) #saving UNDO action before we moved something
			selected_objects[i].position=Vector3(x*step,y*step,0)
			undo_redo.add_do_property(selected_objects[i], "position", selected_objects[i].position) #saving UNDO action before we moved something			
			i+=1
	undo_redo.commit_action()
			
		
