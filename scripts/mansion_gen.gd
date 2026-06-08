@tool
extends Node3D

## Gera uma mansão simples (paredes, andares, escadas, telhado) sobre o
## terreno. Nivelada pelo ponto mais alto sob a área ocupada — assim a casa
## nunca afunda no relevo gerado por ruído; o desnível nos cantos mais baixos
## é coberto por uma fundação.

@export_tool_button("Gerar / Atualizar Mansao") var regenerate_action: Callable = regenerate
@export var active: bool = true:
	set(value):
		active = value
		_apply_active()
@export_range(6.0, 30.0, 0.5) var width: float = 14.0
@export_range(6.0, 30.0, 0.5) var depth: float = 12.0
@export_range(1, 5, 1) var floor_count: int = 2
@export_range(2.0, 10.0, 0.1) var wall_height: float = 5.0
@export_range(0.2, 2.0, 0.1) var wall_thickness: float = 0.5
@export_range(0.2, 4.0, 0.1) var roof_height: float = 2.0
@export_range(1.0, 6.0, 0.1) var stair_width: float = 2.0
@export var wall_color: Color = Color(0.66, 0.62, 0.52)
@export var roof_color: Color = Color(0.32, 0.08, 0.06)
@export var floor_color: Color = Color(0.22, 0.18, 0.14)
@export var stair_color: Color = Color(0.34, 0.25, 0.18)

const FLOOR_THICKNESS := 0.25
const FLOOR_SINK := 0.25
## A laje fica enterrada (FLOOR_SINK) na parede — sua superfície de cima fica
## abaixo do nível "nominal" do andar. Sem compensar isso, o pé da escada
## (que usava o nível nominal) ficava ~0.12 acima do piso de verdade — uma
## beirada que travava o personagem ao se aproximar.
const FLOOR_SURFACE_OFFSET := FLOOR_THICKNESS * 0.5 - FLOOR_SINK
const FLOOR_RAY_UP := 80.0
const FLOOR_RAY_DOWN := 200.0
## Degraus mais baixos (e mais numeros) que floor_snap_length do personagem
## (0.5) — assim ele "flui" escada acima em vez de travar em cada degrau.
const STAIR_STEPS := 25
const STAIR_WALL_GAP := 0.05
const STAIR_MARGIN := 0.4
const FRONT_DOOR_WIDTH := 3.0
const ROOM_DOOR_WIDTH := 1.6
const HALL_WIDTH := 3.0
const MIN_SEGMENT := 0.5

func _ready() -> void:
	_ensure_runtime_input()
	regenerate()

func _process(_delta: float) -> void:
	if InputMap.has_action("toggle_mansion") and Input.is_action_just_pressed("toggle_mansion"):
		_toggle_active()

func _ensure_runtime_input() -> void:
	_add_runtime_key("toggle_mansion", KEY_M)

