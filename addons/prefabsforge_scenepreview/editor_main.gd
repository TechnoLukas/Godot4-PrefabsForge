"""
based on guides: 
https://www.youtube.com/watch?v=qy4nBHMXIPk
https://www.youtube.com/watch?v=42q6vZSvtxc
"""

@tool
extends EditorPlugin
class_name PrefabsForge_ScenePreview

const scene = preload("res://addons/prefabsforge_scenepreview/scene.tscn")

var menu_instance
var models_dictionary = {}

func _ready():
	var images = DirAccess.get_files_at("res://addons/prefabsforge_scenepreview/assets/images/")
	load_images(images)
	menu_instance.dropdown.item_selected.connect(_item_clicked)
	dictonarize_images(images)

func _enter_tree():
	menu_instance = scene.instantiate()	
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, menu_instance)
	_make_visible(false)
	
func _exit_tree():
	if menu_instance:
		remove_control_from_docks(menu_instance)
		menu_instance.free()
	
func _make_visible(visible):
	if menu_instance:
		menu_instance.visible=true
		
func _get_plugin_name():
	return "Prefabs Forge Scene"
	
func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")

func _item_clicked(item: TreeItem = menu_instance.dropdown.get_selected()):
	#print(item.get_text(0)," ",item.get_tooltip_text(0))
	var path = [item]
	get_item_path(item,path)
	var path_str=""
	for i in range(path.size(),0,-1):
		path_str+="_"+path[i-1].get_tooltip_text(0)
	path_str=path_str.erase(0)
	update_images(path_str)
	print(path_str)

func get_item_path(item, path):
	var parent = item.get_parent()
	#print(path)
	if item.get_parent() is TreeItem:
		path.append(parent)
		get_item_path(parent, path)
	else:
		path.pop_back()
		return path
		
func update_images(name):
	for image in menu_instance.container.get_children():
		if name in image.name:
			image.visible=true
		else:
			image.visible=false

# ----------------------------------------------------------------------
	
func load_images(images):
	for c in menu_instance.container.get_children():
		c.queue_free()
		
	for img in images:
		if "import" not in img:
			var image = Image.load_from_file("res://addons/prefabsforge_scenepreview/assets/images/"+img)
			var texture = ImageTexture.create_from_image(image)
			texture.set_size_override(Vector2(300,300))
			var texturerect = TextureRect.new()
			texturerect.texture=texture
			texturerect.size=Vector2(300,300)
			texturerect.custom_minimum_size=Vector2(300,300)
			texturerect.name=img
			texturerect.tooltip_text=img.rstrip(".png")
			menu_instance.container.add_child(texturerect)	
	
	
func dictonarize_images(images):
	var groups_list = []
	for img in images:
		if ".import" not in img:
			var image_name=img.split(".")[0]
			var split = image_name.split("_")
			var steps = [{split[-1]:null}]
			for gi in range(1,split.size()):
				var dict = {}
				#dict[steps[-1]]=split[split.size()-(gi+1)]
				dict[split[split.size()-(gi+1)]]=steps[-1]
				steps.append(dict)
			groups_list.append(steps[-1])
			#print(groups_list[-1])
	for l in groups_list.slice(0,groups_list.size()):
		#print(l)
		merge_nested_dicts(models_dictionary,l)
			
	print(JSON.stringify(models_dictionary,"	"))
	
	buildTree(models_dictionary)

func merge_nested_dicts(d1, d2):
	if not d2 is Dictionary or not d1 is Dictionary: return
	for key in d2.keys():
		if key in d1:
			merge_nested_dicts(d1[key], d2[key])
		else:
			d1[key]=d2[key]
			
func buildTree(dict):
	var root = menu_instance.dropdown.create_item()
	menu_instance.dropdown.set_hide_root(true)
	
	for i in dict.keys():
		var category = menu_instance.dropdown.create_item(root)
		category.set_text(0,i)
		category.set_tooltip_text(0,i)
		dictrecurse(dict[i], category)

func dictrecurse(o, dict):
	var check = {}
	if typeof(o) != typeof(check):
		if o == null: return
		var entry = menu_instance.dropdown.create_item(dict)
		entry.collapsed=true
		entry.set_text(0,o)
		entry.set_tooltip_text(0,o)
		pass
	else:
		for n in o.keys():
			if n == null: return
			var entry = menu_instance.dropdown.create_item(dict)
			entry.collapsed=true
			entry.set_text(0,n)
			entry.set_tooltip_text(0,n)
			dictrecurse(o[n], entry)
			
# ----------------------------------------------------------------------
