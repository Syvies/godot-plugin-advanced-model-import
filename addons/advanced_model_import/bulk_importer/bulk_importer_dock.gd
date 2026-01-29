@tool
@static_unload
class_name BulkImporterDock
extends EditorDock

signal material_file_selected(file_path: String)

const _AVAILABLE_LAYOUTS: int = EditorDock.DockLayout.DOCK_LAYOUT_VERTICAL \
+ EditorDock.DockLayout.DOCK_LAYOUT_FLOATING
const _DEFAULT_SLOT: EditorDock.DockSlot = EditorDock.DockSlot.DOCK_SLOT_LEFT_UL
const _EDITOR_ICON: StringName = &"DirAccess"
const _LAYOUT_KEY: String = "advanced_model_import_dock"
const _FILE_DIALOG_DEFAULT_SIZE: Vector2 = Vector2(1024.0, 576.0)
const _MAT_ENTRY_SCENE_PATH: String = AdvancedModelImportPlugin.PLUGIN_DIR_PATH \
+ "bulk_importer/material_replacement_entry.tscn"
const _NO_FILE_SELECTED: String = "[color=WEB_GRAY]No File Selected[/color]"
const _VALID_EXTENSIONS: PackedStringArray = [
	"blend",
	"dae",
	"fbx",
	"glb",
	"gltf",
]

static var add_icon: Texture2D = null
static var clear_icon: Texture2D = null
static var folder_icon: Texture2D = null
static var load_icon: Texture2D = null
static var play_icon: Texture2D = null
static var remove_icon: Texture2D = null

static var _file_display_sep: String = ""

@export var _apply_button: Button = null
@export var _selected_paths_label: RichTextLabel = null
@export_group("Meshes", "_mesh_")
@export var _mesh_check: CheckBox = null
@export var _mesh_panel: PanelContainer = null
@export var _mesh_name_option: OptionButton = null
@export var _mesh_mirror_check: CheckBox = null
@export_subgroup("Path", "_mesh_path_")
@export var _mesh_path_edit: LineEdit = null
@export var _mesh_path_set_button: Button = null
@export var _mesh_path_clear_button: Button = null
@export_group("Materials", "_mat_")
@export_subgroup("Extract", "_mat_extract_")
@export var _mat_extract_check: CheckBox = null
@export var _mat_extract_panel: PanelContainer = null
@export_subgroup("Path", "_mat_extract_path_")
@export var _mat_extract_path_edit: LineEdit = null
@export var _mat_extract_path_set_button: Button = null
@export var _mat_extract_path_clear_button: Button = null
@export_subgroup("Replace", "_mat_replace_")
@export var _mat_replace_check: CheckBox = null
@export var _mat_replace_panel: PanelContainer = null
@export var _mat_replace_no_material: Label = null
@export var _mat_replace_material_container: BoxContainer = null
@export var _mat_replace_name_edit: LineEdit = null
@export var _mat_replace_add_button: Button = null
@export var _mat_replace_clear_button: Button = null

var _selected_editor_paths: PackedStringArray = PackedStringArray()
var _selected_files: PackedStringArray = PackedStringArray()
var _mesh_extract_path: String = ""
var _material_extract_path: String = ""
var _material_replace_dict: Dictionary[String, Material] = { }
var _material_entry_list: Array[MaterialReplacementEntry] = []
var _parent_container: TabContainer = null
var _material_entry_scene: PackedScene = null
var _mesh_extract_path_dialog: EditorFileDialog = null
var _material_extract_path_dialog: EditorFileDialog = null
var _material_replace_file_dialog: EditorFileDialog = null
var _confirm_reimport_dialog: ConfirmationDialog = null


static func _static_init() -> void:
	var editor_theme: Theme = EditorInterface.get_editor_theme()

	add_icon = editor_theme.get_icon(&"Add", &"EditorIcons")
	clear_icon = editor_theme.get_icon(&"Clear", &"EditorIcons")
	folder_icon = editor_theme.get_icon(&"Folder", &"EditorIcons")
	load_icon = editor_theme.get_icon(&"Load", &"EditorIcons")
	play_icon = editor_theme.get_icon(&"Play", &"EditorIcons")
	remove_icon = editor_theme.get_icon(&"Remove", &"EditorIcons")

	_file_display_sep = "\n%c " % [8226]


