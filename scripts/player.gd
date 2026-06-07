extends CharacterBody3D

@export_range(0.5, 30.0, 0.1) var speed: float = 5.0
@export_range(0.5, 40.0, 0.1) var sprint_speed: float = 9.0
@export_range(0.3, 10.0, 0.1) var crouch_speed: float = 2.5
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 6.5
@export_range(0.0001, 0.02, 0.0001) var mouse_sensitivity: float = 0.0025

const STANDING_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const STANDING_CAMERA_Y := 0.7
const CROUCH_CAMERA_Y := 0.3
const CROUCH_TRANSITION_SPEED := 8.0

## Distância máxima pra ver o aviso "[F] assumir personagem" e poder possuir.
const POSSESS_RANGE := 3.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Falso enquanto o jogador está "dentro" de um NPC possuído — corpo e câmera
## do jogador ficam parados, e o input vai pro NPC (ver npc_walker.gd).
var is_controlling: bool = true
var possessed_npc: CharacterBody3D = null
var nearby_npc: CharacterBody3D = null

@onready var camera: Camera3D = $Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var capsule_shape: CapsuleShape3D = collision_shape.shape.duplicate()
@onready var possess_prompt: Label = $PossessPrompt/Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	collision_shape.shape = capsule_shape
	# Terreno gerado por ruído pode ter ladeiras íngremes; o ângulo padrão de
	# chão (45°) trata isso como parede e trava o personagem. Floor snap evita
	# que pequenos ressaltos do terreno tirem o personagem do chão.
	floor_max_angle = deg_to_rad(65.0)
	floor_snap_length = 0.5
	_snap_to_ground.call_deferred()

func _snap_to_ground() -> void:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 80.0,
		global_position + Vector3.DOWN * 200.0
	)
	query.exclude = [self]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		global_position.y = 3.0
		return
	global_position.y = hit.position.y + (capsule_shape.height * 0.5) + 0.08
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if is_controlling and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("possess"):
		_toggle_possession()

## "F" perto de um NPC: assume o controle dele em terceira pessoa, congelando
## o corpo do jogador no lugar. "F" de novo: devolve a IA ao NPC (ele escolhe
## novo destino e segue andando normal) e volta pra câmera/corpo do jogador.
func _toggle_possession() -> void:
	if is_controlling:
		if nearby_npc == null:
			return
		possessed_npc = nearby_npc
		possessed_npc.start_possession()
		is_controlling = false
		camera.current = false
		possess_prompt.visible = false
		nearby_npc = null
	else:
		if possessed_npc != null:
			possessed_npc.stop_possession()
		possessed_npc = null
		is_controlling = true
		camera.current = true

func _update_possess_prompt() -> void:
	nearby_npc = null
	var nearest_distance := POSSESS_RANGE
	for npc in get_tree().get_nodes_in_group("npc_walker"):
		if npc.is_possessed:
			continue
		var distance := global_position.distance_to(npc.global_position)
		if distance <= nearest_distance:
			nearby_npc = npc
			nearest_distance = distance
	possess_prompt.visible = nearby_npc != null

func _physics_process(delta: float) -> void:
	if not is_controlling:
		return

	_update_possess_prompt()

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var crouching := Input.is_action_pressed("crouch")
	var target_height := CROUCH_HEIGHT if crouching else STANDING_HEIGHT
	var target_camera_y := CROUCH_CAMERA_Y if crouching else STANDING_CAMERA_Y
	capsule_shape.height = move_toward(capsule_shape.height, target_height, CROUCH_TRANSITION_SPEED * delta)
	collision_shape.position.y = -(STANDING_HEIGHT - capsule_shape.height) * 0.5
	camera.position.y = move_toward(camera.position.y, target_camera_y, CROUCH_TRANSITION_SPEED * delta)

	var input_dir := Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_speed := speed
	if crouching:
		current_speed = crouch_speed
	elif Input.is_action_pressed("sprint"):
		current_speed = sprint_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
