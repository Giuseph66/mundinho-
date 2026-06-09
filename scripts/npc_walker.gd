extends CharacterBody3D

## NPC simples: anda em círculo aleatório ao redor do ponto onde nasceu,
## tocando a animação de andar/correr do modelo (se existir).

const TARGET_HEIGHT := 1.8
const WALK_KEYWORDS := [
	"walk", "run", "jog", "sprint", "locomot", "forward",
	"stride", "gait", "move", "andar", "correr",
]
const IDLE_KEYWORDS := [
	"idle", "stand", "rest", "breath", "parad",
]

## Modelos Quaternius "Universal" compartilham o mesmo esqueleto: se um modelo
## não traz animações embutidas (caso do Mannequin_F), pegamos emprestada a
## biblioteca de animações de outro arquivo do mesmo pacote (UAL2_Standard).
const SHARED_ANIMATION_SOURCE := "res://assets/models/quaternius_universal_animation_library_2/UAL2_Standard.glb"

## Pacote 1 da Quaternius traz clipes que o pacote 2 não tem (corrida, agachar
## etc.). Importamos como biblioteca extra "UAL1" em todo modelo, além da sua
## própria animação (ou da emprestada acima).
const EXTRA_ANIMATION_SOURCE := "res://assets/models/quaternius_universal_animation_library_1/UAL1_Standard.glb"
const EXTRA_ANIMATION_LIBRARY_NAME := "UAL1"

## Capoeira baixada do Mixamo: esqueleto "mixamorig_*" tem ossos com nomes E
## rests (poses de descanso) diferentes do esqueleto Quaternius do personagem.
## _import_animation_library só troca o caminho do nó; aqui também traduzimos
## osso a osso (MIXAMO_TO_QUATERNIUS_BONES) e corrigimos a rotação pela
## diferença de rest entre os dois esqueletos (ver _remap_animation_bones).
const CAPOEIRA_ANIMATION_SOURCE := "res://assets/animations/mixamo_capoeira/Capoeira.fbx"
const CAPOEIRA_ANIMATION_LIBRARY := "Mixamo"
const CAPOEIRA_ANIMATION_NAME := "Capoeira"
const MIXAMO_TO_QUATERNIUS_BONES := {
	"mixamorig_Hips": "pelvis",
	"mixamorig_Spine": "spine_01",
	"mixamorig_Spine1": "spine_02",
	"mixamorig_Spine2": "spine_03",
	"mixamorig_Neck": "neck_01",
	"mixamorig_Head": "Head",
	"mixamorig_RightShoulder": "clavicle_r",
	"mixamorig_RightArm": "upperarm_r",
	"mixamorig_RightForeArm": "lowerarm_r",
	"mixamorig_RightHand": "hand_r",
	"mixamorig_RightHandThumb1": "thumb_01_r",
	"mixamorig_RightHandThumb2": "thumb_02_r",
	"mixamorig_RightHandThumb3": "thumb_03_r",
	"mixamorig_RightHandThumb4": "thumb_04_leaf_r",
	"mixamorig_RightHandIndex1": "index_01_r",
	"mixamorig_RightHandIndex2": "index_02_r",
	"mixamorig_RightHandIndex3": "index_03_r",
	"mixamorig_RightHandIndex4": "index_04_leaf_r",
	"mixamorig_RightHandMiddle1": "middle_01_r",
	"mixamorig_RightHandMiddle2": "middle_02_r",
	"mixamorig_RightHandMiddle3": "middle_03_r",
	"mixamorig_RightHandMiddle4": "middle_04_leaf_r",
	"mixamorig_RightHandRing1": "ring_01_r",
	"mixamorig_RightHandRing2": "ring_02_r",
	"mixamorig_RightHandRing3": "ring_03_r",
	"mixamorig_RightHandRing4": "ring_04_leaf_r",
	"mixamorig_RightHandPinky1": "pinky_01_r",
	"mixamorig_RightHandPinky2": "pinky_02_r",
	"mixamorig_RightHandPinky3": "pinky_03_r",
	"mixamorig_RightHandPinky4": "pinky_04_leaf_r",
	"mixamorig_LeftShoulder": "clavicle_l",
	"mixamorig_LeftArm": "upperarm_l",
	"mixamorig_LeftForeArm": "lowerarm_l",
	"mixamorig_LeftHand": "hand_l",
	"mixamorig_LeftHandThumb1": "thumb_01_l",
	"mixamorig_LeftHandThumb2": "thumb_02_l",
	"mixamorig_LeftHandThumb3": "thumb_03_l",
	"mixamorig_LeftHandThumb4": "thumb_04_leaf_l",
	"mixamorig_LeftHandIndex1": "index_01_l",
	"mixamorig_LeftHandIndex2": "index_02_l",
	"mixamorig_LeftHandIndex3": "index_03_l",
	"mixamorig_LeftHandIndex4": "index_04_leaf_l",
	"mixamorig_LeftHandMiddle1": "middle_01_l",
	"mixamorig_LeftHandMiddle2": "middle_02_l",
	"mixamorig_LeftHandMiddle3": "middle_03_l",
	"mixamorig_LeftHandMiddle4": "middle_04_leaf_l",
	"mixamorig_LeftHandRing1": "ring_01_l",
	"mixamorig_LeftHandRing2": "ring_02_l",
	"mixamorig_LeftHandRing3": "ring_03_l",
	"mixamorig_LeftHandRing4": "ring_04_leaf_l",
	"mixamorig_LeftHandPinky1": "pinky_01_l",
	"mixamorig_LeftHandPinky2": "pinky_02_l",
	"mixamorig_LeftHandPinky3": "pinky_03_l",
	"mixamorig_LeftHandPinky4": "pinky_04_leaf_l",
	"mixamorig_RightUpLeg": "thigh_r",
	"mixamorig_RightLeg": "calf_r",
	"mixamorig_RightFoot": "foot_r",
	"mixamorig_RightToeBase": "ball_r",
	"mixamorig_RightToe_End": "ball_leaf_r",
	"mixamorig_LeftUpLeg": "thigh_l",
	"mixamorig_LeftLeg": "calf_l",
	"mixamorig_LeftFoot": "foot_l",
	"mixamorig_LeftToeBase": "ball_l",
	"mixamorig_LeftToe_End": "ball_leaf_l",
}

const GROUP_NAME := "npc_walker"

## Sequência completa de pulo (início no chão → loop no ar → aterrissagem),
## alternando entre o estilo "normal" e o estilo "ninja" a cada novo pulo.
const JUMP_SEQUENCES: Array[Dictionary] = [
	{"start": "Jump_Start", "air": "Jump_Loop", "land": "Jump_Land"},
	{"start": "NinjaJump_Start", "air": "NinjaJump_Idle_Loop", "land": "NinjaJump_Land"},
]
const JUMP_IMPULSE := 6.0
const JUMP_LAND_FALLBACK_DURATION := 0.5

## Combo de espada: cada "attack" dentro da janela avança pro próximo golpe
## da lista; fora da janela (ou já no último), volta ao primeiro. Espelha a
## ideia de JUMP_SEQUENCES — variar o golpe a cada novo input.
const SWORD_COMBO: Array[String] = ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"]
const SWORD_COMBO_WINDOW := 0.6
## Fração da duração do clipe em que o hitbox fica ativo (a "lâmina conecta").
const ATTACK_HITBOX_START_FRACTION := 0.35
const ATTACK_HITBOX_END_FRACTION := 0.65
const ATTACK_DAMAGE := 1

## Arremesso: instancia o projétil na fração da animação em que a mão solta.
const THROW_RELEASE_FRACTION := 0.5
const THROW_SPEED := 16.0
const THROWN_DAGGER_SCENE := preload("res://scenes/thrown_dagger.tscn")

## Slot único de arma equipada (selecionado pela mochila — ver item_menu.gd).
## O botão "attack" dispara a ação da arma equipada: combo de espada,
## arremesso de adaga ou disparo de arma de fogo — nunca mais de uma por vez.
const WEAPON_NONE := "none"
const WEAPON_SWORD := "sword"
const WEAPON_DAGGER := "dagger"
const WEAPON_FIREARM := "firearm"
const WEAPON_IDS: Array[String] = [WEAPON_NONE, WEAPON_SWORD, WEAPON_DAGGER, WEAPON_FIREARM]