func _init() -> void:
	available_layouts = _AVAILABLE_LAYOUTS
	default_slot = _DEFAULT_SLOT
	dock_icon = AdvancedModelImportPlugin.ICON
	icon_name = _EDITOR_ICON
	layout_key = _LAYOUT_KEY
	title = AdvancedModelImportPlugin.TITLE

	_material_entry_scene = ResourceLoader.load(_MAT_ENTRY_SCENE_PATH, "PackedScene")

	_mesh_extract_path_dialog = EditorFileDialog.new()
	_setup_editor_file_dialog(_mesh_extract_path_dialog)
	_mesh_extract_path_dialog.file_mode = FileDialog.FileMode.FILE_MODE_OPEN_DIR

	_material_extract_path_dialog = EditorFileDialog.new()
	_setup_editor_file_dialog(_material_extract_path_dialog)
	_material_extract_path_dialog.file_mode = FileDialog.FileMode.FILE_MODE_OPEN_DIR

	_material_replace_file_dialog = EditorFileDialog.new()
	_setup_editor_file_dialog(_material_replace_file_dialog)
	_material_replace_file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE
	_material_replace_file_dialog.add_filter("*.tres,*.res,*.material", "Material Resource")

	_confirm_reimport_dialog = ConfirmationDialog.new()
	_confirm_reimport_dialog.title = "Reimport Models"
	_confirm_reimport_dialog.dialog_text = ""


func _ready() -> void:
	_apply_button.icon = play_icon
	_mesh_path_clear_button.icon = clear_icon
	_mesh_path_set_button.icon = load_icon
	_mat_extract_path_clear_button.icon = clear_icon
	_mat_extract_path_set_button.icon = load_icon
	_mat_replace_add_button.icon = add_icon
	_mat_replace_clear_button.icon = clear_icon

	_selected_paths_label.bbcode_enabled = true

	if _material_entry_list.size() == 0:
		_mat_replace_no_material.show()

	_on_mesh_toggled(_mesh_check.button_pressed)
	_on_mat_extract_toggled(_mat_extract_check.button_pressed)
	_on_mat_replace_toggled(_mat_replace_check.button_pressed)
	_check_can_apply()


func _enter_tree() -> void:
	_mesh_name_option.clear()

	for value: int in AdvancedModelImportPlugin.MeshName.values() as Array[int]:
		_mesh_name_option.add_item(
			str(AdvancedModelImportPlugin.MeshName.keys()[value]).capitalize(),
			value,
		)

	_apply_button.pressed.connect(_on_apply_pressed)
	_mesh_check.toggled.connect(_on_mesh_toggled)
	_mesh_path_set_button.pressed.connect(_mesh_extract_path_dialog.popup_centered)
	_mesh_path_clear_button.pressed.connect(_on_mesh_path_clear_pressed)
	_mat_extract_check.toggled.connect(_on_mat_extract_toggled)
	_mat_extract_path_set_button.pressed.connect(_material_extract_path_dialog.popup_centered)
	_mat_extract_path_clear_button.pressed.connect(_on_mat_extract_path_clear_pressed)
	_mat_replace_check.toggled.connect(_on_mat_replace_toggled)
	_mat_replace_add_button.pressed.connect(_on_mat_replace_add_pressed)
	_mat_replace_clear_button.pressed.connect(_on_mat_replace_clear_pressed)
	_mesh_extract_path_dialog.dir_selected.connect(_on_mesh_extract_dir_selected)
	_material_extract_path_dialog.dir_selected.connect(_on_material_extract_dir_selected)
	_confirm_reimport_dialog.confirmed.connect(_on_confirm_reimport_confirmed)

	EditorInterface.get_base_control().add_child(_mesh_extract_path_dialog)
	EditorInterface.get_base_control().add_child(_material_extract_path_dialog)
	EditorInterface.get_base_control().add_child(_material_replace_file_dialog)
	EditorInterface.get_base_control().add_child(_confirm_reimport_dialog)

	var parent: Control = get_parent_control()

	if parent is TabContainer:
		_parent_container = parent as TabContainer


