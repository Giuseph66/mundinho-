extends CharacterBody3D

@export_range(0.5, 30.0, 0.1) var speed: float = 5.0
@export_range(0.5, 40.0, 0.1) var sprint_speed: float = 9.0
@export_range(0.3, 10.0, 0.1) var crouch_speed: float = 2.5
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 6.5
@export_range(0.0001, 0.02, 0.0001) var mouse_sensitivity: float = 0.0025
@export_range(8.0, 80.0, 0.5) var top_down_height: float = 28.0
@export_range(2.0, 120.0, 0.5) var top_down_zoom: float = 22.0
@export_range(0.5, 30.0, 0.5) var top_down_zoom_step: float = 3.0
@export var start_top_down: bool = false
@export var start_fullscreen: bool = true

const STANDING_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const STANDING_CAMERA_Y := 0.7
const CROUCH_CAMERA_Y := 0.3
const CROUCH_TRANSITION_SPEED := 8.0

## Distância máxima pra ver o aviso "[F] assumir personagem" e poder possuir.
const POSSESS_RANGE := 3.0
const NETWORK_NONE := 0
const NETWORK_SERVER := 1
const NETWORK_CLIENT_LOCAL := 2
const NETWORK_CLIENT_REMOTE := 3

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Falso enquanto o jogador está "dentro" de um NPC possuído — corpo e câmera
## do jogador ficam parados, e o input vai pro NPC (ver npc_walker.gd).
var is_controlling: bool = true
var possessed_npc: CharacterBody3D = null
var nearby_npc: CharacterBody3D = null
var top_down_enabled: bool = false
var hp: int = 5
var damage_cooldown: float = 0.0
var network_mode := NETWORK_NONE
var network_peer_id := 0
var network_is_local := false
var network_headless := false

@onready var camera: Camera3D = $Camera3D
@onready var top_down_camera: Camera3D = $TopDownCamera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var capsule_shape: CapsuleShape3D = collision_shape.shape.duplicate()
@onready var possess_prompt: Label = $PossessPrompt/Label

func _ready() -> void:
	if not _ensure_runtime_nodes():
		return
	var headless := network_headless or _is_headless_server()
	if start_fullscreen and not Engine.is_editor_hint() and not headless:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if not headless and (network_mode == NETWORK_NONE or network_is_local):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	collision_shape.shape = capsule_shape
	top_down_enabled = start_top_down
	_update_top_down_camera()
	_apply_camera_mode()
	if network_mode != NETWORK_NONE:
		_apply_network_setup()
	# Terreno gerado por ruído pode ter ladeiras íngremes; o ângulo padrão de
	# chão (45°) trata isso como parede e trava o personagem. Floor snap evita
	# que pequenos ressaltos do terreno tirem o personagem do chão.
	floor_max_angle = deg_to_rad(65.0)
	floor_snap_length = 0.5
	if network_mode == NETWORK_NONE or network_mode == NETWORK_SERVER:
		_snap_to_ground.call_deferred()

func configure_network(peer_id: int, mode: int, local_view: bool, headless: bool = false) -> void:
	network_peer_id = peer_id
	network_mode = mode
	network_is_local = local_view
	network_headless = headless
	top_down_enabled = false
	if is_inside_tree() and has_node("Camera3D"):
		_apply_network_setup()

func collect_network_input(seq: int) -> Dictionary:
	if not network_is_local or network_headless:
		return {
			"seq": seq,
			"move": Vector2.ZERO,
			"jump": false,
			"sprint": false,
			"crouch": false,
			"yaw": rotation.y,
		}
	return {
		"seq": seq,
		"move": Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back"),
		"jump": Input.is_action_just_pressed("jump"),
		"sprint": Input.is_action_pressed("sprint"),
		"crouch": Input.is_action_pressed("crouch"),
		"yaw": rotation.y,
	}

func apply_network_input(input: Dictionary, delta: float) -> void:
	if not is_inside_tree():
		return
	if not _ensure_runtime_nodes():
		return
	if damage_cooldown > 0.0:
		damage_cooldown -= delta

	rotation.y = float(input.get("yaw", rotation.y))

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif bool(input.get("jump", false)):
		velocity.y = jump_velocity

	var crouching := bool(input.get("crouch", false))
	_apply_crouch_shape(crouching, delta)

	var input_dir := Vector2.ZERO
	var raw_move = input.get("move", Vector2.ZERO)
	if raw_move is Vector2:
		var move_vector: Vector2 = raw_move
		input_dir = move_vector.limit_length(1.0)

	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	if direction.length_squared() > 0.0001:
		direction = (transform.basis * direction.normalized()).normalized()

	var current_speed := speed
	if crouching:
		current_speed = crouch_speed
	elif bool(input.get("sprint", false)):
		current_speed = sprint_speed

	if direction.length_squared() > 0.0001:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func apply_network_snapshot(state: Dictionary, alpha: float = 1.0) -> void:
	if not is_inside_tree():
		return
	var target_position: Vector3 = state.get("pos", global_position)
	var target_velocity: Vector3 = state.get("vel", velocity)
	var clamped_alpha := clampf(alpha, 0.0, 1.0)
	global_position = target_position if clamped_alpha >= 1.0 else global_position.lerp(target_position, clamped_alpha)
	velocity = target_velocity
	rotation.y = float(state.get("yaw", rotation.y))
	hp = int(state.get("hp", hp))

