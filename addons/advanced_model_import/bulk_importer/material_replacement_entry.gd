@tool
class_name MaterialReplacementEntry
extends HBoxContainer

signal path_changed(entry: MaterialReplacementEntry)
signal remove_requested(entry: MaterialReplacementEntry)

@export var _mat_name_edit: LineEdit = null
@export var _mat_path_edit: LineEdit = null
@export var _set_path_button: Button = null
@export var _remove_button: Button = null

var material_name: String:
	get:
		return _material_name_value
	set(value):
		_material_name_value = value
		if is_instance_valid(_mat_name_edit):
			_mat_name_edit.text = value
var material_path: String:
	get:
		return _material_path_value
	set(value):
		_material_path_value = value
		if is_instance_valid(_mat_path_edit):
			_mat_path_edit.text = value

var _material_name_value: String = ""
var _material_path_value: String = ""
var _material_file_dialog: EditorFileDialog = null


func _ready() -> void:
	_mat_name_edit.text = material_name
	_mat_path_edit.text = material_path


func _enter_tree() -> void:
	_set_path_button.icon = BulkImporterDock.load_icon
	_remove_button.icon = BulkImporterDock.remove_icon

	_set_path_button.pressed.connect(_on_set_path_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)


func _exit_tree() -> void:
	_set_path_button.pressed.disconnect(_on_set_path_pressed)
	_remove_button.pressed.disconnect(_on_remove_pressed)

	if is_instance_valid(_material_file_dialog) \
	&& _material_file_dialog.file_selected.is_connected(_on_material_replace_file_selected):
		_material_file_dialog.file_selected.disconnect(_on_material_replace_file_selected)

#region Utilities

func setup(material_file_dialog: EditorFileDialog) -> void:
	if !is_instance_valid(_material_file_dialog):
		_material_file_dialog = material_file_dialog

#endregion

#region Signals & Callbacks

func _on_set_path_pressed() -> void:
	if !is_instance_valid(_material_file_dialog):
		return

	_material_file_dialog.file_selected.connect(_on_material_replace_file_selected)
	_material_file_dialog.confirmed.connect(_on_material_replace_file_closed)
	_material_file_dialog.canceled.connect(_on_material_replace_file_closed)
	_material_file_dialog.close_requested.connect(_on_material_replace_file_closed)

	_material_file_dialog.current_path = material_path
	_material_file_dialog.popup_centered()


func _on_remove_pressed() -> void:
	remove_requested.emit(self)


func _on_material_replace_file_closed() -> void:
	if _material_file_dialog.file_selected.is_connected(_on_material_replace_file_selected):
		_material_file_dialog.file_selected.disconnect(_on_material_replace_file_selected)
		_material_file_dialog.confirmed.disconnect(_on_material_replace_file_closed)
		_material_file_dialog.canceled.disconnect(_on_material_replace_file_closed)
		_material_file_dialog.close_requested.disconnect(_on_material_replace_file_closed)


func _on_material_replace_file_selected(path: String) -> void:
	material_path = path
	path_changed.emit(self)

#endregion
