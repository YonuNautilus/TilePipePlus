extends Control

signal input_image_processed()

const INPUT_COONTAINER_DEFAULT_SIZE := Vector2(192, 192)

onready var texture_file_dialog: FileDialog = $TextureDialog
onready var template_file_dialog: FileDialog = $TemplateDialog
onready var save_file_dialog: FileDialog = $SaveTextureDialog
onready var save_resource_dialog: FileDialog = $SaveTextureResourceDialog

onready var texture_in_container: Control = $Panel/HBox/Images/InContainer/VBoxInput/Control
onready var texture_in: TextureRect = texture_in_container.get_node("InputTextureRect")
onready var texture_input_bg: TextureRect = texture_in_container.get_node("BGTextureRect")
onready var generation_type_select: OptionButton = $Panel/HBox/Images/InContainer/VBoxInput/InputType

onready var corners_merge_container: VBoxContainer = $Panel/HBox/Images/InContainer/MarginContainer/CornersMergeSettings
onready var corners_merge_type_select: OptionButton = corners_merge_container.get_node("CornersOptionButton")
onready var overlay_merge_container: VBoxContainer = $Panel/HBox/Images/InContainer/MarginContainer/OverlaySettings
onready var overlay_merge_type_select: OptionButton = overlay_merge_container.get_node("OverlayOptionButton")
onready var color_process_select: OptionButton = overlay_merge_container.get_node("ColorProcessType")

onready var slice_viewport: Viewport = $Panel/HBox/Images/InContainer/VBoxViewport/ViewportContainer/Viewport
onready var texture_in_viewport: TextureRect = slice_viewport.get_node("TextureRect")
onready var slice_slider: HSlider = $Panel/HBox/Images/InContainer/VBoxViewport/HBoxContainer/HSlider

onready var debug_input_scroll: Control = $Panel/HBox/Images/InContainer/DebugTextureContainer
onready var debug_input_control: Control = debug_input_scroll.get_node("Control")
onready var debug_input_texture: TextureRect = debug_input_control.get_node("DebugTexture")
onready var debug_input_texture_bg: TextureRect = debug_input_control.get_node("BGTextureRect")

onready var template_load_button : Button = $Panel/HBox/Images/TemplateContainer/ButtonBox/TemplateButton
onready var template_type_select: OptionButton = $Panel/HBox/Images/TemplateContainer/ButtonBox/TemplateOption
onready var template_texture: TextureRect = $Panel/HBox/Images/TemplateContainer/ScrollContainer/TemplateTextureRect

onready var output_scroll: ScrollContainer = $Panel/HBox/Images/OutputContainer/ScrollContainer
onready var output_control: Control = output_scroll.get_node("Control")
onready var out_texture: TextureRect = output_scroll.get_node("Control/OutTextureRect")
onready var out_bg_texture: TextureRect = output_scroll.get_node("Control/BGTextureRect")

onready var output_size_select: OptionButton = $Panel/HBox/Settings/SizeOptionButton
onready var export_type_select: CheckButton = $Panel/HBox/Settings/Resourse/AutotileSelect
onready var description_select_box: HBoxContainer = $Panel/HBox/Settings/DescriptionResourse
onready var export_manual_resource_type_select: CheckButton = $Panel/HBox/Settings/DescriptionResourse/Select


var generation_data: GenerationData

export var is_godot_plugin: bool = false

var template_size: Vector2
var input_slices: Dictionary = {}
var input_tile_size_vector := Vector2.ZERO
var input_overlayed: Dictionary = {}
# tile_masks = [{"mask": int, "godot_mask": int, "position" Vector2}, ...]
var tile_masks: Array = []

func _ready():
#	save_settings(true) # uncomment on change of save file structure
	connect("input_image_processed", self, "make_output_texture")
	output_size_select.clear()
	for size in Const.OUTPUT_SIZES:
		output_size_select.add_item(Const.OUTPUT_SIZES[size])
	for type in Const.COLOR_PROCESS_TYPES:
		color_process_select.add_item(Const.COLOR_PROCESS_TYPE_NAMES[Const.COLOR_PROCESS_TYPES[type]])
	for type in Const.INPUT_TYPES:
		generation_type_select.add_item(Const.INPUT_TYPE_NAMES[Const.INPUT_TYPES[type]])