func make_network_snapshot() -> Dictionary:
	if not is_inside_tree():
		return {
			"id": network_peer_id,
			"pos": position,
			"vel": velocity,
			"yaw": rotation.y,
			"hp": hp,
		}
	return {
		"id": network_peer_id,
		"pos": global_position,
		"vel": velocity,
		"yaw": rotation.y,
		"hp": hp,
	}

func _apply_network_setup() -> void:
	if not _ensure_runtime_nodes():
		return
	top_down_enabled = false
	is_controlling = true
	nearby_npc = null
	possessed_npc = null
	if possess_prompt != null:
		possess_prompt.visible = false
	camera.current = network_is_local and not network_headless
	top_down_camera.current = false

	var body_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if body_mesh != null:
		body_mesh.visible = not network_is_local
	var marker := get_node_or_null("LocationMarker") as MeshInstance3D
	if marker != null:
		marker.visible = not network_headless

func _network_unhandled_input(event: InputEvent) -> void:
	if not network_is_local or network_headless:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _apply_crouch_shape(crouching: bool, delta: float) -> void:
	if not _ensure_runtime_nodes():
		return
	var target_height := CROUCH_HEIGHT if crouching else STANDING_HEIGHT
	var target_camera_y := CROUCH_CAMERA_Y if crouching else STANDING_CAMERA_Y
	capsule_shape.height = move_toward(capsule_shape.height, target_height, CROUCH_TRANSITION_SPEED * delta)
	collision_shape.position.y = -(STANDING_HEIGHT - capsule_shape.height) * 0.5
	camera.position.y = move_toward(camera.position.y, target_camera_y, CROUCH_TRANSITION_SPEED * delta)

func _ensure_runtime_nodes() -> bool:
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if camera == null:
		camera = get_node_or_null("Camera3D") as Camera3D
	if top_down_camera == null:
		top_down_camera = get_node_or_null("TopDownCamera3D") as Camera3D
	if possess_prompt == null:
		possess_prompt = get_node_or_null("PossessPrompt/Label") as Label
	if collision_shape == null or camera == null or top_down_camera == null:
		return false
	if capsule_shape == null:
		var source_shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
		if source_shape == null:
			return false
		capsule_shape = source_shape.duplicate() as CapsuleShape3D
		collision_shape.shape = capsule_shape
	return true

func _is_headless_server() -> bool:
	var manager := get_node_or_null("/root/MultiplayerManager")
	return manager != null and manager.has_method("is_headless_server") and bool(manager.call("is_headless_server"))

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
	if network_mode != NETWORK_NONE:
		_network_unhandled_input(event)
		return

	if top_down_enabled and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			top_down_zoom = maxf(2.0, top_down_zoom - top_down_zoom_step)
			_update_top_down_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			top_down_zoom = minf(120.0, top_down_zoom + top_down_zoom_step)
			_update_top_down_camera()

	if is_controlling and not top_down_enabled and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("possess"):
		_toggle_possession()

	if event.is_action_pressed("toggle_view") and is_controlling:
		top_down_enabled = not top_down_enabled
		_apply_camera_mode()

## "F" perto de um NPC: assume o controle dele em terceira pessoa, congelando
## o corpo do jogador no lugar. "F" de novo: devolve a IA ao NPC (ele escolhe
## novo destino e segue andando normal) e volta pra câmera/corpo do jogador.
func _toggle_possession() -> void:
	if is_controlling:
		if nearby_npc == null:
			return
		possessed_npc = nearby_npc
		_apply_control_speed_to_npc(possessed_npc)
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
		_apply_camera_mode()

## Assume um NPC específico (usado pelo menu de seleção de personagem, tanto no
## início quanto reaberto durante o jogo pra trocar). Se já estiver possuindo
## outro, devolve a IA a ele antes de assumir o novo.
func possess_specific(npc: CharacterBody3D) -> void:
	if npc == null or npc == possessed_npc:
		return
	if not is_controlling and possessed_npc != null:
		possessed_npc.stop_possession()
	possessed_npc = npc
	_apply_control_speed_to_npc(possessed_npc)
	possessed_npc.start_possession()
	is_controlling = false
	camera.current = false
	possess_prompt.visible = false
	nearby_npc = null

func _apply_control_speed_to_npc(npc: CharacterBody3D) -> void:
	npc.set("walk_speed", speed)
	npc.set("run_multiplier", sprint_speed / speed if speed > 0.0 else 1.0)
	npc.set("crouch_multiplier", crouch_speed / speed if speed > 0.0 else 1.0)

func _apply_camera_mode() -> void:
	camera.current = is_controlling and not top_down_enabled
	top_down_camera.current = is_controlling and top_down_enabled

func _update_top_down_camera() -> void:
	top_down_camera.position = Vector3(0, top_down_height, 0)
	top_down_camera.rotation = Vector3(deg_to_rad(-90.0), 0, 0)
	top_down_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	top_down_camera.size = top_down_zoom

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
	if network_mode != NETWORK_NONE:
		return

	if not is_controlling:
		return
	if damage_cooldown > 0.0:
		damage_cooldown -= delta

	_update_top_down_camera()
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
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	if not top_down_enabled:
		direction = (transform.basis * direction).normalized()
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

func take_damage(amount: int = 1) -> void:
	if damage_cooldown > 0.0:
		return
	hp = max(hp - amount, 0)
	damage_cooldown = 1.0
	if hp <= 0:
		global_position = Vector3(24, 12, 18)
		hp = 5
		_snap_to_ground.call_deferred()