func _exit_tree() -> void:
	EditorInterface.get_base_control().remove_child(_mesh_extract_path_dialog)
	EditorInterface.get_base_control().remove_child(_material_extract_path_dialog)
	EditorInterface.get_base_control().remove_child(_material_replace_file_dialog)
	EditorInterface.get_base_control().remove_child(_confirm_reimport_dialog)

	_parent_container = null

	_apply_button.pressed.disconnect(_on_apply_pressed)
	_mesh_check.toggled.disconnect(_on_mesh_toggled)
	_mesh_path_set_button.pressed.disconnect(_mesh_extract_path_dialog.popup_centered)
	_mesh_path_clear_button.pressed.disconnect(_on_mesh_path_clear_pressed)
	_mat_extract_check.toggled.disconnect(_on_mat_extract_toggled)
	_mat_extract_path_set_button.pressed.disconnect(_material_extract_path_dialog.popup_centered)
	_mat_extract_path_clear_button.pressed.disconnect(_on_mat_extract_path_clear_pressed)
	_mat_replace_check.toggled.disconnect(_on_mat_replace_toggled)
	_mat_replace_add_button.pressed.disconnect(_on_mat_replace_add_pressed)
	_mat_replace_clear_button.pressed.disconnect(_on_mat_replace_clear_pressed)
	_mesh_extract_path_dialog.dir_selected.disconnect(_on_mesh_extract_dir_selected)
	_material_extract_path_dialog.dir_selected.disconnect(_on_material_extract_dir_selected)
	_confirm_reimport_dialog.confirmed.disconnect(_on_confirm_reimport_confirmed)


func _process(_delta: float) -> void:
	if !is_inside_tree() || !is_instance_valid(_parent_container) \
	|| _parent_container.get_current_tab_control() != self:
		return

	var path_selected: PackedStringArray = EditorInterface.get_selected_paths()

	if _arrays_are_the_same(_selected_editor_paths, path_selected):
		return

	_selected_editor_paths = EditorInterface.get_selected_paths()

	if _selected_editor_paths.size() == 0:
		_selected_paths_label.text = _NO_FILE_SELECTED
		return

	_selected_files.clear()

	for path: String in _selected_editor_paths:
		var file: String = path.get_file()

		if file.is_empty():
			_selected_files.append_array(_get_valid_files_recursive(path))

		elif file.get_extension() in _VALID_EXTENSIONS:
			_selected_files.append(path)

	var file_count: int = _selected_files.size()

	if file_count == 0:
		_selected_paths_label.text = _NO_FILE_SELECTED
		return

	_selected_paths_label.text = "[b]%d[/b] %s:%s%s" % [
		file_count,
		"Selected File" if file_count == 1 else "Selected Files",
		_file_display_sep,
		_file_display_sep.join(_selected_files),
	]

#region Utilities

func _setup_editor_file_dialog(file_dailog: EditorFileDialog) -> void:
	if !is_instance_valid(file_dailog):
		printerr(
			"BulkImporterDock._setup_editor_file_dialog() - ",
			"EditorFileDialog passed is invalid.",
		)
		return

	file_dailog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	file_dailog.size = _FILE_DIALOG_DEFAULT_SIZE


func _check_can_apply() -> void:
	var is_disabled: bool = false
	var tooltips: PackedStringArray = PackedStringArray()

	if _selected_editor_paths.is_empty():
		is_disabled = true
		tooltips.append("No file or directory selected")

	if _mesh_check.button_pressed && _mesh_extract_path.is_empty():
		is_disabled = true
		tooltips.append("No path set to extract meshes")

	if _mat_extract_check.button_pressed && _material_extract_path.is_empty():
		is_disabled = true
		tooltips.append("No path set to extract materials")

	if _mat_replace_check.button_pressed:
		if _material_replace_dict.is_empty():
			is_disabled = true
			tooltips.append("No replacement material set")
		elif _material_replace_dict.values().find_custom(_check_if_not_valid) != -1:
			is_disabled = true
			tooltips.append("At least 1 replacement material is not set")

	if !_mesh_check.button_pressed && !_mat_extract_check.button_pressed \
	&& !_mat_replace_check.button_pressed:
		is_disabled = true
		tooltips.append("Select at least one option")

	_apply_button.disabled = is_disabled

	if tooltips.is_empty():
		_apply_button.tooltip_text = "Reimport the selected models"
	else:
		_apply_button.tooltip_text = "\n".join(tooltips)