#	setup_input_type(Const.DEFAULT_INPUT_TYPE)
	for type in Const.TEMPLATE_TYPES:
		template_type_select.add_item(Const.TEMPLATE_TYPE_NAMES[Const.TEMPLATE_TYPES[type]])
	for index in Const.CORNERS_INPUT_PRESETS:
		corners_merge_type_select.add_item(Const.CORNERS_INPUT_PRESETS_NAMES[Const.CORNERS_INPUT_PRESETS[index]])
	for index in Const.OVERLAY_INPUT_PRESETS:
		overlay_merge_type_select.add_item(Const.OVERLAY_INPUT_PRESET_NAMES[Const.OVERLAY_INPUT_PRESETS[index]])
	load_settings()
	generate_tile_masks()
	preprocess_input_image()

func _process(_delta: float):
	if Input.is_action_just_pressed("ui_cancel"):
		_on_CloseButton_pressed()

var last_generator_preset_path: String = ""
func get_generator_preset_path() -> String:
	var path: String = ""
	match generation_type_select.selected:
		Const.INPUT_TYPES.CORNERS:
			var corner_preset: int = corners_merge_type_select.selected
			path = Const.CORNERS_INPUT_PRESETS_DATA_PATH[corner_preset]
		Const.INPUT_TYPES.OVERLAY:
			var overlay_preset: int = overlay_merge_type_select.selected
			path = Const.OVERLAY_INPUT_PRESETS_DATA_PATH[overlay_preset]
	return path

var custom_template_path: String = ""
func get_template_path() -> String:
	if custom_template_path != "":
		return custom_template_path
	else:
		return Const.TEMPLATE_47_PATH

func capture_setting_values() -> Dictionary:
	return {
		"last_texture_path": texture_file_dialog.current_path,
		"last_gen_preset_path": get_generator_preset_path(),
		"last_template_path": get_template_path(),
		"last_save_texture_path": save_file_dialog.current_path,
		"last_save_texture_resource_path": save_resource_dialog.current_path,
		"output_tile_size": get_output_tile_size(),
		"input_type": generation_type_select.selected,
		"corner_preset": corners_merge_type_select.selected,
		"overlay_preset": overlay_merge_type_select.selected
	}

func save_settings(store_defaults: bool = false):
	var save = File.new()
	save.open(Const.SETTINGS_PATH, File.WRITE)
	var data := Const.DEFAULT_SETTINGS
	if not store_defaults:
		data = capture_setting_values() 
	save.store_line(to_json(data))
	save.close()

func apply_settings(data: Dictionary):
	texture_file_dialog.current_path = data["last_texture_path"]
	texture_in.texture = load_image_texture(data["last_texture_path"])
	resize_input_container()
	generation_data = GenerationData.new(data["last_gen_preset_path"])
	template_file_dialog.current_path = data["last_template_path"]
	template_texture.texture = load_image_texture(data["last_template_path"])
	save_file_dialog.current_path = data["last_save_texture_path"]
	save_resource_dialog.current_path = data["last_save_texture_resource_path"]
	output_size_select.selected = Const.OUTPUT_SIZES.keys().find(int(data["output_tile_size"]))
	generation_type_select.selected = data["input_type"]
	corners_merge_type_select.selected = data["corner_preset"]
	overlay_merge_type_select.selected = data["overlay_preset"]
	setup_input_type(generation_type_select.selected)
	update_output_bg_texture_scale()
	
func setting_exist() -> bool:
	var save = File.new()
	return save.file_exists(Const.SETTINGS_PATH)

func load_settings():
	if not setting_exist():
		save_settings(true)
	var save = File.new()
	save.open(Const.SETTINGS_PATH, File.READ)
	var save_data: Dictionary = parse_json(save.get_line())
	apply_settings(save_data)
	save.close()

func check_input_texture() -> bool:
	if not is_instance_valid(texture_in.texture):
		return false
	return true

func check_template_texture() -> bool:
	if not is_instance_valid(template_texture.texture):
		return false
	var template_image_size: Vector2 = template_texture.texture.get_data().get_size()
	if template_image_size.x < Const.TEMPLATE_TILE_SIZE and template_image_size.y < Const.TEMPLATE_TILE_SIZE:
		return false
	return true

func compute_template_size() -> Vector2:
	var template_image: Image = template_texture.texture.get_data()
	return template_image.get_size() / Const.TEMPLATE_TILE_SIZE