## Arma de fogo: o acervo de animação é medieval/fantasia — não existe clipe
## de mira/disparo. Por isso o tiro não usa máquina de fases por animação:
## só cooldown + projétil físico (bala) + recuo/clarão procedurais.
const FIREARM_FIRE_COOLDOWN := 0.28
const FIREARM_MUZZLE_FLASH_DURATION := 0.06
const FIREARM_RECOIL_ANGLE := 0.32
const BULLET_SPEED := 40.0
const BULLET_SCENE := preload("res://scenes/bullet.tscn")

## Quando o jogador "assume" o NPC: câmera em terceira pessoa orbitando o
## CameraRig, controles análogos ao player (correr/agachar com multiplicador
## de velocidade — sem isso a animação de corrida tocava na velocidade de
## passeio, descompassada).
const POSSESSION_MOUSE_SENSITIVITY := 0.0025
const POSSESSION_PITCH_MIN := -60.0
const POSSESSION_PITCH_MAX := 10.0
const FIRST_PERSON_PITCH_MIN := -85.0
const FIRST_PERSON_PITCH_MAX := 85.0
const THIRD_PERSON_SPRING_LENGTH := 4.5
const FIRST_PERSON_SPRING_LENGTH := 0.0
const POSSESSION_RUN_MULTIPLIER := 2.2
const POSSESSION_CROUCH_MULTIPLIER := 0.6
const NETWORK_NONE := 0
const NETWORK_SERVER := 1
const NETWORK_CLIENT_LOCAL := 2
const NETWORK_CLIENT_REMOTE := 3
const NETWORK_OVERRIDE_PREFIX := "override:"
const MAX_HP := 5
const RESPAWN_POSITION := Vector3(24, 12, 18)

## Em ladeira íngreme o NPC pode "empurrar" o morro sem nunca progredir —
## floor_max_angle não resolve sozinho. Detectamos isso medindo o avanço a
## cada intervalo; se andar de menos, desiste do alvo atual e escolhe outro.
const STUCK_CHECK_INTERVAL := 1.5
const STUCK_DISTANCE_THRESHOLD := 0.4

enum JumpPhase { NONE, STARTING, AIRBORNE, LANDING }
## Espelha JumpPhase: golpe começa (clipe toca), fica "ativo" (hitbox liga
## na janela de conexão da lâmina) e recupera (clipe termina, volta ao normal).
enum AttackPhase { NONE, SWINGING, ACTIVE, RECOVERING }
enum ThrowPhase { NONE, WINDUP, RELEASED }

@export var model_scene: PackedScene
@export_range(0.3, 6.0, 0.1) var walk_speed: float = 1.4
@export_range(2.0, 30.0, 0.5) var wander_radius: float = 6.0
@export_range(0.5, 10.0, 0.5) var pause_time: float = 2.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var home_position: Vector3
var target_position: Vector3
var pause_timer: float = 0.0
var current_player: AnimationPlayer = null
var current_skeleton: Skeleton3D = null
var override_animation: String = ""
var override_keep_moving: bool = false
var jump_requested: bool = false
var jump_phase: JumpPhase = JumpPhase.NONE
var jump_sequence_index: int = 0
var jump_air_animation: String = ""
var jump_land_animation: String = ""
var jump_land_timer: float = 0.0

## Estado do golpe de espada: fases (espelha jump_phase), índice do combo
## atual, timer de janela de combo (decai; expira -> reseta combo) e timers
## de início/fim da janela em que o hitbox conecta. `_attack_hit_bodies`
## evita acertar o mesmo alvo duas vezes no mesmo golpe.
var attack_phase: AttackPhase = AttackPhase.NONE
var attack_combo_index: int = 0
var attack_combo_timer: float = 0.0
var attack_hitbox_start_timer: float = 0.0
var attack_hitbox_end_timer: float = 0.0
var attack_hit_bodies: Array = []

## Estado do arremesso: toca OverhandThrow e, na fração de soltura, instancia
## o projétil — igual ao golpe, mas sem hitbox (o projétil cuida do dano).
var throw_phase: ThrowPhase = ThrowPhase.NONE
var throw_release_timer: float = 0.0

var override_speed_multiplier: float = 1.0
var is_idle_animation_active: bool = false
var stuck_check_timer: float = 0.0
var stuck_reference_position: Vector3 = Vector3.ZERO

## Estado de "posse": jogador assumiu o controle deste NPC (tecla F perto dele).
## Enquanto possuído, a IA de passeio para e o movimento vem do input do jogador.
var is_possessed: bool = false
var possessed_locomotion_state: String = ""
var is_first_person: bool = false
## Tecla C: toca a Capoeira (Mixamo) como "emote" — anda/pula cancela.
var is_dancing: bool = false
var hp: int = MAX_HP
var network_mode := NETWORK_NONE
var network_peer_id := 0
var network_is_local := false
var network_headless := false
var network_anim_state: String = "idle"
var network_last_anim_state: String = ""
var pending_network_projectiles: Array[Dictionary] = []

@onready var model_root: Node3D = $ModelRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var possession_camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var weapon_hitbox: Area3D = $CameraRig/WeaponHitbox

## Anexo das armas no osso da mão direita — montado em _spawn_model() se o
## esqueleto do modelo tiver o osso "hand_r" (todos os rigs suportados têm,
## via MIXAMO_TO_QUATERNIUS_BONES). Usado também pra spawnar projéteis
## (adaga/bala) na posição da mão.
var weapon_attachment: BoneAttachment3D = null
## Visual de cada arma (Node3D), filho de weapon_attachment, oculto até ser
## equipado. Só espada e arma de fogo têm modelo na mão — adaga é "sacada"
## do nada ao arremessar (não precisa de visual parado).
var weapon_visuals: Dictionary = {}
var equipped_weapon: String = WEAPON_SWORD

## Estado da arma de fogo: sem fase de animação (não há clipe), só timers —
## cooldown entre disparos (também dirige o recuo procedural, que relaxa de
## volta ao repouso conforme o cooldown esvazia) e duração do clarão do cano.
var firearm_cooldown_timer: float = 0.0
var firearm_muzzle_flash_timer: float = 0.0
var firearm_model: Node3D = null
var firearm_muzzle: Marker3D = null
var firearm_muzzle_flash: MeshInstance3D = null

func _ready() -> void:
	add_to_group(GROUP_NAME)
	# Mesmo motivo do player: terreno gerado por ruído pode ter ladeiras
	# íngremes que o ângulo de chão padrão (45°) trataria como parede,
	# travando o NPC. Floor snap evita "pular" em pequenos ressaltos.
	floor_max_angle = deg_to_rad(65.0)
	floor_snap_length = 0.5
	home_position = global_position
	stuck_reference_position = global_position
	_spawn_model()
	if network_mode != NETWORK_NONE:
		_apply_network_setup()
		return
	_pick_new_target()

func configure_network(peer_id: int, mode: int, local_view: bool, headless: bool = false) -> void:
	network_peer_id = peer_id
	network_mode = mode
	network_is_local = local_view
	network_headless = headless
	if is_inside_tree():
		_apply_network_setup()

func collect_network_input(seq: int) -> Dictionary:
	if not network_is_local or network_headless:
		return {
			"seq": seq,
			"move": Vector2.ZERO,
			"jump": false,
			"sprint": false,
			"crouch": false,
			"attack": false,
			"dance": false,
			"camera_yaw": camera_rig.rotation.y,
			"camera_pitch": camera_spring_arm.rotation.x,
		}
	return {
		"seq": seq,
		"move": Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back"),
		"jump": Input.is_action_just_pressed("jump"),
		"sprint": Input.is_action_pressed("sprint"),
		"crouch": Input.is_action_pressed("crouch"),
		"attack": Input.is_action_just_pressed("attack"),
		"dance": Input.is_action_just_pressed("dance"),
		"camera_yaw": camera_rig.rotation.y,
		"camera_pitch": camera_spring_arm.rotation.x,
	}

