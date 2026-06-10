extends Node3D

## Itens adicionados à mochila (item_menu.gd) na primeira abertura do baú.
@export var item_names: Array[String] = ["Moeda de Ouro"]
@export var prompt_text: String = "[E] abrir baú"

const LID_OPEN_ANGLE := 105.0
const LID_CLOSED_ANGLE := 0.0
const LID_ANIM_SPEED := 4.0

var _player_in_range: bool = false
var _opened: bool = false
var _item_given: bool = false
var _lid_target_rotation: float = 0.0

@onready var lid: Node3D = $Lid
@onready var body: StaticBody3D = $StaticBody3D
@onready var area: Area3D = $InteractionArea
@onready var prompt_label: Label = $PromptUI/Label

## Tesouro visível ao abrir o baú, removido (e dado ao inventário) ao coletar.
@onready var treasure_meshes: Array[MeshInstance3D] = [
	$StaticBody3D/GoldBarA,
	$StaticBody3D/GoldBarB,
	$StaticBody3D/CoinA,
	$StaticBody3D/CoinB,
]

func _ready() -> void:
	prompt_label.text = prompt_text
	prompt_label.visible = false
	for mesh in treasure_meshes:
		mesh.visible = false
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	_snap_to_ground.call_deferred()

## Terreno gerado por ruído: posição fixa no editor pode ficar flutuando ou
## enterrada — raycast pra encostar a base do baú no chão (mesma técnica de
## player.gd _snap_to_ground).
func _snap_to_ground() -> void:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 80.0,
		global_position + Vector3.DOWN * 200.0
	)
	query.exclude = [body.get_rid(), area.get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return
	global_position.y = hit.position.y

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		if not _opened:
			_open()
		elif not _item_given:
			_collect()
		else:
			_close()

func _process(delta: float) -> void:
	if not is_equal_approx(lid.rotation_degrees.x, _lid_target_rotation):
		var step := LID_ANIM_SPEED * delta * 60.0
		lid.rotation_degrees.x = move_toward(lid.rotation_degrees.x, _lid_target_rotation, step)

func _on_body_entered(body: Node3D) -> void:
	if not _is_interactor(body):
		return
	_player_in_range = true
	prompt_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if not _is_interactor(body):
		return
	_player_in_range = false
	prompt_label.visible = false

func _is_interactor(body: Node3D) -> bool:
	if body.is_in_group("player"):
		return true
	if not body.is_in_group("npc_walker"):
		return false
	if "is_possessed" in body and bool(body.is_possessed):
		return true
	if "network_is_local" in body and bool(body.network_is_local):
		return true
	return false

func _open() -> void:
	_opened = true
	_lid_target_rotation = LID_OPEN_ANGLE
	if _item_given:
		prompt_label.text = "[E] fechar baú"
	else:
		for mesh in treasure_meshes:
			mesh.visible = true
		prompt_label.text = "[E] pegar item"

func _collect() -> void:
	_item_given = true
	for mesh in treasure_meshes:
		mesh.visible = false
	var menu := get_tree().get_first_node_in_group("item_menu")
	if menu != null and menu.has_method("add_item"):
		for item in item_names:
			menu.add_item(item)
	prompt_label.text = "[E] fechar baú"

func _close() -> void:
	_opened = false
	_lid_target_rotation = LID_CLOSED_ANGLE
	prompt_label.text = prompt_text