func get_template_mask_value(template_image: Image, x: int, y: int, 
		mask_check_points: Dictionary = Const.TEMPLATE_MASK_CHECK_POINTS) -> int:
	var mask_value: int = 0
	template_image.lock()
	for mask in mask_check_points:
		var pixel_x: int = x * Const.TEMPLATE_TILE_SIZE + mask_check_points[mask].x
		var pixel_y: int = y *Const.TEMPLATE_TILE_SIZE + mask_check_points[mask].y
		if not template_image.get_pixel(pixel_x, pixel_y).is_equal_approx(Color.white):
			mask_value += mask
	template_image.unlock()
	return mask_value

func clear_generation_mask():
	tile_masks = []
	for label in template_texture.get_children():
		label.queue_free()

func mark_template_tile(mask_value: int, mask_position: Vector2, is_text: bool = false):
	if is_text:
		var mask_text_label := Label.new()
		mask_text_label.add_color_override("font_color", Color(0, 0.05, 0.1))
		mask_text_label.text = str(mask_value)
		mask_text_label.rect_position = mask_position * Const.TEMPLATE_TILE_SIZE + Vector2(5, 5)
		template_texture.add_child(mask_text_label)
	else:
		for x in range(3):
			for y in range(3):
				var check: int = 1 << (x + y*3)
				if check & mask_value == check:
					var mask_marker = TextureRect.new()
					mask_marker.texture = preload("res://template_marker.png")
					mask_marker.rect_position = mask_position * Const.TEMPLATE_TILE_SIZE + \
						Vector2(x * 10.6 + 1, y * 10.6 + 1)
					template_texture.add_child(mask_marker)


		

func generate_tile_masks():
	clear_generation_mask()
	if not check_template_texture():
		print("WRONG template texture")
		return
	template_size = compute_template_size()
	var template_image: Image = template_texture.texture.get_data()
	for x in range(template_size.x):
		for y in range(template_size.y):
			var mask_value: int = get_template_mask_value(template_image, x, y) 
			var godot_mask_value: int = get_template_mask_value(template_image, x, y, Const.GODOT_MASK_CHECK_POINTS)
			tile_masks.append({"mask": mask_value, "position": Vector2(x, y), "godot_mask": godot_mask_value })
#			mark_template_tile(godot_mask_value, Vector2(x, y), true)
			mark_template_tile(godot_mask_value, Vector2(x, y), false)

func put_to_viewport(slice: Image, rotation_key: int, color_process: int,
		is_flipped := false):
	var flip_x := false
	var flip_y := false
	if is_flipped:
		if rotation_key in Const.FLIP_HORIZONTAL_KEYS:
			flip_x = true
		else:
			flip_y = true
	var rotation_angle: float = Const.ROTATION_SHIFTS[rotation_key]['angle']
	var itex = ImageTexture.new()
	itex.create_from_image(slice)
	texture_in_viewport.texture = itex
	texture_in_viewport.material.set_shader_param("rotation", -rotation_angle)
	texture_in_viewport.material.set_shader_param("is_flipped_x", flip_x)
	texture_in_viewport.material.set_shader_param("is_flipped_y", flip_y)
	var is_flow_map: bool = color_process == Const.COLOR_PROCESS_TYPES.FLOW_MAP
	texture_in_viewport.material.set_shader_param("is_flow_map", is_flow_map)

func get_from_viewport(image_fmt: int, resize_factor: float = 1.0) -> Image:
	var image := Image.new()
	var size: Vector2 = texture_in_viewport.texture.get_size()
	image.create(int(size.x), int(size.y), false, image_fmt)
	image.blit_rect(
		slice_viewport.get_texture().get_data(),
		Rect2(Vector2.ZERO, size), 
		Vector2.ZERO)
	if resize_factor != 1.0:
		image.resize(int(size.x * resize_factor), int(size.y * resize_factor))
	return image

func get_color_process() -> int:
	return color_process_select.selected

func append_to_debug_image(debug_image: Image, slice_image: Image, slice_size: int, slice_position: Vector2):
	debug_image.blit_rect(
		slice_image,
		Rect2(0, 0, slice_size, slice_size), 
		slice_position
	)
	var itex = ImageTexture.new()
	itex.create_from_image(debug_image)
	debug_input_texture.texture = itex