func _get_valid_files_recursive(path: String) -> PackedStringArray:
	var file_list: PackedStringArray = PackedStringArray()

	if !path.is_absolute_path():
		return file_list

	var dir: DirAccess = DirAccess.open(path)

	if !is_instance_valid(dir):
		return file_list

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while !file_name.is_empty():
		if file_name == ".gdignore":
			file_list.clear()
			return file_list

		if dir.current_is_dir():
			file_list.append_array(_get_valid_files_recursive("%s%s/" % [path, file_name]))

		elif file_name.get_extension() in _VALID_EXTENSIONS:
			file_list.append("%s%s" % [path, file_name])

		file_name = dir.get_next()

	return file_list


func _check_if_not_valid(variant: Variant) -> bool:
	return !is_instance_valid(variant)


func _arrays_are_the_same(array_1: Array, array_2: Array) -> bool:
	if array_1.size() != array_2.size():
		return false

	for idx: int in array_1.size():
		if array_1[idx] != array_2[idx]:
			return false

	return true

#endregion

#region Signal

func _on_apply_pressed() -> void:
	_check_can_apply()

	if _apply_button.disabled || !is_instance_valid(_confirm_reimport_dialog):
		return

	_confirm_reimport_dialog.dialog_text = "Are you sure you want to apply the configured actions" \
	+ " to the selected models?"

	if _mesh_check.button_pressed:
		_confirm_reimport_dialog.dialog_text += "\n\nMesh names that are similar between models" \
		+ " may overwrite themselves."

	_confirm_reimport_dialog.dialog_text += "\n\nYou may need to reload the project after the" \
	+ " process is complete.\nIf the processed resources aren't behaving as expected, make sure" \
	+ " to reload."

	_confirm_reimport_dialog.popup_centered()


func _on_mesh_toggled(toggled_on: bool) -> void:
	_mesh_panel.visible = toggled_on
	_check_can_apply()


func _on_mesh_path_clear_pressed() -> void:
	_on_mesh_extract_dir_selected("")


func _on_mat_extract_toggled(toggled_on: bool) -> void:
	_mat_extract_panel.visible = toggled_on
	_check_can_apply()


func _on_mat_extract_path_clear_pressed() -> void:
	_on_material_extract_dir_selected("")


func _on_mat_replace_toggled(toggled_on: bool) -> void:
	_mat_replace_panel.visible = toggled_on
	_check_can_apply()


func _on_mat_replace_add_pressed() -> void:
	if _mat_replace_name_edit.text.is_empty():
		printerr("%s - No material name given." % [AdvancedModelImportPlugin.TITLE])
		return

	if _material_replace_dict.keys().has(_mat_replace_name_edit.text):
		printerr("%s - Material name already in the list." % [AdvancedModelImportPlugin.TITLE])
		return

	if !is_instance_valid(_material_entry_scene):
		printerr(
			"BulkImporterDock._material_entry_scene - ",
			"Invalid PackedScene.",
		)
		return

	var mat_entry_node: Node = _material_entry_scene.instantiate()

	if !is_instance_valid(mat_entry_node) || mat_entry_node is not MaterialReplacementEntry:
		printerr(
			"BulkImporterDock._material_entry_scene - ",
			"Root of the PackedScene is not MaterialReplacementEntry.",
		)
		mat_entry_node.queue_free()
		return

	var entry: MaterialReplacementEntry = mat_entry_node as MaterialReplacementEntry

	entry.setup(_material_replace_file_dialog)
	_mat_replace_material_container.add_child(entry)
	_material_entry_list.append(entry)

	entry.material_name = _mat_replace_name_edit.text
	entry.path_changed.connect(_on_mat_entry_path_changed)
	entry.remove_requested.connect(_on_mat_entry_remove_requested)

	_material_replace_dict[entry.material_name] = null
	_mat_replace_name_edit.clear()
	_mat_replace_no_material.hide()
	_check_can_apply()


