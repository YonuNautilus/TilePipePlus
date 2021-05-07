extends PopupDialog

class_name GodotExporter

signal exporter_error(message)

var current_tile_name: String
onready var resource_name_edit: LineEdit = $VBox/HBoxTileset/ResourceNameEdit
onready var current_tile_name_edit: LineEdit = $VBox/TilesPanelContainer/VBox/HBoxNewTile/LineEditName
onready var current_tile_texture_edit: LineEdit = $VBox/TilesPanelContainer/VBox/HBoxNewTile/LineEditTexture


func save_resource(path: String, tile_size: int, tile_masks: Array, 
		texture_size: Vector2, texture_path: String, tile_base_name: String, 
		tile_spacing: int):
	var output_string : String
	output_string = make_autotile_resource_data(path, tile_size, 
		tile_masks, texture_size, texture_path, tile_base_name, tile_spacing)
	var tileset_resource_path: String = path.get_basename( ) + ".tres"
	var file = File.new()
	file.open(tileset_resource_path, File.WRITE)
	file.store_string(output_string)
	file.close()

func tile_name_from_position(pos: Vector2, tile_base_name: String) -> String:
	return "%s_%d_%d" % [tile_base_name, pos.x, pos.y]

func get_godot_project_path(path: String) -> String:
	var path_array := path.get_base_dir().split("/")
	var current_test_dir: String = ""
	for dir in path_array:
		current_test_dir += dir + "/"
		var godot_project = File.new()
		if godot_project.file_exists(current_test_dir + "project.godot"):
			return current_test_dir
	return ""

func cancel_action():
	if $PopupDialog.visible:
		$PopupDialog.hide()
		_on_PopupDialog_confirmed()
	elif $ResourceFileDialog.visible:
		$ResourceFileDialog.hide()
	elif $TextureFileDialog.visible:
		$TextureFileDialog.hide()
	else:
		hide()

func report_error_inside_dialog(text: String):
	$PopupDialog.dialog_text = text
	$PopupDialog.popup_centered()
	$ColorRect.show()

# return error string 
func check_paths(resource_path: String, texture_path: String) -> bool:
	var resource_parent_project_path := get_godot_project_path(resource_path)
	var texture_parent_project_path := get_godot_project_path(texture_path)
	print(resource_parent_project_path)
	print(texture_parent_project_path)
	if resource_parent_project_path.empty():
		report_error_inside_dialog("Error: saving resource not in any Godot project path")
#		emit_signal("exporter_error", "Error: saving resource not in any Godot project path")
		return false
	if texture_parent_project_path.empty() or resource_parent_project_path != resource_parent_project_path:
		report_error_inside_dialog("Error: last saved texture is not in the same Godot project with the resource")
#		emit_signal("exporter_error", "Error: last saved texture is not in the same Godot project with the resource")
		return false
	return true

func project_export_relative_path(path: String) -> String:
	var path_array := path.get_base_dir().split("/")
	var current_test_dir: String = ""
	var project_found: bool = false
	var project_dir_index = 0
	for dir in path_array:
		current_test_dir += dir + "/"
		project_dir_index += 1
		var godot_project = File.new()
		if godot_project.file_exists(current_test_dir + "project.godot"):
			project_found = true
			break
	if project_found:
		var relative_path_array: Array = Array(path_array).slice(project_dir_index, len(path_array))
		relative_path_array.append(path.get_file())
		var relative_path: String = "res://" 
		relative_path += PoolStringArray(relative_path_array).join("/")
		return relative_path
	return ""

func make_autotile_resource_data(path: String, tile_size: int, tile_masks: Array, 
		texture_size: Vector2, texture_path: String, tile_base_name: String, 
		tile_spacing: int) -> String:
	var texture_relative_path := project_export_relative_path(texture_path)
	var out_string: String = "[gd_resource type=\"TileSet\" load_steps=3 format=2]\n"
	out_string += "\n[ext_resource path=\"%s\" type=\"Texture\" id=1]\n" % texture_relative_path
	out_string += "\n[resource]\n"