func set_input_tile_size(input_tile_size: int, input_image: Image):
	input_tile_size_vector = Vector2(input_tile_size, input_tile_size)
	var input_scale_factor: float = float(input_tile_size) / float(Const.DEFAULT_OUTPUT_SIZE)
	var input_scale := Vector2(input_scale_factor, input_scale_factor)
	var input_size = input_image.get_size()
	texture_in_container.rect_size.x = max(input_size.x, INPUT_COONTAINER_DEFAULT_SIZE.x)
	texture_in_container.rect_size.y = max(input_size.y, INPUT_COONTAINER_DEFAULT_SIZE.y)
	texture_input_bg.rect_size = texture_in_container.rect_size / input_scale_factor
	texture_input_bg.rect_scale = input_scale
	texture_in_container.get_node("TileSizeLabel").text = "%sx%s" % [input_tile_size, input_tile_size]

func generate_corner_slices():
	input_slices = {}
	var output_tile_size: int = get_output_tile_size()
	var input_image: Image = texture_in.texture.get_data()
	var min_input_slices: Vector2 = generation_data.get_min_input_size()
	var input_slice_size: int = int(input_image.get_size().x / min_input_slices.x)
	set_input_tile_size(input_slice_size * 2, input_image)
	var output_slice_size: int = int(output_tile_size / 2.0)
	var resize_factor: float = float(output_slice_size) / float(input_slice_size)
	var new_viewport_size := Vector2(input_slice_size, input_slice_size)
	if slice_viewport.size != new_viewport_size:
		slice_viewport.size = new_viewport_size
		texture_in_viewport.rect_size = new_viewport_size
	var image_input_fmt: int = input_image.get_format()
	var image_fmt: int = slice_viewport.get_texture().get_data().get_format()
	var debug_image := Image.new()
	var color_process: int = get_color_process()
	var debug_texture_size: Vector2 = get_debug_image_rect_size(Const.INPUT_TYPES.CORNERS)
	debug_image.create(int(debug_texture_size.x), int(debug_texture_size.y), false, image_fmt)
	for x in range(min_input_slices.x):
		input_slices[x] = {}
		var slice := Image.new()
		slice.create(input_slice_size, input_slice_size, false, image_input_fmt)
		slice.blit_rect(input_image, Rect2(x * input_slice_size, 0, input_slice_size, input_slice_size), Vector2.ZERO)
		for rot_index in Const.ROTATION_SHIFTS.size():
			var rotation_key: int = Const.ROTATION_SHIFTS.keys()[rot_index]
			put_to_viewport(slice, rotation_key, color_process, false)
			yield(VisualServer, 'frame_post_draw')
			var processed_slice: Image = get_from_viewport(image_fmt, resize_factor)
			append_to_debug_image(debug_image, processed_slice, output_slice_size, 
				Vector2(x * output_slice_size, 2 * rot_index * output_slice_size))
			put_to_viewport(slice, rotation_key, color_process, true)
			yield(VisualServer, 'frame_post_draw')
			var processed_flipped_slice : Image = get_from_viewport(image_fmt, resize_factor)
			append_to_debug_image(debug_image, processed_flipped_slice, output_slice_size, 
				Vector2(x * output_slice_size, (2 * rot_index + 1) * output_slice_size))
			input_slices[x][rotation_key] = {
				false: processed_slice, 
				true: processed_flipped_slice
			}
	texture_in_viewport.hide()
	emit_signal("input_image_processed")

func generate_overlayed_tiles():
	input_slices = {}
	var output_tile_size: int = get_output_tile_size()
	var input_image: Image = texture_in.texture.get_data()
	var min_input_tiles: Vector2 = generation_data.get_min_input_size()
	var input_tile_size: int = int(input_image.get_size().x / min_input_tiles.x)
