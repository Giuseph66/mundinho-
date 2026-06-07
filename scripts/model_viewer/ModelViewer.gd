extends Node3D

## Cena isolada de preview de modelos 3D — não toca em player/inimigos/jogo principal.
## Coloque arquivos .glb/.gltf/.fbx nas três pastas de MODEL_DIRS e rode esta cena (F6).
##
## Nota sobre FBX: alguns arquivos .fbx falham ao importar no Godot (depende do
## suporte do Assimp embutido). Se um modelo não carregar/aparecer quebrado, o
## caminho mais simples é abrir o arquivo no Blender e exportar como .glb/.gltf —
## formato com melhor suporte nativo no Godot 4.

const MODEL_DIRS: Array[String] = [
	"res://assets/models/quaternius_universal_animation_library_2/",
]
const MODEL_EXTENSIONS := ["glb", "gltf", "fbx"]

const ROTATE_SPEED := 2.0
const TARGET_HEIGHT := 1.8 # altura alvo (metros) usada para corrigir escala

@onready var spawn_point: Node3D = $SpawnPoint
@onready var name_label: Label = $UI/Panel/VBoxContainer/NameLabel
@onready var path_label: Label = $UI/Panel/VBoxContainer/PathLabel
@onready var animation_label: Label = $UI/Panel/VBoxContainer/AnimationLabel
@onready var status_label: Label = $UI/Panel/VBoxContainer/StatusLabel

var model_paths: Array[String] = []
var current_index := -1
var current_model: Node3D = null
var current_player: AnimationPlayer = null
var animation_names: Array[String] = []
var current_animation_index := -1


func _ready() -> void:
	_scan_models()
	_update_labels()

	if model_paths.is_empty():
		_show_no_models_message()
	else:
		_load_model(0)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	match key_event.physical_keycode:
		KEY_1:
			_load_model_from_dir(0)
		KEY_2:
			_load_model_from_dir(1)
		KEY_3:
			_load_model_from_dir(2)
		KEY_TAB:
			_load_next_model()
		KEY_SPACE:
			_play_next_animation()
		KEY_R:
			if current_model != null:
				current_model.rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if current_model == null:
		return
	if Input.is_physical_key_pressed(KEY_A):
		current_model.rotate_y(ROTATE_SPEED * delta)
	if Input.is_physical_key_pressed(KEY_D):
		current_model.rotate_y(-ROTATE_SPEED * delta)


# --- Descoberta de arquivos -------------------------------------------------

func _scan_models() -> void:
	model_paths.clear()
	for dir_path in MODEL_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var extension := file_name.get_extension().to_lower()
				if extension in MODEL_EXTENSIONS:
					model_paths.append(dir_path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	model_paths.sort()


# --- Carregamento de modelos -------------------------------------------------

func _load_model_from_dir(dir_index: int) -> void:
	if dir_index < 0 or dir_index >= MODEL_DIRS.size():
		return
	var prefix := MODEL_DIRS[dir_index]
	for i in model_paths.size():
		if model_paths[i].begins_with(prefix):
			_load_model(i)
			return
	_set_status("Nenhum modelo encontrado em:\n%s" % prefix)


func _load_next_model() -> void:
	if model_paths.is_empty():
		_set_status("Nenhum modelo encontrado.")
		return
	_load_model((current_index + 1) % model_paths.size())


func _load_model(index: int) -> void:
	if index < 0 or index >= model_paths.size():
		return

	var path := model_paths[index]
	var packed := load(path) as PackedScene
	if packed == null:
		_set_status("Falha ao carregar (formato não suportado?):\n%s" % path)
		return

	var instance := packed.instantiate()
	if not (instance is Node3D):
		_set_status("Cena carregada não é um modelo 3D válido:\n%s" % path)
		instance.queue_free()
		return

	_clear_current_model()

	current_model = instance as Node3D
	current_index = index
	spawn_point.add_child(current_model)

	_normalize_model(current_model)
	_find_animation_player(current_model)
	_set_status("")
	_update_labels()


func _clear_current_model() -> void:
	if current_model != null:
		current_model.queue_free()
		current_model = null
	current_player = null
	animation_names.clear()
	current_animation_index = -1


# --- Escala e posicionamento -------------------------------------------------

func _normalize_model(model: Node3D) -> void:
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	model.position = Vector3.ZERO

	var bounds := _calculate_local_aabb(model)
	if bounds.size.y > 0.001:
		var scale_factor := TARGET_HEIGHT / bounds.size.y
		model.scale = Vector3.ONE * scale_factor
		bounds = _calculate_local_aabb(model)

	# Apoia a base do modelo no chão (spawn_point já fica na superfície da base)
	# e centraliza horizontalmente sobre o ponto central.
	model.position.y -= bounds.position.y
	model.position.x -= bounds.position.x + bounds.size.x * 0.5
	model.position.z -= bounds.position.z + bounds.size.z * 0.5


func _calculate_local_aabb(model: Node3D) -> AABB:
	var combined := AABB()
	var has_bounds := false
	var stack: Array[Node] = [model]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is VisualInstance3D:
			var visual := node as VisualInstance3D
			var to_model := model.global_transform.affine_inverse() * visual.global_transform
			var transformed: AABB = to_model * visual.get_aabb()
			if has_bounds:
				combined = combined.merge(transformed)
			else:
				combined = transformed
				has_bounds = true
		for child in node.get_children():
			stack.append(child)

	return combined


# --- Animações ---------------------------------------------------------------

func _find_animation_player(model: Node) -> void:
	current_player = _search_animation_player(model)
	animation_names.clear()
	current_animation_index = -1

	if current_player == null:
		return

	for anim_name in current_player.get_animation_list():
		animation_names.append(anim_name)
	animation_names.sort()

	if not animation_names.is_empty():
		_play_animation(0)


func _search_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _search_animation_player(child)
		if found != null:
			return found
	return null


func _play_animation(index: int) -> void:
	if current_player == null or animation_names.is_empty():
		return
	current_animation_index = index % animation_names.size()
	current_player.stop()
	current_player.play(animation_names[current_animation_index])
	_update_labels()


func _play_next_animation() -> void:
	if current_player == null or animation_names.is_empty():
		_set_status("Sem animações detectadas")
		return
	_play_animation(current_animation_index + 1)


# --- Interface ----------------------------------------------------------------

func _update_labels() -> void:
	if current_index >= 0 and current_index < model_paths.size():
		var path := model_paths[current_index]
		name_label.text = "Modelo: %s" % path.get_file().get_basename()
		path_label.text = "Arquivo: %s" % path
	else:
		name_label.text = "Modelo: -"
		path_label.text = "Arquivo: -"

	if current_player != null and not animation_names.is_empty():
		var anim_name := animation_names[current_animation_index]
		animation_label.text = "Animação: %s (%d/%d)" % [anim_name, current_animation_index + 1, animation_names.size()]
	elif current_model != null:
		animation_label.text = "Animação: Sem animações detectadas"
	else:
		animation_label.text = "Animação: -"


func _set_status(text: String) -> void:
	status_label.text = text


func _show_no_models_message() -> void:
	var message := "Nenhum modelo encontrado. Coloque arquivos .glb / .gltf / .fbx em:\n"
	for dir_path in MODEL_DIRS:
		message += "  • %s\n" % dir_path
	_set_status(message)