func apply_network_input(input: Dictionary, delta: float) -> void:
	if not is_inside_tree():
		return
	camera_rig.rotation.y = float(input.get("camera_yaw", camera_rig.rotation.y))
	camera_spring_arm.rotation.x = float(input.get("camera_pitch", camera_spring_arm.rotation.x))
	if bool(input.get("attack", false)):
		_trigger_equipped_weapon()
	if bool(input.get("dance", false)) and not is_dancing and jump_phase == JumpPhase.NONE \
			and attack_phase == AttackPhase.NONE and throw_phase == ThrowPhase.NONE:
		is_dancing = true
		possessed_locomotion_state = ""
		_play_override(CAPOEIRA_ANIMATION_NAME)

	if is_on_floor():
		if bool(input.get("jump", false)) and jump_phase == JumpPhase.NONE \
				and attack_phase == AttackPhase.NONE and throw_phase == ThrowPhase.NONE:
			trigger_jump()
		if jump_requested:
			velocity.y = JUMP_IMPULSE
			jump_requested = false
		else:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	_advance_jump_phase(delta)
	_advance_attack_phase(delta)
	_advance_throw_phase(delta)
	_advance_firearm_phase(delta)

	var input_dir := Vector2.ZERO
	var raw_move = input.get("move", Vector2.ZERO)
	if raw_move is Vector2:
		var move_vector: Vector2 = raw_move
		input_dir = move_vector.limit_length(1.0)

	var direction := camera_rig.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	var moving := direction.length_squared() > 0.0001
	if moving:
		direction = direction.normalized()

	var crouching := bool(input.get("crouch", false))
	var sprinting := moving and not crouching and bool(input.get("sprint", false))
	var current_speed := walk_speed
	if crouching:
		current_speed = walk_speed * POSSESSION_CROUCH_MULTIPLIER
	elif sprinting:
		current_speed = walk_speed * POSSESSION_RUN_MULTIPLIER

	if moving:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		_face_direction(direction)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	_update_possessed_animation(moving, sprinting, crouching)
	move_and_slide()
	if network_is_local and possession_camera.current:
		possession_camera.look_at(camera_rig.global_position, Vector3.UP)

func apply_network_snapshot(state: Dictionary, alpha: float = 1.0) -> void:
	if not is_inside_tree():
		return
	var target_position: Vector3 = state.get("pos", global_position)
	var target_velocity: Vector3 = state.get("vel", velocity)
	var clamped_alpha := clampf(alpha, 0.0, 1.0)
	global_position = target_position if clamped_alpha >= 1.0 else global_position.lerp(target_position, clamped_alpha)
	velocity = target_velocity
	model_root.rotation.y = float(state.get("model_yaw", model_root.rotation.y))
	var snapshot_weapon := String(state.get("weapon", equipped_weapon))
	if snapshot_weapon != equipped_weapon:
		equip_weapon(snapshot_weapon)
	hp = int(state.get("hp", hp))
	_apply_network_anim_state(String(state.get("anim_state", "idle")))
	if firearm_muzzle_flash != null:
		firearm_muzzle_flash.visible = bool(state.get("firearm_flash", false))
	for raw_projectile in state.get("projectiles", []):
		if raw_projectile is Dictionary:
			_spawn_network_projectile_visual(raw_projectile)
	if network_is_local and possession_camera.current:
		possession_camera.look_at(camera_rig.global_position, Vector3.UP)

func make_network_snapshot() -> Dictionary:
	var state := {
		"id": network_peer_id,
		"pos": global_position,
		"vel": velocity,
		"model_yaw": model_root.rotation.y,
		"hp": hp,
		"weapon": equipped_weapon,
		"anim_state": network_anim_state,
		"firearm_flash": firearm_muzzle_flash != null and firearm_muzzle_flash.visible,
	}
	if not pending_network_projectiles.is_empty():
		state["projectiles"] = pending_network_projectiles.duplicate(true)
		pending_network_projectiles.clear()
	return state

func _apply_network_setup() -> void:
	is_possessed = false
	possessed_locomotion_state = ""
	is_dancing = false
	jump_phase = JumpPhase.NONE
	jump_requested = false
	attack_phase = AttackPhase.NONE
	throw_phase = ThrowPhase.NONE
	if weapon_hitbox != null:
		weapon_hitbox.monitoring = false
	_reset_firearm_state()
	camera_spring_arm.rotation = Vector3(deg_to_rad(-12.0), 0.0, 0.0)
	possession_camera.current = network_is_local and not network_headless
	if network_is_local and not network_headless:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_play_idle_animation(current_player)
	is_idle_animation_active = true
	network_anim_state = "idle"
	network_last_anim_state = ""

# --- Controle externo (menu de análise de animações) -------------------------

## `speed_multiplier` deixa o ritmo do passo combinar com a animação — sem
## isso "Sprint_Loop" tocava na pose de corrida mas o NPC seguia andando na
## velocidade normal de passeio, descompassado com o clipe.
func set_override_animation(anim_name: String, keep_moving: bool = false, speed_multiplier: float = 1.0) -> void:
	jump_phase = JumpPhase.NONE
	override_keep_moving = keep_moving
	override_speed_multiplier = speed_multiplier
	_play_override(anim_name)

## Dispara a sequência completa de pulo: Start (no chão) → Air (no ar, em
## loop) → Land (ao tocar o chão) → volta a andar. Alterna entre os estilos
## de JUMP_SEQUENCES a cada chamada, pra comparar "normal" vs "ninja". Também
## aplica o impulso vertical de verdade — sem isso o NPC só fica na pose sem
## sair do chão (o impulso só "pega" quando o _physics_process roda com o NPC
## no chão, daí a flag `jump_requested` em vez de mexer em `velocity.y` aqui).
func trigger_jump() -> void:
	if jump_phase != JumpPhase.NONE:
		return
	var sequence: Dictionary = JUMP_SEQUENCES[jump_sequence_index]
	jump_sequence_index = (jump_sequence_index + 1) % JUMP_SEQUENCES.size()
	jump_air_animation = String(sequence["air"])
	jump_land_animation = String(sequence["land"])
	jump_phase = JumpPhase.STARTING
	override_keep_moving = true
	_play_override(String(sequence["start"]))
	jump_requested = true

func clear_override_animation() -> void:
	jump_phase = JumpPhase.NONE
	override_animation = ""
	override_keep_moving = false
	override_speed_multiplier = 1.0
	is_idle_animation_active = false
	_play_walk_animation(current_player)

# --- Combate (espada, arremesso e arma de fogo) ------------------------------

## Único botão de ataque ("attack") despacha pra ação da arma equipada —
## slot único selecionado na mochila (equip_weapon). Sem arma equipada
## (WEAPON_NONE), o botão não faz nada.
func _trigger_equipped_weapon() -> void:
	match equipped_weapon:
		WEAPON_SWORD:
			trigger_attack()
		WEAPON_DAGGER:
			trigger_throw()
		WEAPON_FIREARM:
			trigger_fire()

## Botão de ataque enquanto possuído: encadeia o combo Sword_Regular_A → B → C
## (cada clique dentro da janela avança; fora dela, ou após o terceiro golpe,
## volta ao primeiro). Liga o hitbox só na janela em que a lâmina conecta —
## ver _advance_attack_phase.
func trigger_attack() -> void:
	if attack_phase != AttackPhase.NONE or jump_phase != JumpPhase.NONE or throw_phase != ThrowPhase.NONE:
		return
	if attack_combo_timer > 0.0:
		attack_combo_index = (attack_combo_index + 1) % SWORD_COMBO.size()
	else:
		attack_combo_index = 0
	var clip := SWORD_COMBO[attack_combo_index]
	var length := _animation_length(clip)
	attack_phase = AttackPhase.SWINGING
	attack_hitbox_start_timer = length * ATTACK_HITBOX_START_FRACTION
	attack_hitbox_end_timer = length * ATTACK_HITBOX_END_FRACTION
	attack_combo_timer = SWORD_COMBO_WINDOW
	attack_hit_bodies.clear()
	override_keep_moving = false
	_play_override(clip)

## Avança SWINGING (espera a lâmina chegar na janela de conexão) → ACTIVE
## (hitbox ligado, aplica dano uma vez por alvo) → RECOVERING (hitbox desligado,
## espera o clipe acabar) → volta ao normal. Chamada de _physics_process_possessed,
## ao lado de _advance_jump_phase — mesmo padrão de máquina de fases por timer.
func _advance_attack_phase(delta: float) -> void:
	if attack_combo_timer > 0.0:
		attack_combo_timer -= delta
		if attack_combo_timer <= 0.0:
			attack_combo_index = 0

	match attack_phase:
		AttackPhase.SWINGING:
			attack_hitbox_start_timer -= delta
			if attack_hitbox_start_timer <= 0.0:
				attack_phase = AttackPhase.ACTIVE
				weapon_hitbox.monitoring = true
		AttackPhase.ACTIVE:
			attack_hitbox_end_timer -= delta
			_apply_attack_damage()
			if attack_hitbox_end_timer <= 0.0:
				weapon_hitbox.monitoring = false
				attack_phase = AttackPhase.RECOVERING
		AttackPhase.RECOVERING:
			if current_player == null or not current_player.is_playing():
				attack_phase = AttackPhase.NONE
				clear_override_animation()
		AttackPhase.NONE:
			pass