#	var texture_size: Vector2 = out_texture.texture.get_data().get_size()
	var mask_out_array: PoolStringArray = []
	for mask in tile_masks:
		mask_out_array.append("Vector2 ( %d, %d )" % [mask['position'].x, mask['position'].y])
		mask_out_array.append(mask['godot_mask'])
	out_string += "0/name = \"%s\"\n" % tile_base_name
	out_string += "0/texture = ExtResource( 1 )\n"
	out_string += "0/tex_offset = Vector2( 0, 0 )\n"
	out_string += "0/modulate = Color( 1, 1, 1, 1 )\n"
	out_string += "0/region = Rect2( 0, 0, %d, %d )\n" % [texture_size.x, texture_size.y]
	out_string += "0/tile_mode = 1\n"
	out_string += "0/autotile/bitmask_mode = 1\n"
	out_string += "0/autotile/bitmask_flags = [%s]\n" % mask_out_array.join(", ")
	out_string += "0/autotile/icon_coordinate = Vector2( 0, 0 )\n"
	out_string += "0/autotile/tile_size = Vector2( %d, %d )\n" % [tile_size, tile_size]
	out_string += "0/autotile/spacing = %d\n" % tile_spacing
	out_string += "0/autotile/occluder_map = [  ]\n"
	out_string += "0/autotile/navpoly_map = [  ]\n"
	out_string += "0/autotile/priority_map = [  ]\n"
	out_string += "0/autotile/z_index_map = [  ]\n"
	out_string += "0/occluder_offset = Vector2( 0, 0 )\n"
	out_string += "0/navigation_offset = Vector2( 0, 0 )\n"
	out_string += "0/shape_offset = Vector2( 0, 0 )\n"
	out_string += "0/shape_transform = Transform2D( 1, 0, 0, 1, 0, 0 )\n"
	out_string += "0/shape_one_way = false\n"
	out_string += "0/shape_one_way_margin = 0.0\n"
	out_string += "0/shapes = [  ]\n"
	out_string += "0/z_index = 0\n"
	return out_string

func start_export(tile_size: int, tile_masks: Array, 
		texture_size: Vector2, texture_path: String, tile_base_name: String, 
		tile_spacing: int):
	popup_centered()
	current_tile_name = tile_base_name + "_generated"
	current_tile_name_edit.text = current_tile_name


func _ready():
	$ResourceFileDialog.connect("popup_hide", $ColorRect, "hide")
	$TextureFileDialog.connect("popup_hide", $ColorRect, "hide")

func load_defaults_from_settings(data: Dictionary):
	$ResourceFileDialog.current_path = Helpers.clear_path(data["last_save_texture_resource_path"])
	resource_name_edit.text = $ResourceFileDialog.current_path
	$TextureFileDialog.current_path = Helpers.clear_path(data["last_save_texture_path"])
#	current_tile_texture_edit.text = $TextureFileDialog.current_path 

func _on_ButtonCancel_pressed():
	hide()

func _on_SelectResourceButton_pressed():
	$ResourceFileDialog.popup_centered()
	$ColorRect.show()

func _on_SelectTextureButton_pressed():
	$TextureFileDialog.popup_centered()
	$ColorRect.show()

func _on_ResourceFileDialog_file_selected(path: String):
	resource_name_edit.text = path
	var texture_path: String = path.get_base_dir() + "/" + current_tile_name + ".png"
	$TextureFileDialog.current_path = texture_path
	current_tile_texture_edit.text = texture_path

func _on_ButtonOk_pressed():
	print($ResourceFileDialog.current_path)
	print($TextureFileDialog.current_path)
	check_paths($ResourceFileDialog.current_path, $TextureFileDialog.current_path)


func _on_PopupDialog_confirmed():
	$PopupDialog.dialog_text = ""
	$ColorRect.hide()