func _on_mat_replace_clear_pressed() -> void:
	for entry: MaterialReplacementEntry in _material_entry_list:
		_mat_replace_material_container.remove_child(entry)
		_material_replace_dict.erase(entry.material_name)

		entry.path_changed.disconnect(_on_mat_entry_path_changed)
		entry.remove_requested.disconnect(_on_mat_entry_remove_requested)
		entry.queue_free()

	_material_entry_list.clear()
	_mat_replace_no_material.show()
	_check_can_apply()


func _on_mat_entry_path_changed(entry: MaterialReplacementEntry) -> void:
	if !_material_entry_list.has(entry) || !_material_replace_dict.has(entry.material_name):
		return

	if entry.material_path.is_absolute_path():
		var resource: Resource = ResourceLoader.load(entry.material_path)
		var mat_resource: Material = null

		if resource is Material:
			mat_resource = resource as Material

		if is_instance_valid(mat_resource):
			_material_replace_dict[entry.material_name] = mat_resource

			print("%s added." % [mat_resource.resource_path])
			_check_can_apply()
			return

		printerr(
			"%s - \"%s\" is not a Material." % [
				AdvancedModelImportPlugin.TITLE,
				entry.material_path,
			],
		)
	else:
		printerr(
			"%s - Invalid path \"%s\"." % [
				AdvancedModelImportPlugin.TITLE,
				entry.material_path,
			],
		)

	if is_instance_valid(_material_replace_dict[entry.material_name]):
		entry.material_path = _material_replace_dict[entry.material_name].resource_path
	else:
		entry.material_path = ""

	_check_can_apply()


func _on_mat_entry_remove_requested(entry: MaterialReplacementEntry) -> void:
	if !_material_entry_list.has(entry):
		return

	_mat_replace_material_container.remove_child(entry)
	_material_entry_list.erase(entry)
	_material_replace_dict.erase(entry.material_name)

	entry.path_changed.disconnect(_on_mat_entry_path_changed)
	entry.remove_requested.disconnect(_on_mat_entry_remove_requested)
	entry.queue_free()

	if _material_entry_list.size() == 0:
		_mat_replace_no_material.show()

	_check_can_apply()


func _on_mesh_extract_dir_selected(dir: String) -> void:
	_mesh_extract_path = dir
	_mesh_path_edit.text = dir
	_check_can_apply()


func _on_material_extract_dir_selected(dir: String) -> void:
	_material_extract_path = dir
	_mat_extract_path_edit.text = dir
	_check_can_apply()


func _on_confirm_reimport_confirmed() -> void:
	if _selected_files.is_empty() || _selected_editor_paths.is_empty() \
	|| _selected_editor_paths[0].is_empty():
		return

	var source_path: String = _selected_editor_paths[0].get_base_dir()
	var material_list: Dictionary[String, String] = { }

	for material_name: String in _material_replace_dict.keys() as Array[String]:
		material_list[material_name] = _material_replace_dict[material_name].resource_path

	var options: Dictionary = {
		AdvancedModelImportPlugin.KEY_MESH_EXTRACT: _mesh_check.button_pressed,
		AdvancedModelImportPlugin.KEY_MESH_EXTRACT_NAME: _mesh_name_option.get_selected_id(),
		AdvancedModelImportPlugin.KEY_MESH_EXTRACT_MIRROR: _mesh_mirror_check.button_pressed,
		AdvancedModelImportPlugin.KEY_MESH_EXTRACT_SOURCE_PATH: source_path,
		AdvancedModelImportPlugin.KEY_MESH_EXTRACT_PATH: _mesh_extract_path,
		AdvancedModelImportPlugin.KEY_MATERIAL_EXTRACT: _mat_extract_check.button_pressed,
		AdvancedModelImportPlugin.KEY_MATERIAL_EXTRACT_PATH: _material_extract_path,
		AdvancedModelImportPlugin.KEY_MATERIAL_REPLACE: _mat_replace_check.button_pressed,
		AdvancedModelImportPlugin.KEY_MATERIAL_REPLACE_LIST: material_list,
	}

	AdvancedModelImportPlugin.apply_reimport(_selected_files, options)

#endregion