## Dá dano em corpos do grupo "enemy" sobrepostos ao hitbox — uma vez só por
## golpe (attack_hit_bodies dedupe), igual ao cooldown de contato da aranha.
func _apply_attack_damage() -> void:
	for body in weapon_hitbox.get_overlapping_bodies():
		if body == self or attack_hit_bodies.has(body):
			continue
		if body.has_method("take_damage"):
			attack_hit_bodies.append(body)
			body.take_damage(ATTACK_DAMAGE)

## Botão de arremesso enquanto possuído: toca OverhandThrow (não-loop, igual
## a Melee_Hook) e, na fração de soltura do clipe, instancia o projétil na
## posição da mão — ver _advance_throw_phase.
func trigger_throw() -> void:
	if attack_phase != AttackPhase.NONE or jump_phase != JumpPhase.NONE or throw_phase != ThrowPhase.NONE:
		return
	var length := _animation_length("OverhandThrow")
	throw_phase = ThrowPhase.WINDUP
	throw_release_timer = length * THROW_RELEASE_FRACTION
	override_keep_moving = false
	_play_override("OverhandThrow")

## Avança WINDUP (espera o frame de soltura) → spawna o projétil → RELEASED
## (espera o clipe acabar) → volta ao normal. Mesma estrutura de timers da
## máquina de pulo/ataque.
func _advance_throw_phase(delta: float) -> void:
	match throw_phase:
		ThrowPhase.WINDUP:
			throw_release_timer -= delta
			if throw_release_timer <= 0.0:
				_spawn_thrown_dagger()
				throw_phase = ThrowPhase.RELEASED
		ThrowPhase.RELEASED:
			if current_player == null or not current_player.is_playing():
				throw_phase = ThrowPhase.NONE
				clear_override_animation()
		ThrowPhase.NONE:
			pass

## Instancia a adaga na posição da mão (ou do peito, se o modelo não tiver o
## osso) e lança na direção que a câmera de terceira pessoa está olhando —
## convenção de mira já usada pelo controle possuído (_physics_process_possessed).
func _spawn_thrown_dagger() -> void:
	var spawn_position := global_position + Vector3.UP * 1.4
	if weapon_attachment != null:
		spawn_position = weapon_attachment.global_position
	var direction := -camera_rig.global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	else:
		direction = Vector3.FORWARD

	var dagger := THROWN_DAGGER_SCENE.instantiate()
	get_parent().add_child(dagger)
	dagger.global_position = spawn_position
	dagger.look_at(spawn_position + direction, Vector3.UP)
	dagger.launch(direction * THROW_SPEED, self)

# --- Equipar arma (mochila) --------------------------------------------------

## Chamado pela mochila (item_menu.gd) no NPC possuído pelo jogador. Cancela
## qualquer ação em andamento (golpe/arremesso/recuo) pra trocar de arma na
## mão sem deixar lixo de estado, e alterna a visibilidade dos visuais —
## só a arma equipada fica visível em weapon_attachment.
func equip_weapon(weapon_id: String) -> void:
	if not WEAPON_IDS.has(weapon_id) or weapon_id == equipped_weapon:
		return
	_cancel_weapon_actions()
	equipped_weapon = weapon_id
	for id in weapon_visuals:
		weapon_visuals[id].visible = (id == weapon_id)

## Zera fases/timers de todas as armas — usado ao trocar de arma e ao
## (re)iniciar a posse, mesmo espírito dos resets em start_possession.
func _cancel_weapon_actions() -> void:
	attack_phase = AttackPhase.NONE
	attack_combo_index = 0
	attack_combo_timer = 0.0
	attack_hit_bodies.clear()
	if weapon_hitbox != null:
		weapon_hitbox.monitoring = false
	throw_phase = ThrowPhase.NONE
	_reset_firearm_state()
	clear_override_animation()

func _reset_firearm_state() -> void:
	firearm_cooldown_timer = 0.0
	firearm_muzzle_flash_timer = 0.0
	if firearm_muzzle_flash != null:
		firearm_muzzle_flash.visible = false
	if firearm_model != null:
		firearm_model.rotation.x = 0.0

## Botão de ataque com a arma de fogo equipada: sem clipe de animação pra
## esperar (não existe no acervo), então o gatilho só checa cooldown e os
## gates de fase já usados pelas outras armas (não atira no meio de um pulo
## ou golpe). Cooldown também governa o recuo procedural — ver _advance_firearm_phase.
func trigger_fire() -> void:
	if equipped_weapon != WEAPON_FIREARM or firearm_cooldown_timer > 0.0:
		return
	if attack_phase != AttackPhase.NONE or jump_phase != JumpPhase.NONE or throw_phase != ThrowPhase.NONE:
		return
	firearm_cooldown_timer = FIREARM_FIRE_COOLDOWN
	firearm_muzzle_flash_timer = FIREARM_MUZZLE_FLASH_DURATION
	if firearm_muzzle_flash != null:
		firearm_muzzle_flash.visible = true
	_spawn_bullet()

## Recuo e clarão são só feedback procedural (sem animação): o cano gira pra
## trás na hora do disparo e relaxa de volta ao repouso conforme o cooldown
## esvazia; o clarão (mesh emissivo + luz) liga por FIREARM_MUZZLE_FLASH_DURATION.
func _advance_firearm_phase(delta: float) -> void:
	if firearm_cooldown_timer > 0.0:
		firearm_cooldown_timer = maxf(0.0, firearm_cooldown_timer - delta)
	if firearm_muzzle_flash_timer > 0.0:
		firearm_muzzle_flash_timer -= delta
		if firearm_muzzle_flash_timer <= 0.0 and firearm_muzzle_flash != null:
			firearm_muzzle_flash.visible = false
	if firearm_model != null:
		var recoil := clampf(firearm_cooldown_timer / FIREARM_FIRE_COOLDOWN, 0.0, 1.0)
		firearm_model.rotation.x = -recoil * FIREARM_RECOIL_ANGLE

## Instancia a bala no cano (ou na altura do peito, se não houver visual de
## arma) mirando pra onde a câmera de terceira pessoa olha — mesma convenção
## de mira do arremesso (_spawn_thrown_dagger).
func _spawn_bullet() -> void:
	var spawn_position := global_position + Vector3.UP * 1.4
	if firearm_muzzle != null:
		spawn_position = firearm_muzzle.global_position
	var direction := -camera_rig.global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	else:
		direction = Vector3.FORWARD

	var bullet := BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = spawn_position
	bullet.look_at(spawn_position + direction, Vector3.UP)
	var bullet_velocity := direction * BULLET_SPEED
	bullet.launch(bullet_velocity, self)
	if network_mode == NETWORK_SERVER:
		pending_network_projectiles.append({
			"type": "bullet",
			"pos": spawn_position,
			"vel": bullet_velocity,
		})

func _spawn_network_projectile_visual(projectile: Dictionary) -> void:
	if String(projectile.get("type", "")) != "bullet":
		return
	var spawn_position: Vector3 = projectile.get("pos", global_position + Vector3.UP * 1.4)
	var bullet_velocity: Vector3 = projectile.get("vel", Vector3.ZERO)
	if bullet_velocity.length_squared() <= 0.0001:
		return
	var bullet := BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = spawn_position
	bullet.look_at(spawn_position + bullet_velocity.normalized(), Vector3.UP)
	bullet.visual_only = true
	bullet.launch(bullet_velocity, self)

func take_damage(amount: int = 1) -> void:
	if network_mode != NETWORK_NONE and network_mode != NETWORK_SERVER:
		return
	hp = max(hp - amount, 0)
	if hp <= 0:
		_respawn_network_character()

func _respawn_network_character() -> void:
	hp = MAX_HP
	global_position = RESPAWN_POSITION
	velocity = Vector3.ZERO
	_cancel_weapon_actions()

# --- Câmera (1ª / 3ª pessoa) -------------------------------------------------

## F5 alterna entre terceira pessoa (câmera orbitando atrás — spring_length
## normal) e primeira pessoa (câmera no pivô da cabeça, spring_length=0).
## Em primeira pessoa esconde o modelo — câmera está dentro do corpo, então
## ver os próprios membros seria estranho.
func _set_camera_mode(first_person: bool) -> void:
	is_first_person = first_person
	camera_spring_arm.spring_length = FIRST_PERSON_SPRING_LENGTH if first_person else THIRD_PERSON_SPRING_LENGTH
	model_root.visible = not first_person
	camera_spring_arm.rotation = Vector3(deg_to_rad(-12.0), 0.0, 0.0)