#
#	print(min_input_tiles, input_tile_size)
	set_input_tile_size(input_tile_size, input_image)
	var resize_factor: float = float(output_tile_size) / float(input_tile_size)
	var new_viewport_size := Vector2(input_tile_size, input_tile_size)
	if slice_viewport.size != new_viewport_size:
		slice_viewport.size = new_viewport_size
		texture_in_viewport.rect_size = new_viewport_size
	var image_input_fmt: int = input_image.get_format()
	var image_fmt: int = slice_viewport.get_texture().get_data().get_format()
	var debug_image := Image.new()
	var color_process: int = get_color_process()
	var debug_texture_size: Vector2 = get_debug_image_rect_size(Const.INPUT_TYPES.OVERLAY) * 2
	debug_image.create(int(debug_texture_size.x), int(debug_texture_size.y), false, image_fmt)
	for x in range(min_input_tiles.x):
		for rot_index in Const.ROTATION_SHIFTS.size():
			input_slices[x] = {}
			var slice := Image.new()
			slice.create(input_tile_size, input_tile_size, false, image_input_fmt)
	#		print(Rect2(x * input_tile_size, 0, input_tile_size, input_tile_size), Vector2(x * input_tile_size, 0))
			slice.blit_rect(input_image, Rect2(x * input_tile_size, 0, input_tile_size, input_tile_size), Vector2.ZERO)
			append_to_debug_image(debug_image, slice, output_tile_size, Vector2(x * input_tile_size, rot_index * input_tile_size))

	
	
	emit_signal("input_image_processed")

func preprocess_input_image():
	texture_in_viewport.show()
	if not check_input_texture():
		print("WRONG input texture")
		return
	debug_input_texture.texture = null
	var generation_type: int = generation_type_select.selected
	match generation_type:
		Const.INPUT_TYPES.CORNERS:
			generate_corner_slices()
		Const.INPUT_TYPES.OVERLAY:
			generate_overlayed_tiles()

func get_output_tile_size() -> int:
	return Const.OUTPUT_SIZES.keys()[output_size_select.selected]

func make_from_corners():
	if input_slices.size() == 0:
		set_output_texture(null)
		return
	var tile_size: int = get_output_tile_size()
	# warning-ignore:integer_division
	var slice_size: int = int(tile_size) / 2
	var image_fmt: int = input_slices[0][0][true].get_format()
	var slice_rect := Rect2(0, 0, slice_size, slice_size)
	var out_image := Image.new()
	out_image.create(tile_size * int(template_size.x), tile_size * int(template_size.y), false, image_fmt)
	var preset: Array = generation_data.get_preset()
	for mask in tile_masks:
		var tile_position: Vector2 = mask['position'] * tile_size
		if mask["godot_mask"] != 0: # don't draw only center
			for place_mask in preset:
				var allowed_rotations: Array = get_allowed_mask_rotations(
						place_mask["in_mask"]["positive"], 
						place_mask["in_mask"]["negative"], 
						mask['mask'],
						place_mask["rotation_offset"])
				for rotation in allowed_rotations:
					var out_tile = place_mask["out_tile"]
					var is_flipped: bool = out_tile["flip"]
					var slice_index: int = out_tile["index"]
					var slice_image: Image = input_slices[slice_index][rotation][is_flipped]
					var init_rotation: int = rotate_cw(rotation, place_mask["rotation_offset"])
					var intile_offset : Vector2 = Const.ROTATION_SHIFTS[init_rotation]["vector"] * slice_size
					if is_flipped: 
						intile_offset = Const.ROTATION_SHIFTS[rotate_cw(init_rotation)]["vector"] * slice_size
					out_image.blit_rect(slice_image, slice_rect, tile_position + intile_offset)
	var itex = ImageTexture.new()
	itex.create_from_image(out_image)
	set_output_texture(itex)

func set_output_texture(texture: Texture):
	out_texture.texture = texture
	if texture != null:
		var image_size: Vector2 = out_texture.texture.get_data().get_size()
		out_texture.rect_size = image_size
		output_control.rect_min_size = image_size
	else:
		output_control.rect_min_size = Vector2.ZERO

func make_from_overlayed():
	if input_overlayed.size() == 0:
		set_output_texture(null)
		return

func make_output_texture():
	var generation_type: int = generation_type_select.selected
	set_output_texture(null)
	match generation_type:
		Const.INPUT_TYPES.CORNERS:
			make_from_corners()
		Const.INPUT_TYPES.OVERLAY:
			make_from_overlayed()
	
func rotate_ccw(in_rot: int, quarters: int = 1) -> int:
	var out: int = int(clamp(in_rot, 0, 6)) - 2 * quarters
	out = out % 8
	if out < 0:
		out = 8 + out
	return out
	
func rotate_cw(in_rot: int, quarters: int = 1) -> int:
	var out: int = int(clamp(in_rot, 0, 6)) + 2 * quarters
	out = out % 8
	return out