func _add_runtime_key(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

## Tecla M: some com a mansão (visual + colisão) — útil pra testar o
## labirinto sem ela no caminho (mesma ideia da tecla K em maze_gen.gd: visual
## sozinho deixaria paredes invisíveis travando o personagem, por isso
## desligamos cada CollisionShape3D da subárvore também).
func _toggle_active() -> void:
	active = not active
	if active and get_child_count() == 0:
		regenerate()

func _apply_active() -> void:
	visible = active
	_set_collision_enabled(self, active)

func _set_collision_enabled(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enabled
	for child in node.get_children():
		_set_collision_enabled(child, enabled)

func regenerate() -> void:
	if not is_inside_tree():
		return
	# remove_child() já libera o nome na hora (o nó sai da hashtable do pai),
	# então recriar com o MESMO nome no mesmo frame não colide mais. Mas
	# `free()` imediato corrompe a hashtable interna do editor ("Children name
	# does not match parent name in hashtable") — por isso queue_free(), que
	# só desaloca no fim do frame, depois do remove_child já ter limpo o nome.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not active:
		return

	var half_w := width * 0.5
	var half_d := depth * 0.5
	var levels := _measure_terrain(half_w, half_d)
	var base_y: float = levels["highest"]
	_add_foundation(base_y, levels["lowest"])

	# Geometria das escadas é calculada uma vez só; andares e degraus leem do
	# mesmo lugar, então o vão no piso sempre bate com o lance de verdade.
	var stairs := _plan_stairs(base_y, half_w)

	for floor_index in range(floor_count):
		var floor_base_y := base_y + floor_index * wall_height
		var wall_y := floor_base_y + wall_height * 0.5

		if floor_index == 0:
			_add_box("Floor%s" % floor_index, Vector3(0, floor_base_y - FLOOR_SINK, 0), Vector3(width, FLOOR_THICKNESS, depth), floor_color, true)
		else:
			_add_upper_floor(floor_index, floor_base_y, stairs[floor_index - 1], half_w, half_d)

		_add_box("BackWall%s" % floor_index, Vector3(0, wall_y, -half_d), Vector3(width, wall_height, wall_thickness), wall_color, true)
		_add_box("LeftWall%s" % floor_index, Vector3(-half_w, wall_y, 0), Vector3(wall_thickness, wall_height, depth), wall_color, true)
		_add_box("RightWall%s" % floor_index, Vector3(half_w, wall_y, 0), Vector3(wall_thickness, wall_height, depth), wall_color, true)
		# Vão na fachada em TODOS os andares (porta no térreo, janela/sacada
		# em cima) — a versão antiga só abria vão no térreo; de cima a casa
		# era uma caixa fechada.
		_add_wall_x_with_gap("FrontWall%s" % floor_index, half_d, wall_y, -half_w, half_w, 0.0, FRONT_DOOR_WIDTH)

		_add_rooms(floor_index, wall_y, half_d)

	for stair in stairs:
		_add_stair(stair)

	var roof_y := base_y + floor_count * wall_height + roof_height * 0.5
	_add_box("Roof", Vector3(0, roof_y, 0), Vector3(width + 1.2, roof_height, depth + 1.2), roof_color, false)
	_apply_active()

# --- Nivelamento / fundação ---------------------------------------------------

## Amostra o relevo nos 4 cantos + centro da área ocupada pela casa. Usa o
## ponto mais alto como base — assim nenhum canto afunda no morro — e guarda
## o mais baixo pra dimensionar a fundação que cobre o vão dos cantos baixos
## (a versão antiga amostrava só o centro: em ladeira, um lado ficava no ar
## e o outro enterrado).
func _measure_terrain(half_w: float, half_d: float) -> Dictionary:
	var samples: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(-half_w, 0.0, -half_d),
		Vector3(half_w, 0.0, -half_d),
		Vector3(-half_w, 0.0, half_d),
		Vector3(half_w, 0.0, half_d),
	]
	var highest := -INF
	var lowest := INF
	for sample in samples:
		var y := _raycast_floor_y(sample)
		highest = maxf(highest, y)
		lowest = minf(lowest, y)
	return {"highest": highest, "lowest": lowest}

## Bloco que preenche o desnível entre a base da casa e o ponto mais baixo do
## terreno sob ela. Sem isso, em ladeira, dava pra ver o vão por baixo da casa.
func _add_foundation(base_y: float, lowest_y: float) -> void:
	var height := (base_y - lowest_y) + FLOOR_THICKNESS
	if height < MIN_SEGMENT:
		return
	_add_box("Foundation", Vector3(0, base_y - height * 0.5, 0), Vector3(width + wall_thickness, height, depth + wall_thickness), wall_color.darkened(0.35), true)

func _raycast_floor_y(local_pos: Vector3) -> float:
	var world_pos := global_transform * local_pos
	var query := PhysicsRayQueryParameters3D.create(
		world_pos + Vector3.UP * FLOOR_RAY_UP,
		world_pos + Vector3.DOWN * FLOOR_RAY_DOWN
	)
	query.exclude = _collect_collision_excludes()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return global_position.y if hit.is_empty() else hit.position.y

func _collect_collision_excludes() -> Array[RID]:
	var excludes: Array[RID] = []
	for child in get_children():
		if child is CollisionObject3D:
			excludes.append(child.get_rid())
	return excludes

# --- Escadas -------------------------------------------------------------------

## Calcula a geometria de cada lance ANTES de desenhar qualquer coisa.
func _plan_stairs(base_y: float, half_w: float) -> Array[Dictionary]:
	var stair_run := depth * 0.64
	# Encosta o lance na parede lateral do cômodo (em vez de flutuar no meio
	# dele) — só falta o vão de STAIR_WALL_GAP pra não brigar com a parede.
	var wall_x := half_w - wall_thickness - stair_width * 0.5 - STAIR_WALL_GAP
	var stairs: Array[Dictionary] = []
	for floor_index in range(floor_count - 1):
		# Lance fica no cômodo OPOSTO ao do lance anterior — direita nos
		# índices pares, esquerda nos ímpares. Zigue-zague entre os cômodos
		# em vez de empilhar todo mundo do mesmo lado.
		var side := 1 if floor_index % 2 == 0 else -1
		var stair_x := side * wall_x
		var direction := 1 if floor_index % 2 == 0 else -1
		var start_z := -depth * 0.32 if direction == 1 else depth * 0.32
		var end_z := start_z + direction * stair_run
		stairs.append({
			"floor_index": floor_index,
			# Encostado na SUPERFÍCIE do piso de baixo (não no nível nominal),
			# pra não sobrar beirada no pé — e o topo acaba flush com a
			# superfície do andar de cima, porque os dois usam o mesmo offset.
			"base_y": base_y + floor_index * wall_height + FLOOR_SURFACE_OFFSET,
			"direction": direction,
			"x": stair_x,
			"z_min": minf(start_z, end_z),
			"z_max": maxf(start_z, end_z),
		})
	return stairs

func _add_stair(stair: Dictionary) -> void:
	var direction: int = stair["direction"]
	var z_min: float = stair["z_min"]
	var z_max: float = stair["z_max"]
	var step_depth := (z_max - z_min) / STAIR_STEPS
	var step_height := wall_height / STAIR_STEPS
	var start_z: float = z_min if direction == 1 else z_max

	var body := StaticBody3D.new()
	body.name = "Stair%s" % stair["floor_index"]
	for i in range(STAIR_STEPS):
		var step_size := Vector3(stair_width, step_height, step_depth)
		var step_pos := Vector3(0.0, step_height * (i + 0.5), direction * step_depth * (i + 0.5))

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = step_size
		collision.shape = shape
		collision.position = step_pos
		body.add_child(collision)

		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = stair_color
		material.roughness = 0.85
		mesh.size = step_size
		mesh.material = material
		mesh_instance.mesh = mesh
		mesh_instance.position = step_pos
		body.add_child(mesh_instance)

	body.position = Vector3(float(stair["x"]), float(stair["base_y"]), start_z)
	add_child(body)

# --- Andares / paredes / cômodos ------------------------------------------------

## Andar de cima com vão recortado exatamente no contorno da escada (mais
## margem): decompõe o piso em até 4 retângulos ao redor do buraco (esquerda,
## direita, faixa da frente, faixa de trás). A versão antiga só cobria
## esquerda/direita ao longo de TODA a profundidade — sobrava buraco vazio
## nas pontas do vão, onde não havia degrau embaixo.
func _add_upper_floor(floor_index: int, base_y: float, stair: Dictionary, half_w: float, half_d: float) -> void:
	var stair_x: float = stair["x"]
	var hole_half_width := stair_width * 0.5 + STAIR_MARGIN
	var hole_x_min := stair_x - hole_half_width
	var hole_x_max := stair_x + hole_half_width
	var hole_z_min: float = float(stair["z_min"]) - STAIR_MARGIN
	var hole_z_max: float = float(stair["z_max"]) + STAIR_MARGIN
	var hole_width := hole_x_max - hole_x_min
	var y := base_y - FLOOR_SINK

	if hole_x_min - (-half_w) > MIN_SEGMENT:
		var w := hole_x_min - (-half_w)
		_add_box("Floor%sLeft" % floor_index, Vector3(-half_w + w * 0.5, y, 0.0), Vector3(w, FLOOR_THICKNESS, depth), floor_color, true)
	if half_w - hole_x_max > MIN_SEGMENT:
		var w := half_w - hole_x_max
		_add_box("Floor%sRight" % floor_index, Vector3(hole_x_max + w * 0.5, y, 0.0), Vector3(w, FLOOR_THICKNESS, depth), floor_color, true)
	if half_d - hole_z_max > MIN_SEGMENT:
		var d := half_d - hole_z_max
		_add_box("Floor%sFront" % floor_index, Vector3(stair_x, y, hole_z_max + d * 0.5), Vector3(hole_width, FLOOR_THICKNESS, d), floor_color, true)
	if hole_z_min - (-half_d) > MIN_SEGMENT:
		var d := hole_z_min - (-half_d)
		_add_box("Floor%sBack" % floor_index, Vector3(stair_x, y, -half_d + d * 0.5), Vector3(hole_width, FLOOR_THICKNESS, d), floor_color, true)

## Hall central + um cômodo de cada lado, cada um com UMA porta só (pro hall).
## A versão antiga usava 2 segmentos de divisória que, sem querer, deixavam
## 3 vãos por cômodo (parecia labirinto, não cômodo fechado).
func _add_rooms(floor_index: int, wall_y: float, half_d: float) -> void:
	var inner_z_start := -half_d + wall_thickness
	var inner_z_end := half_d - wall_thickness
	for side: int in [-1, 1]:
		var label := "Left" if side < 0 else "Right"
		var x: float = side * HALL_WIDTH * 0.5
		_add_wall_z_with_gap("%sDivider%s" % [label, floor_index], x, wall_y, inner_z_start, inner_z_end, 0.0, ROOM_DOOR_WIDTH)
	if floor_index == 0:
		_add_box("GrandHallArch%s" % floor_index, Vector3(0, wall_y + wall_height * 0.25, 0.0), Vector3(HALL_WIDTH * 1.4, wall_height * 0.5, wall_thickness), wall_color, true)

## Parede ao longo do eixo X (fachada) com vão centralizado — porta/janela.
## Gera 0, 1 ou 2 segmentos dependendo de quanto sobra de cada lado do vão.
func _add_wall_x_with_gap(name_prefix: String, z: float, wall_y: float, x_start: float, x_end: float, gap_center: float, gap_width: float) -> void:
	var gap_start := gap_center - gap_width * 0.5
	var gap_end := gap_center + gap_width * 0.5
	if gap_start - x_start > MIN_SEGMENT:
		var seg := gap_start - x_start
		_add_box(name_prefix + "Left", Vector3(x_start + seg * 0.5, wall_y, z), Vector3(seg, wall_height, wall_thickness), wall_color, true)
	if x_end - gap_end > MIN_SEGMENT:
		var seg := x_end - gap_end
		_add_box(name_prefix + "Right", Vector3(gap_end + seg * 0.5, wall_y, z), Vector3(seg, wall_height, wall_thickness), wall_color, true)

## Parede ao longo do eixo Z (divisória interna) com vão centralizado — porta.
func _add_wall_z_with_gap(name_prefix: String, x: float, wall_y: float, z_start: float, z_end: float, gap_center: float, gap_width: float) -> void:
	var gap_start := gap_center - gap_width * 0.5
	var gap_end := gap_center + gap_width * 0.5
	if gap_start - z_start > MIN_SEGMENT:
		var seg := gap_start - z_start
		_add_box(name_prefix + "Back", Vector3(x, wall_y, z_start + seg * 0.5), Vector3(wall_thickness, wall_height, seg), wall_color, true)
	if z_end - gap_end > MIN_SEGMENT:
		var seg := z_end - gap_end
		_add_box(name_prefix + "Front", Vector3(x, wall_y, gap_end + seg * 0.5), Vector3(wall_thickness, wall_height, seg), wall_color, true)

# --- Construção primitiva -------------------------------------------------------
# Nota: NÃO setamos `owner` nos nós gerados. _ready() roda regenerate() toda
# vez que a cena carrega, então persistir esses nós no .tscn é desnecessário —
# e foi exatamente isso que causou os erros "BackWall2 já na cena": salvos
# tanto em mansion.tscn quanto (como override local) na cena que a instancia,
# colidindo no carregamento. Sem owner, eles existem em runtime/preview mas
# nunca são serializados — zero risco de duplicata.

func _add_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color, collidable: bool) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos

	if collidable:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.size = box_size
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	add_child(body)