# --- Posse (jogador assume o controle) ---------------------------------------

## Chamado pelo player ao apertar F perto do NPC. Liga a câmera de terceira
## pessoa deste NPC (desligando a do jogador) e entrega o controle ao input.
func start_possession() -> void:
	if is_possessed:
		return
	is_possessed = true
	jump_phase = JumpPhase.NONE
	jump_requested = false
	attack_phase = AttackPhase.NONE
	attack_combo_index = 0
	attack_combo_timer = 0.0
	attack_hit_bodies.clear()
	weapon_hitbox.monitoring = false
	throw_phase = ThrowPhase.NONE
	_reset_firearm_state()
	override_animation = ""
	override_keep_moving = false
	override_speed_multiplier = 1.0
	possessed_locomotion_state = ""
	is_dancing = false
	_set_camera_mode(false)
	possession_camera.current = true
	_play_idle_animation(current_player)
	is_idle_animation_active = true

## Chamado ao apertar F de novo: devolve o NPC pro "piloto automático" — ele
## escolhe um novo destino e segue andando normalmente, como se nada tivesse
## acontecido.
func stop_possession() -> void:
	if not is_possessed:
		return
	is_possessed = false
	possession_camera.current = false
	is_idle_animation_active = false
	attack_phase = AttackPhase.NONE
	weapon_hitbox.monitoring = false
	throw_phase = ThrowPhase.NONE
	_reset_firearm_state()
	_set_camera_mode(false)
	_pick_new_target()

func _play_override(anim_name: String) -> void:
	override_animation = anim_name
	network_anim_state = NETWORK_OVERRIDE_PREFIX + anim_name
	if current_player == null:
		return
	var resolved := _resolve_animation_name(current_player, anim_name)
	if resolved == "":
		return
	current_player.stop()
	current_player.play(resolved)

func _apply_network_anim_state(anim_state: String) -> void:
	if anim_state == "" or anim_state == network_last_anim_state:
		return
	network_last_anim_state = anim_state
	if anim_state.begins_with(NETWORK_OVERRIDE_PREFIX):
		_play_override(anim_state.substr(NETWORK_OVERRIDE_PREFIX.length()))
		return
	match anim_state:
		"idle":
			_play_idle_animation(current_player)
		"crouch":
			_play_override("Crouch_Fwd_Loop")
		"run":
			_play_override("Sprint_Loop")
		"walk":
			_play_walk_animation(current_player)

func _animation_length(anim_name: String) -> float:
	if current_player == null:
		return JUMP_LAND_FALLBACK_DURATION
	var resolved := _resolve_animation_name(current_player, anim_name)
	if resolved == "" or not current_player.has_animation(resolved):
		return JUMP_LAND_FALLBACK_DURATION
	return current_player.get_animation(resolved).length

## Resolve um nome de animação "amigável" pro nome real exposto pelo player.
## Cobre dois casos comuns de divergência:
## - AnimationLibrary com nome próprio: get_animation_list() devolve
##   "Biblioteca/Clipe" em vez de só "Clipe".
## - O importador do Godot remove o sufixo "_Loop"/"_loop" do nome do clipe
##   (e ajusta o loop_mode), então "Idle_FoldArms_Loop" vira "Idle_FoldArms".
func _resolve_animation_name(player: AnimationPlayer, requested: String) -> String:
	var candidates: Array[String] = [requested]
	for suffix in ["_Loop", "_loop", "_LOOP"]:
		if requested.ends_with(suffix):
			candidates.append(requested.substr(0, requested.length() - suffix.length()))
		else:
			candidates.append(requested + suffix)

	for candidate in candidates:
		if player.has_animation(candidate):
			return candidate

	for full_name in player.get_animation_list():
		var name_str := String(full_name)
		var slash_idx := name_str.rfind("/")
		var bare_name := name_str if slash_idx == -1 else name_str.substr(slash_idx + 1)
		if bare_name in candidates:
			return full_name
	return ""

func _physics_process(delta: float) -> void:
	if network_mode != NETWORK_NONE:
		return
	if is_possessed:
		_physics_process_possessed(delta)
		return

	if is_on_floor():
		if jump_requested:
			velocity.y = JUMP_IMPULSE
			jump_requested = false
		else:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	_advance_jump_phase(delta)

	if override_animation != "" and not override_keep_moving:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_target := target_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	if distance < 0.3:
		velocity.x = 0.0
		velocity.z = 0.0
		pause_timer -= delta
		if pause_timer <= 0.0:
			_pick_new_target()
		stuck_check_timer = 0.0
		stuck_reference_position = global_position
		if not is_idle_animation_active:
			_play_idle_animation(current_player)
			is_idle_animation_active = true
	else:
		var direction := to_target / distance
		var current_speed := walk_speed * override_speed_multiplier
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		_face_direction(direction)
		_check_stuck(delta)
		if is_idle_animation_active:
			_play_walk_animation(current_player)
			is_idle_animation_active = false

	move_and_slide()

## Compartilhado entre o modo IA e o modo possuído: avança Start → Air → Land
## da sequência de pulo conforme o NPC sai/toca o chão.
func _advance_jump_phase(delta: float) -> void:
	match jump_phase:
		JumpPhase.STARTING:
			if not is_on_floor():
				jump_phase = JumpPhase.AIRBORNE
				_play_override(jump_air_animation)
		JumpPhase.AIRBORNE:
			if is_on_floor():
				jump_phase = JumpPhase.LANDING
				_play_override(jump_land_animation)
				jump_land_timer = _animation_length(jump_land_animation)
		JumpPhase.LANDING:
			jump_land_timer -= delta
			if jump_land_timer <= 0.0:
				clear_override_animation()
		JumpPhase.NONE:
			pass

## Olhar com o mouse enquanto possuído: gira o CameraRig (yaw) e o SpringArm
## (pitch, com limite — sem isso a câmera vira de cabeça pra baixo).
func _unhandled_input(event: InputEvent) -> void:
	if network_mode != NETWORK_NONE:
		_network_unhandled_input(event)
		return
	if not is_possessed:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.rotate_y(-event.relative.x * POSSESSION_MOUSE_SENSITIVITY)
		var pitch_min := FIRST_PERSON_PITCH_MIN if is_first_person else POSSESSION_PITCH_MIN
		var pitch_max := FIRST_PERSON_PITCH_MAX if is_first_person else POSSESSION_PITCH_MAX
		camera_spring_arm.rotation.x = clampf(
			camera_spring_arm.rotation.x - event.relative.y * POSSESSION_MOUSE_SENSITIVITY,
			deg_to_rad(pitch_min),
			deg_to_rad(pitch_max),
		)
	if event.is_action_pressed("toggle_camera"):
		_set_camera_mode(not is_first_person)
	if event.is_action_pressed("dance") and not is_dancing and jump_phase == JumpPhase.NONE:
		is_dancing = true
		possessed_locomotion_state = ""
		_play_override(CAPOEIRA_ANIMATION_NAME)

	if event.is_action_pressed("attack") and not is_dancing:
		_trigger_equipped_weapon()

func _network_unhandled_input(event: InputEvent) -> void:
	if not network_is_local or network_headless:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.rotate_y(-event.relative.x * POSSESSION_MOUSE_SENSITIVITY)
		var pitch_min := FIRST_PERSON_PITCH_MIN if is_first_person else POSSESSION_PITCH_MIN
		var pitch_max := FIRST_PERSON_PITCH_MAX if is_first_person else POSSESSION_PITCH_MAX
		camera_spring_arm.rotation.x = clampf(
			camera_spring_arm.rotation.x - event.relative.y * POSSESSION_MOUSE_SENSITIVITY,
			deg_to_rad(pitch_min),
			deg_to_rad(pitch_max),
		)
	if event.is_action_pressed("toggle_camera"):
		_set_camera_mode(not is_first_person)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