func rotate_check_mask(mask: int, rot: int) -> int:
	var rotated_check: int = mask << rot
	if rotated_check > 255:
		var overshoot: int = rotated_check >> 8
		rotated_check ^= overshoot << 8
		rotated_check |= overshoot
	return rotated_check

# returns all rotations for mask which satisfy both templates
#func check_mask_template(pos_check_mask: int, neg_check_mask: int, current_mask: int) -> Array:
# quarters_offset - это количество поворотов на 90 от квадрата (0,0) для положения на картинке (если как на картинке ставим налево вверх, то 0)
func get_allowed_mask_rotations(pos_check_mask: int, neg_check_mask: int, current_mask: int, quarters_offset: int = 0) -> Array:
	var rotations: Array = []
	for rotation in Const.ROTATION_SHIFTS:
		var rotated_check: int = rotate_check_mask(pos_check_mask, rotation)
		var satisfies_check := false
		if current_mask & rotated_check == rotated_check:
			satisfies_check = true
		if satisfies_check and neg_check_mask != 0: # check negative mask
			rotated_check = rotate_check_mask(neg_check_mask, rotation)
			var inverted_check: int = (~rotated_check & 0xFF)
#			print("%s: %s %s %s" % [str(rotation), str(rotated_check), 
#				str(inverted_check),
#				str(current_mask & inverted_check)])
			if current_mask | inverted_check != inverted_check:
				satisfies_check = false
		if satisfies_check:
			rotations.append(rotation)
	return rotations

func _on_CloseButton_pressed():
	tile_masks.empty()
	get_tree().quit()

func _on_Save_pressed():
	save_file_dialog.popup_centered()

func _on_Save2_pressed():
	save_resource_dialog.popup_centered()

func load_image_texture(path: String) -> Texture:
	if path.begins_with("res://"):
		var texture: Texture = load(path)
		return texture
	else:
		var image = Image.new()
		var err = image.load(path)
		if(err != 0):
			print("Error loading the image: " + path)
			return null
		var image_texture = ImageTexture.new()
		image_texture.create_from_image(image)
		return image_texture

func resize_input_container():
	var prev_min_input_width: float = texture_in_container.rect_min_size.x
	texture_in_container.rect_min_size = texture_in.texture.get_data().get_size()
	var texture_width_increase: float = texture_in_container.rect_min_size.x - prev_min_input_width
	if texture_width_increase > 0:
		debug_input_control.rect_size.x -= texture_width_increase
		debug_input_scroll.rect_min_size.x = debug_input_control.rect_size.x
	
func _on_TextureDialog_file_selected(path):
	texture_in.texture = load_image_texture(path)
	resize_input_container()
	preprocess_input_image()
	save_settings()

func _on_TemplateDialog_file_selected(path):
	custom_template_path = path
	template_texture.texture = load_image_texture(path)
	generate_tile_masks()
	make_output_texture()
	save_settings()

func _on_TemplateButton_pressed():
	template_file_dialog.popup_centered()

func _on_Button_pressed():
	texture_file_dialog.popup_centered()

func save_texture_png(path: String):
	out_texture.texture.get_data().save_png(path)

func _on_SaveTextureDialog_file_selected(path):
	save_texture_png(path)
	save_settings()

func _on_SaveTextureDialog2_file_selected(path: String):
#	save_texture_png(path)
	var resource_exporter: GodotExporter = GodotExporter.new()
	resource_exporter.save_resource(path, get_output_tile_size(), tile_masks,
		export_type_select.pressed, 
		out_texture.texture.get_data().get_size(),
		export_manual_resource_type_select.pressed
	)
	save_settings()

func _on_AutotileSelect_toggled(button_pressed):
	if is_godot_plugin:
		description_select_box.visible = not button_pressed

func setup_input_type(index: int):
	match index:
		Const.INPUT_TYPES.CORNERS:
			overlay_merge_container.hide()
			corners_merge_container.show()
			color_process_select.disabled = true
			color_process_select.selected = Const.COLOR_PROCESS_TYPES.NO
			set_corner_generation_data(corners_merge_type_select.selected)
		Const.INPUT_TYPES.OVERLAY:
			corners_merge_container.hide()
			overlay_merge_container.show()
			color_process_select.disabled = false
			set_overlay_generation_data(overlay_merge_type_select.selected)
	
