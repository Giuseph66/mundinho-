extends CharacterBody3D

const WALK_SPEED := 2.2
const CHASE_SPEED := 5.2
const ATTACK_RANGE := 1.6
const DETECT_RANGE := 14.0
const PATROL_DIST := 5.0
const ATTACK_COOLDOWN := 1.8
const LUNGE_SPEED := 11.0
const LUNGE_TIME := 0.18

@export var passive: bool = false
@export var attack_enabled: bool = true

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var patrol_origin: Vector3
var patrol_dir := 1.0
var hp := 2
var attack_timer := 0.0
var anim_time := 0.0
var is_lunging := false
var lunge_timer := 0.0
var lunge_direction := Vector3.ZERO
var visual_base_y := 0.0
var legs: Array[Node3D] = []
var body_parts: Array[Node3D] = []

@onready var damage_area: Area3D = $DamageArea
@onready var visual: Node3D = $Visual

func _ready() -> void:
	add_to_group("enemy")
	patrol_origin = global_position
	visual_base_y = visual.position.y
	damage_area.body_entered.connect(_on_body_entered)
	_collect_legs()
	_apply_texture()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if attack_timer > 0.0:
		attack_timer -= delta

	if is_lunging:
		lunge_timer -= delta
		velocity.x = lunge_direction.x * LUNGE_SPEED
		velocity.z = lunge_direction.z * LUNGE_SPEED
		if lunge_timer <= 0.0:
			is_lunging = false
		move_and_slide()
		_animate(delta, true)
		return

	var player := _get_player()
	if player != null and not passive:
		var dist := global_position.distance_to(player.global_position)
		if attack_enabled and dist < ATTACK_RANGE and attack_timer <= 0.0:
			_lunge(player)
		elif dist < DETECT_RANGE:
			_chase(player)
		else:
			_patrol()
	else:
		_patrol()

	move_and_slide()
	_animate(delta, is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.1)

func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as Node3D if not players.is_empty() else null

func _patrol() -> void:
	velocity.x = WALK_SPEED * patrol_dir
	velocity.z = 0.0
	if abs(global_position.x - patrol_origin.x) >= PATROL_DIST:
		patrol_dir *= -1.0

func _chase(player: Node3D) -> void:
	var dir := player.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() <= 0.01:
		return
	dir = dir.normalized()
	velocity.x = dir.x * CHASE_SPEED
	velocity.z = dir.z * CHASE_SPEED
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 0.18)

func _lunge(player: Node3D) -> void:
	attack_timer = ATTACK_COOLDOWN
	is_lunging = true
	lunge_timer = LUNGE_TIME
	lunge_direction = player.global_position - global_position
	lunge_direction.y = 0.0
	if lunge_direction.length_squared() > 0.01:
		lunge_direction = lunge_direction.normalized()
	velocity.y = 4.5

func _apply_texture() -> void:
	var tex := load("res://assets/mobs/aranha-esqueleto/spider_0.jpg") as Texture2D
	var mat := StandardMaterial3D.new()
	if tex != null:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.35, 0.22, 0.12)
	mat.roughness = 0.85
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = mat

func _collect_legs() -> void:
	const LEG_PARTS := ["part_1", "part_2", "part_3", "part_4", "part_5", "part_6", "part_15"]
	var mesh_root := visual.get_node_or_null("SpiderMesh")
	if mesh_root == null:
		return
	for child in mesh_root.find_children("*", "Node3D", true, false):
		var node := child as Node3D
		if node == null:
			continue
		if node.name in LEG_PARTS:
			legs.append(node)
		elif node.name != "part_0":
			body_parts.append(node)

func _animate(delta: float, moving: bool) -> void:
	var speed_mult := 2.5 if is_lunging else (1.8 if moving else 0.6)
	anim_time += delta * speed_mult * 6.0

	var bob := 0.045 if moving else 0.01
	visual.position.y = visual_base_y + sin(anim_time * 2.0) * bob

	var rock := 0.10 if moving else 0.02
	visual.rotation.z = sin(anim_time) * rock

	var tilt := -0.18 if (moving and not is_lunging) else (0.25 if is_lunging else 0.0)
	visual.rotation.x = lerp(visual.rotation.x, tilt, delta * 8.0)

	if is_lunging:
		var pulse := 1.0 + sin(anim_time * 18.0) * 0.08
		visual.scale = Vector3(pulse, pulse * 0.88, pulse)
	else:
		visual.scale = visual.scale.lerp(Vector3.ONE, delta * 10.0)

	_animate_legs()

func _animate_legs() -> void:
	var count := float(max(legs.size(), 1))
	for i in legs.size():
		var leg := legs[i]
		var phase := float(i) * (PI / (count * 0.5))
		var speed_factor := 2.0 if is_lunging else 1.0
		leg.rotation.x = sin(anim_time * speed_factor + phase) * 0.55
		leg.rotation.z = cos(anim_time * speed_factor + phase) * 0.20
	for i in body_parts.size():
		var body_part := body_parts[i]
		var phase := float(i) * 0.8
		body_part.rotation.z = sin(anim_time * 0.8 + phase) * 0.04

func _on_body_entered(body: Node3D) -> void:
	if attack_enabled and not passive and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