## Controle manual: mesmas teclas do player (WASD, Shift corre, Ctrl agacha,
## Espaço pula), movendo-se em relação à direção da câmera (convenção de
## terceira pessoa) em vez do "para frente" do corpo do NPC.
func _physics_process_possessed(delta: float) -> void:
	if is_on_floor():
		if jump_requested:
			velocity.y = JUMP_IMPULSE
			jump_requested = false
		else:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	_advance_jump_phase(delta)
	_advance_attack_phase(delta)
	_advance_throw_phase(delta)

	var input_dir := Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	var direction := (camera_rig.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	direction.y = 0.0
	var moving := direction.length_squared() > 0.0001
	if moving:
		direction = direction.normalized()

	var crouching := Input.is_action_pressed("crouch")
	var sprinting := moving and not crouching and Input.is_action_pressed("sprint")
	var current_speed := walk_speed
	if crouching:
		current_speed = walk_speed * POSSESSION_CROUCH_MULTIPLIER
	elif sprinting:
		current_speed = walk_speed * POSSESSION_RUN_MULTIPLIER

	if moving:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		_face_direction(direction)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor() and jump_phase == JumpPhase.NONE \
			and attack_phase == AttackPhase.NONE and throw_phase == ThrowPhase.NONE:
		trigger_jump()

	_update_possessed_animation(moving, sprinting, crouching)
	move_and_slide()

	# SpringArm3D só garante a distância (e evita atravessar paredes/morros);
	# sem isso, dependendo do lado do orbit, a câmera olharia pra longe do
	# personagem em vez de pra ele.
	possession_camera.look_at(camera_rig.global_position, Vector3.UP)

## Troca a animação só quando o estado de locomoção muda (igual ao
## is_idle_animation_active da IA — sem isso reiniciava o clipe a cada frame).
func _update_possessed_animation(moving: bool, sprinting: bool, crouching: bool) -> void:
	if jump_phase != JumpPhase.NONE or attack_phase != AttackPhase.NONE or throw_phase != ThrowPhase.NONE:
		possessed_locomotion_state = ""
		if override_animation != "":
			network_anim_state = NETWORK_OVERRIDE_PREFIX + override_animation
		is_dancing = false
		return

	if is_dancing:
		# Andar cancela o emote; clipe terminando sozinho também libera o estado.
		if moving or current_player == null or not current_player.is_playing():
			is_dancing = false
			# A Capoeira mexe dedo a dedo, coluna etc. — ossos que Walk/Run/Idle
			# não têm trilha ficam "presos" na última pose dela (corcunda,
			# dedos contraídos). Volta tudo pro rest antes de retomar a
			# locomoção; a animação seguinte sobrescreve o que precisa.
			if current_skeleton != null:
				current_skeleton.reset_bone_poses()
		else:
			return

	var desired := "idle"
	if moving:
		if crouching:
			desired = "crouch"
		elif sprinting:
			desired = "run"
		else:
			desired = "walk"
	if desired == possessed_locomotion_state:
		return
	possessed_locomotion_state = desired
	network_anim_state = desired
	is_idle_animation_active = desired == "idle"
	match desired:
		"idle":
			_play_idle_animation(current_player)
		"crouch":
			_play_override("Crouch_Fwd_Loop")
		"run":
			_play_override("Sprint_Loop")
		"walk":
			_play_walk_animation(current_player)

func _check_stuck(delta: float) -> void:
	stuck_check_timer += delta
	if stuck_check_timer < STUCK_CHECK_INTERVAL:
		return
	stuck_check_timer = 0.0
	if global_position.distance_to(stuck_reference_position) < STUCK_DISTANCE_THRESHOLD:
		_pick_recovery_target()
	stuck_reference_position = global_position

## Alvo de fuga: ao contrário de _pick_new_target (que mira de novo perto de
## "casa" — podendo escolher outra direção igualmente bloqueada pelo mesmo
## morro, parecendo travado pra sempre), foge a partir da posição ATUAL, na
## direção oposta a que estava tentando ir, com variação de ângulo.
func _pick_recovery_target() -> void:
	var away := -(target_position - global_position)
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	away = away.normalized().rotated(Vector3.UP, randf_range(-PI * 0.5, PI * 0.5))
	target_position = global_position + away * randf_range(2.0, 4.0)
	pause_timer = pause_time

func _spawn_model() -> void:
	if model_scene == null:
		return
	var instance := model_scene.instantiate()
	if not (instance is Node3D):
		instance.queue_free()
		return
	model_root.add_child(instance)
	_normalize_model(instance as Node3D)

	var players: Array[AnimationPlayer] = []
	_collect_animation_players(instance, players)
	var player := _pick_usable_player(players)
	var skeleton := _find_skeleton(instance)

	# Modelos baixados do Mixamo vêm com esqueleto "mixamorig_"/"mixamorig1_" e
	# SEM as animações do jogo (Walk/Run/Idle/Jump... estão nas libs Quaternius,
	# com outros nomes de osso). Pra esses, retargetamos a biblioteca Quaternius
	# inteira pro rig deles (osso a osso + correção de rest), em vez do remap de
	# caminho simples — que só serve quando os nomes de osso já batem.
	var mixamo_prefix := _detect_mixamo_prefix(skeleton)

	if skeleton != null and mixamo_prefix != "":
		if player == null:
			player = AnimationPlayer.new()
			instance.add_child(player)
		var quaternius_to_target := _build_quaternius_to_mixamo_map(mixamo_prefix)
		_import_retargeted_library(instance, skeleton, player, SHARED_ANIMATION_SOURCE, "", quaternius_to_target)
		_import_retargeted_library(instance, skeleton, player, EXTRA_ANIMATION_SOURCE, EXTRA_ANIMATION_LIBRARY_NAME, quaternius_to_target)
		# Capoeira é Mixamo ("mixamorig_") -> rig Mixamo do char (prefixo dele):
		# mesmo rig na prática, só o prefixo muda; o retarget vira quase identidade.
		var capoeira_to_target := _build_capoeira_to_mixamo_map(mixamo_prefix)
		_import_retargeted_animation(instance, skeleton, player, CAPOEIRA_ANIMATION_SOURCE, CAPOEIRA_ANIMATION_LIBRARY, CAPOEIRA_ANIMATION_NAME, capoeira_to_target)
	else:
		if player == null:
			player = AnimationPlayer.new()
			instance.add_child(player)
			if skeleton != null:
				_import_animation_library(instance, skeleton, player, SHARED_ANIMATION_SOURCE, "")
		if skeleton != null:
			_import_animation_library(instance, skeleton, player, EXTRA_ANIMATION_SOURCE, EXTRA_ANIMATION_LIBRARY_NAME)
			_import_retargeted_animation(instance, skeleton, player, CAPOEIRA_ANIMATION_SOURCE, CAPOEIRA_ANIMATION_LIBRARY, CAPOEIRA_ANIMATION_NAME, MIXAMO_TO_QUATERNIUS_BONES)

	current_player = player
	current_skeleton = skeleton
	_attach_weapon(skeleton)
	_play_walk_animation(player)

## Prende todos os visuais de arma (montados na hora — sem asset novo, mesmo
## espírito de _apply_texture na aranha) no osso "hand_r" via BoneAttachment3D.
## MIXAMO_TO_QUATERNIUS_BONES garante que esse nome de osso existe nos dois
## esquemas suportados (Quaternius e Mixamo retargetado); se um modelo não
## tiver, simplesmente não tem arma visível (o combate continua funcionando,
## só sem o visual). Cada arma fica oculta até ser equipada — ver equip_weapon.
func _attach_weapon(skeleton: Skeleton3D) -> void:
	weapon_attachment = null
	weapon_visuals.clear()
	firearm_model = null
	firearm_muzzle = null
	firearm_muzzle_flash = null
	if skeleton == null:
		return
	var bone_name := "hand_r"
	var bone_idx := skeleton.find_bone(bone_name)
	if bone_idx == -1:
		var mixamo_prefix := _detect_mixamo_prefix(skeleton)
		if mixamo_prefix != "":
			bone_name = mixamo_prefix + "RightHand"
			bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return

	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	weapon_attachment = attachment

	var sword := _build_sword_visual()
	attachment.add_child(sword)
	weapon_visuals[WEAPON_SWORD] = sword

	var firearm := _build_firearm_visual()
	attachment.add_child(firearm)
	weapon_visuals[WEAPON_FIREARM] = firearm
	firearm_model = firearm

	for id in weapon_visuals:
		weapon_visuals[id].visible = (id == equipped_weapon)

## Lâmina (BoxMesh) + cabo (CylinderMesh), material metálico — espada simples
## montada em código.
func _build_sword_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "SwordVisual"

	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color(0.78, 0.8, 0.84)
	blade_material.metallic = 0.85
	blade_material.roughness = 0.25

	var hilt_material := StandardMaterial3D.new()
	hilt_material.albedo_color = Color(0.32, 0.2, 0.1)
	hilt_material.roughness = 0.7

	var blade := MeshInstance3D.new()
	blade.mesh = BoxMesh.new()
	blade.mesh.size = Vector3(0.05, 0.55, 0.12)
	blade.mesh.material = blade_material
	blade.position = Vector3(0.0, 0.32, 0.0)
	root.add_child(blade)

	var hilt := MeshInstance3D.new()
	hilt.mesh = CylinderMesh.new()
	hilt.mesh.top_radius = 0.025
	hilt.mesh.bottom_radius = 0.025
	hilt.mesh.height = 0.16
	hilt.mesh.material = hilt_material
	root.add_child(hilt)

	return root

## Pistola montada em código (corpo + cabo + cano em BoxMesh/CylinderMesh,
## material metálico escuro) com um Marker3D "Muzzle" na ponta do cano —
## ponto de spawn da bala (_spawn_bullet) e do clarão de disparo (mesh
## emissivo + OmniLight3D, ocultos até trigger_fire ligar). Guarda
## referências em firearm_model/firearm_muzzle/firearm_muzzle_flash pra
## recuo, mira e clarão procedurais (ver _advance_firearm_phase).
func _build_firearm_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "FirearmVisual"

	var metal_material := StandardMaterial3D.new()
	metal_material.albedo_color = Color(0.18, 0.18, 0.2)
	metal_material.metallic = 0.8
	metal_material.roughness = 0.35

	var grip_material := StandardMaterial3D.new()
	grip_material.albedo_color = Color(0.25, 0.16, 0.1)
	grip_material.roughness = 0.75

	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.08, 0.12, 0.28)
	body.mesh.material = metal_material
	body.position = Vector3(0.0, 0.02, -0.05)
	root.add_child(body)

	var grip := MeshInstance3D.new()
	grip.mesh = BoxMesh.new()
	grip.mesh.size = Vector3(0.06, 0.16, 0.07)
	grip.mesh.material = grip_material
	grip.position = Vector3(0.0, -0.1, 0.06)
	grip.rotation.x = deg_to_rad(18.0)
	root.add_child(grip)

	var barrel := MeshInstance3D.new()
	barrel.mesh = CylinderMesh.new()
	barrel.mesh.top_radius = 0.025
	barrel.mesh.bottom_radius = 0.03
	barrel.mesh.height = 0.32
	barrel.mesh.material = metal_material
	barrel.rotation.x = deg_to_rad(90.0)
	barrel.position = Vector3(0.0, 0.03, -0.34)
	root.add_child(barrel)

	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.03, -0.5)
	root.add_child(muzzle)
	firearm_muzzle = muzzle

	var flash_material := StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.85, 0.4)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.7, 0.2)
	flash_material.emission_energy_multiplier = 4.0

	var flash := MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	flash.mesh = SphereMesh.new()
	flash.mesh.radius = 0.07
	flash.mesh.height = 0.14
	flash.mesh.material = flash_material
	flash.visible = false
	muzzle.add_child(flash)
	firearm_muzzle_flash = flash

	var flash_light := OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.7, 0.3)
	flash_light.light_energy = 6.0
	flash_light.omni_range = 3.0
	flash.add_child(flash_light)

	return root