func _on_InputType_item_selected(index):
	setup_input_type(index)
	preprocess_input_image()
	save_settings()

func _on_ColorProcessType_item_selected(index):
	preprocess_input_image()
	save_settings()

func _on_ReloadButton_pressed():
	texture_in.texture = load_image_texture(texture_file_dialog.current_path)
	resize_input_container()
	preprocess_input_image()

func _on_TemplateOption_item_selected(index):
	if index == Const.TEMPLATE_TYPES.CUSTOM:
		template_load_button.disabled = false
		template_texture.texture = null
		template_texture.rect_size = Vector2.ZERO
		output_scroll.get_v_scrollbar().rect_size.x = 0
		output_scroll.get_v_scrollbar().rect_size.y = 0
		clear_generation_mask()
	else:
		template_load_button.disabled = true
		template_texture.texture = load_image_texture(Const.TEMPLATE_PATHS[index])
		generate_tile_masks()
	make_output_texture()
	save_settings()

func set_corner_generation_data(index: int):
	last_generator_preset_path = Const.CORNERS_INPUT_PRESETS_DATA_PATH[index]
	generation_data = GenerationData.new(last_generator_preset_path)
#	match index:
#		Const.CORNERS_INPUT_PRESETS.FIVE:
#			last_generator_preset_path = Const.CORNERS_INPUT_PRESETS_DATA_PATH[Const.CORNERS_INPUT_PRESETS.FIVE]
#			generation_data = GenerationData.new(last_generator_preset_path)
#		Const.CORNERS_INPUT_PRESETS.FOUR:
#			last_generator_preset_path = Const.CORNERS_INPUT_PRESETS_DATA_PATH[Const.CORNERS_INPUT_PRESETS.FOUR]
#			generation_data = GenerationData.new(last_generator_preset_path)

func _on_CornersOptionButton_item_selected(index):
	set_corner_generation_data(index)
	preprocess_input_image()
	save_settings()

func set_overlay_generation_data(index: int):
	last_generator_preset_path = Const.OVERLAY_INPUT_PRESETS_DATA_PATH[index]
	generation_data = GenerationData.new(last_generator_preset_path)
#
#	match index:
#		Const.OVERLAY_INPUT_PRESETS.TOP_DOWN_2:
#			pass
#		Const.OVERLAY_INPUT_PRESETS.TOP_DOWN_3:
#			pass
#		Const.OVERLAY_INPUT_PRESETS.TOP_DOWN_4:
#			pass

func _on_OverlayOptionButton_item_selected(index):
	set_overlay_generation_data(index)
	preprocess_input_image()
	save_settings()

func get_debug_image_rect_size(input_type: int) -> Vector2:
	var output_tile_size: int = get_output_tile_size()
	var size := Vector2.ZERO
	match input_type:
		Const.INPUT_TYPES.CORNERS:
			# warning-ignore:integer_division
			var slice_size: int = output_tile_size / 2
			var min_size: Vector2 = generation_data.get_min_input_size()
			size.x = slice_size * min_size.x
			size.y = slice_size * min_size.y * 8
		Const.INPUT_TYPES.OVERLAY:
			var min_size: Vector2 = generation_data.get_min_input_size()
			size.x = min_size.x * input_tile_size_vector.x
			size.y = min_size.y * input_tile_size_vector.y * 4
	return size

func update_output_bg_texture_scale():
	var tile_size: int = get_output_tile_size()
	var output_scale_factor: float = float(tile_size) / float(Const.DEFAULT_OUTPUT_SIZE)
	var output_scale := Vector2(output_scale_factor, output_scale_factor)
	out_bg_texture.rect_scale = output_scale
	out_bg_texture.rect_size = output_control.rect_size / output_scale_factor
	output_control.get_node("TileSizeLabel").text = Const.OUTPUT_SIZES[tile_size]
	debug_input_control.rect_min_size = get_debug_image_rect_size(Const.INPUT_TYPES.CORNERS)
	debug_input_texture_bg.rect_scale = output_scale
	debug_input_texture_bg.rect_size = debug_input_control.rect_size / output_scale_factor
	debug_input_control.get_node("TileSizeLabel").text = Const.OUTPUT_SIZES[tile_size]

func _on_SizeOptionButton_item_selected(index):
	update_output_bg_texture_scale()
	preprocess_input_image()
	save_settings()