## Detecta o prefixo do esqueleto Mixamo ("mixamorig_" ou "mixamorig1_" — o "1"
## aparece quando o download cria um namespace numerado). Retorna "" se for um
## esqueleto não-Mixamo (ex.: Quaternius), sinalizando o caminho de import normal.
func _detect_mixamo_prefix(skeleton: Skeleton3D) -> String:
	if skeleton == null:
		return ""
	for i in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(i)
		if bone_name.begins_with("mixamorig") and bone_name.ends_with("Hips"):
			return bone_name.substr(0, bone_name.length() - 4)  # tira "Hips"
	return ""

## Mapa osso-de-origem Quaternius -> osso-de-destino Mixamo (com o prefixo do
## char). Invertendo MIXAMO_TO_QUATERNIUS_BONES e trocando "mixamorig_" pelo
## prefixo real. Usado pra retargetar a locomoção Quaternius pro rig Mixamo.
func _build_quaternius_to_mixamo_map(prefix: String) -> Dictionary:
	var result := {}
	for mixamo_bone in MIXAMO_TO_QUATERNIUS_BONES:
		var quaternius_bone: String = MIXAMO_TO_QUATERNIUS_BONES[mixamo_bone]
		result[quaternius_bone] = mixamo_bone.replace("mixamorig_", prefix)
	return result

## Mapa pra Capoeira: trilhas vêm com "mixamorig_*"; troca pro prefixo do char.
func _build_capoeira_to_mixamo_map(prefix: String) -> Dictionary:
	if prefix == "mixamorig_":
		var identity := {}
		for mixamo_bone in MIXAMO_TO_QUATERNIUS_BONES:
			identity[mixamo_bone] = mixamo_bone
		return identity
	var result := {}
	for mixamo_bone in MIXAMO_TO_QUATERNIUS_BONES:
		result[mixamo_bone] = mixamo_bone.replace("mixamorig_", prefix)
	return result

# --- Escala / posicionamento (mesma lógica do ModelViewer) -------------------

func _normalize_model(model: Node3D) -> void:
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	model.position = Vector3.ZERO
	var bounds := _calculate_local_aabb(model)
	if bounds.size.y > 0.001:
		var scale_factor := TARGET_HEIGHT / bounds.size.y
		model.scale = Vector3.ONE * scale_factor
		bounds = _calculate_local_aabb(model)
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

# --- Animação -----------------------------------------------------------------

func _collect_animation_players(node: Node, out: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		out.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_animation_players(child, out)

func _pick_usable_player(players: Array[AnimationPlayer]) -> AnimationPlayer:
	for player in players:
		if not player.get_animation_list().is_empty():
			return player
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

## Carrega `source_path`, junta todos os clipes da sua AnimationLibrary numa só
## biblioteca chamada `library_name` e adiciona em `player`. As trilhas das
## animações de origem apontam pro esqueleto do arquivo de origem (ex.:
## "Armature/Skeleton3D:osso"); cada modelo pode ter uma hierarquia ligeiramente
## diferente, então reescrevemos o trecho do caminho do nó pra apontar pro
## esqueleto deste modelo (`skeleton`), preservando o nome do osso.
func _import_animation_library(instance: Node3D, skeleton: Skeleton3D, player: AnimationPlayer, source_path: String, library_name: String) -> void:
	var source := load(source_path) as PackedScene
	if source == null:
		return
	var source_instance := source.instantiate()
	var source_skeleton := _find_skeleton(source_instance)
	var source_players: Array[AnimationPlayer] = []
	_collect_animation_players(source_instance, source_players)
	var source_player := _pick_usable_player(source_players)
	if source_player == null or source_skeleton == null:
		source_instance.queue_free()
		return

	var source_skeleton_path := String(source_instance.get_path_to(source_skeleton))
	var skeleton_path := String(instance.get_path_to(skeleton))

	var merged_library := AnimationLibrary.new()
	for source_lib_name in source_player.get_animation_library_list():
		var source_library := source_player.get_animation_library(source_lib_name)
		for anim_name in source_library.get_animation_list():
			var remapped_animation: Animation = source_library.get_animation(anim_name).duplicate(true)
			_remap_skeleton_tracks(remapped_animation, source_skeleton_path, skeleton_path)
			merged_library.add_animation(anim_name, remapped_animation)
	player.add_animation_library(library_name, merged_library)
	source_instance.queue_free()

func _remap_skeleton_tracks(animation: Animation, from_path: String, to_path: String) -> void:
	if from_path == to_path:
		return
	for track_idx in animation.get_track_count():
		var path_str := String(animation.track_get_path(track_idx))
		var colon_idx := path_str.find(":")
		var node_part := path_str if colon_idx == -1 else path_str.substr(0, colon_idx)
		if node_part != from_path:
			continue
		var rest := "" if colon_idx == -1 else path_str.substr(colon_idx)
		animation.track_set_path(track_idx, NodePath(to_path + rest))

## Importa um clipe cujo esqueleto de origem é de outro rig (ex.: Mixamo) e
## remapeia osso a osso pro esqueleto deste modelo, usando `bone_map` (nome de
## origem -> nome de destino) e correção de rest pose (ver _remap_animation_bones).
## Pega o primeiro clipe da fonte e o renomeia pra `target_animation_name`.
func _import_retargeted_animation(instance: Node3D, skeleton: Skeleton3D, player: AnimationPlayer, source_path: String, library_name: String, target_animation_name: String, bone_map: Dictionary) -> void:
	var source := load(source_path) as PackedScene
	if source == null:
		return
	var source_instance := source.instantiate()
	var source_skeleton := _find_skeleton(source_instance)
	var source_players: Array[AnimationPlayer] = []
	_collect_animation_players(source_instance, source_players)
	var source_player := _pick_usable_player(source_players)
	if source_player == null or source_skeleton == null:
		source_instance.queue_free()
		return

	var skeleton_path := String(instance.get_path_to(skeleton))

	var merged_library: AnimationLibrary
	if player.has_animation_library(library_name):
		merged_library = player.get_animation_library(library_name)
	else:
		merged_library = AnimationLibrary.new()
		player.add_animation_library(library_name, merged_library)

	var picked := false
	for source_lib_name in source_player.get_animation_library_list():
		if picked:
			break
		var source_library := source_player.get_animation_library(source_lib_name)
		for anim_name in source_library.get_animation_list():
			var remapped_animation: Animation = source_library.get_animation(anim_name).duplicate(true)
			_remap_animation_bones(remapped_animation, skeleton_path, source_skeleton, skeleton, bone_map)
			var clip_name: String = target_animation_name
			merged_library.add_animation(clip_name, remapped_animation)
			picked = true
			break

	source_instance.queue_free()

## Como _import_animation_library, mas retargeta osso a osso (bone_map + correção
## de rest) em vez de só remapear o caminho do nó — pra trazer a biblioteca
## Quaternius inteira (Walk/Run/Idle/Jump/Crouch...) pro rig Mixamo do char,
## preservando os nomes dos clipes (o código de locomoção/posse os procura por
## nome). Junta todas as libs da origem numa só `library_name`.
func _import_retargeted_library(instance: Node3D, skeleton: Skeleton3D, player: AnimationPlayer, source_path: String, library_name: String, bone_map: Dictionary) -> void:
	var source := load(source_path) as PackedScene
	if source == null:
		return
	var source_instance := source.instantiate()
	var source_skeleton := _find_skeleton(source_instance)
	var source_players: Array[AnimationPlayer] = []
	_collect_animation_players(source_instance, source_players)
	var source_player := _pick_usable_player(source_players)
	if source_player == null or source_skeleton == null:
		source_instance.queue_free()
		return

	var skeleton_path := String(instance.get_path_to(skeleton))

	var merged_library: AnimationLibrary
	if player.has_animation_library(library_name):
		merged_library = player.get_animation_library(library_name)
	else:
		merged_library = AnimationLibrary.new()
		player.add_animation_library(library_name, merged_library)

	for source_lib_name in source_player.get_animation_library_list():
		var source_library := source_player.get_animation_library(source_lib_name)
		for anim_name in source_library.get_animation_list():
			if merged_library.has_animation(anim_name):
				continue
			var remapped_animation: Animation = source_library.get_animation(anim_name).duplicate(true)
			_remap_animation_bones(remapped_animation, skeleton_path, source_skeleton, skeleton, bone_map)
			merged_library.add_animation(anim_name, remapped_animation)

	source_instance.queue_free()

## Traduz trilhas de ROTAÇÃO de ossos de `source_skeleton` (caminhos tipo
## "Armature/Skeleton3D:mixamorig_Hips") pro esqueleto deste modelo, usando
## `bone_map`. Descarta posição/escala (emote no lugar) e ossos sem mapeamento.
##
## RETARGET de verdade: os dois rigs têm rest poses diferentes (Mixamo T-pose,
## Quaternius A-pose) e convenções de eixo de osso diferentes. Copiar a rotação
## crua iguala a BASE global do osso, mas como a geometria do membro pende de
## eixos locais diferentes, o membro aponta torto. O certo é transferir o DELTA
## de cada osso em relação ao SEU rest: o quanto o osso girou a partir do rest
## no Mixamo, aplicar a partir do rest do nosso rig.
##
## Deriva (queremos G_alvo(b) = G_origem(b) · Rg_origem(b)⁻¹ · Rg_alvo(b), i.e.
## mesmo delta global a partir do rest), e como local = G(pai)⁻¹ · G(osso):
##   local_alvo(b) = Rg_alvo(pai)⁻¹ · Rg_origem(pai) · valor · Rg_origem(b)⁻¹ · Rg_alvo(b)
## onde Rg = rest global (rotação acumulada da raiz até o osso). Tudo só com
## dados de rest => dá pra computar por trilha, independente. Pro osso raiz
## (Mixamo Hips, sem pai) Rg_origem(pai)=identidade e o pai-alvo é o `root`
## (rest -90° X) — o pre-fator vira a inversa disso, cancelando o "deitado".
func _remap_animation_bones(animation: Animation, skeleton_path: String, source_skeleton: Skeleton3D, target_skeleton: Skeleton3D, bone_map: Dictionary) -> void:
	var track_idx := 0
	while track_idx < animation.get_track_count():
		var path_str := String(animation.track_get_path(track_idx))
		var colon_idx := path_str.find(":")
		if colon_idx == -1:
			animation.remove_track(track_idx)
			continue
		var bone_name := path_str.substr(colon_idx + 1)

		if animation.track_get_type(track_idx) != Animation.TYPE_ROTATION_3D or not bone_map.has(bone_name):
			animation.remove_track(track_idx)
			continue

		var target_bone_name: String = bone_map[bone_name]
		var source_bone_idx := source_skeleton.find_bone(bone_name)
		var target_bone_idx := target_skeleton.find_bone(target_bone_name)
		if source_bone_idx == -1 or target_bone_idx == -1:
			animation.remove_track(track_idx)
			continue

		var source_parent_idx := source_skeleton.get_bone_parent(source_bone_idx)
		var target_parent_idx := target_skeleton.get_bone_parent(target_bone_idx)
		var rg_source_bone := _global_rest_rotation(source_skeleton, source_bone_idx)
		var rg_target_bone := _global_rest_rotation(target_skeleton, target_bone_idx)
		var rg_source_parent := Quaternion.IDENTITY if source_parent_idx == -1 else _global_rest_rotation(source_skeleton, source_parent_idx)
		var rg_target_parent := Quaternion.IDENTITY if target_parent_idx == -1 else _global_rest_rotation(target_skeleton, target_parent_idx)

		var pre := rg_target_parent.inverse() * rg_source_parent
		var post := rg_source_bone.inverse() * rg_target_bone

		for key_idx in animation.track_get_key_count(track_idx):
			var original: Quaternion = animation.track_get_key_value(track_idx, key_idx)
			animation.track_set_key_value(track_idx, key_idx, pre * original * post)

		animation.track_set_path(track_idx, NodePath(skeleton_path + ":" + target_bone_name))
		track_idx += 1

## Rotação "rest global" de `bone_idx` — composição do rest dele com o de todos
## os seus ancestrais (da raiz até o osso, ignorando a pose da animação).
func _global_rest_rotation(skeleton: Skeleton3D, bone_idx: int) -> Quaternion:
	var rotation := Quaternion.IDENTITY
	var idx := bone_idx
	while idx != -1:
		rotation = skeleton.get_bone_rest(idx).basis.get_rotation_quaternion() * rotation
		idx = skeleton.get_bone_parent(idx)
	return rotation

func _play_walk_animation(player: AnimationPlayer) -> void:
	if player == null:
		return
	var names := player.get_animation_list()
	if names.is_empty():
		return
	for keyword in WALK_KEYWORDS:
		for anim_name in names:
			if anim_name.to_lower().contains(keyword):
				player.play(anim_name)
				return
	player.play(names[0])

## Sem isso, o NPC ficava em loop de "andar" mesmo parado esperando o
## pause_timer — parecia estar empurrando contra o morro sem sair do lugar.
func _play_idle_animation(player: AnimationPlayer) -> void:
	if player == null:
		return
	var names := player.get_animation_list()
	if names.is_empty():
		return
	for keyword in IDLE_KEYWORDS:
		for anim_name in names:
			if anim_name.to_lower().contains(keyword):
				player.play(anim_name)
				return

# --- Movimento -----------------------------------------------------------------

func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_angle := atan2(direction.x, direction.z)
	model_root.rotation.y = lerp_angle(model_root.rotation.y, target_angle, 0.15)

func _pick_new_target() -> void:
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(2.0, wander_radius)
	target_position = home_position + Vector3(offset.x, 0.0, offset.y)
	pause_timer = pause_time
