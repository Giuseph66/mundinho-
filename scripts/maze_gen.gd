@tool
extends Node3D

@export_tool_button("Gerar / Atualizar Labirinto") var regenerate_action: Callable = regenerate
@export var active: bool = true:
	set(value):
		active = value
		_apply_active()
@export_range(3, 25, 2) var width: int = 9
@export_range(3, 25, 2) var height: int = 9
@export_range(1.0, 6.0, 0.1) var cell_size: float = 3.5
@export_range(1.0, 20.0, 0.1) var wall_height: float = 6.0
@export_range(0.1, 2.0, 0.05) var wall_thickness: float = 0.4
@export var seed: int = 1
@export var wall_color: Color = Color(0.12, 0.35, 0.12)
@export var wall_line_color: Color = Color(0.02, 0.12, 0.03)
@export_range(0.5, 12.0, 0.1) var wall_texture_scale: float = 4.5
@export var guide_color: Color = Color(1.0, 0.85, 0.05)

const FLOOR_RAY_UP := 80.0
const FLOOR_RAY_DOWN := 200.0
const FLOOR_SINK := 0.3
const GUIDE_Y_OFFSET := 0.35
const DEFAULT_GUIDE_COLOR := Color(1.0, 0.85, 0.05)
const WALL_SHADER := preload("res://shaders/maze_wall.gdshader")

var solution_path: Array[Vector2i] = []
var guide_node: Node3D = null
var wall_index: int = 0

func _ready() -> void:
	_ensure_runtime_input()
	regenerate()

func _process(_delta: float) -> void:
	if InputMap.has_action("maze_guide") and Input.is_action_just_pressed("maze_guide"):
		_toggle_guide()
	if InputMap.has_action("randomize_maze") and Input.is_action_just_pressed("randomize_maze"):
		_randomize_seed()
	if InputMap.has_action("toggle_maze") and Input.is_action_just_pressed("toggle_maze"):
		_toggle_active()

func _ensure_runtime_input() -> void:
	_add_runtime_key("maze_guide", KEY_END)
	_add_runtime_key("randomize_maze", KEY_L)
	_add_runtime_key("toggle_maze", KEY_K)

func _add_runtime_key(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func regenerate() -> void:
	if not is_inside_tree():
		return
	wall_index = 0
	for child in get_children():
		child.queue_free()
	if not active:
		return

	var vertical_walls: Array[Array] = []
	var horizontal_walls: Array[Array] = []
	for z in range(height):
		var row: Array[bool] = []
		for _x in range(width + 1):
			row.append(true)
		vertical_walls.append(row)
	for z in range(height + 1):
		var row: Array[bool] = []
		for _x in range(width):
			row.append(true)
		horizontal_walls.append(row)

	solution_path = _carve_maze(vertical_walls, horizontal_walls)
	horizontal_walls[0][0] = false
	horizontal_walls[height][width - 1] = false
	_build_walls(vertical_walls, horizontal_walls)
	_build_guide()
	_apply_active()

func _carve_maze(vertical_walls: Array[Array], horizontal_walls: Array[Array]) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var visited: Array[Array] = []
	var came_from: Dictionary = {}
	for z in range(height):
		var row: Array[bool] = []
		for _x in range(width):
			row.append(false)
		visited.append(row)

	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	visited[0][0] = true

	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var neighbors: Array[Vector2i] = []
		for dir: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var next: Vector2i = current + dir
			if next.x >= 0 and next.x < width and next.y >= 0 and next.y < height and not visited[next.y][next.x]:
				neighbors.append(next)

		if neighbors.is_empty():
			stack.pop_back()
			continue

		var next: Vector2i = neighbors[rng.randi_range(0, neighbors.size() - 1)]
		if next.x > current.x:
			vertical_walls[current.y][current.x + 1] = false
		elif next.x < current.x:
			vertical_walls[current.y][current.x] = false
		elif next.y > current.y:
			horizontal_walls[current.y + 1][current.x] = false
		else:
			horizontal_walls[current.y][current.x] = false

		visited[next.y][next.x] = true
		came_from[next] = current
		stack.append(next)

	return _get_solution_path(came_from)

func _get_solution_path(came_from: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Vector2i = Vector2i(width - 1, height - 1)
	path.append(current)
	while current != Vector2i(0, 0):
		if not came_from.has(current):
			break
		current = came_from[current] as Vector2i
		path.append(current)
	path.reverse()
	return path

func _build_walls(vertical_walls: Array[Array], horizontal_walls: Array[Array]) -> void:
	var material := _build_wall_material()

	for z in range(height):
		for x in range(width + 1):
			if vertical_walls[z][x]:
				var pos := Vector3((x - width * 0.5) * cell_size, 0, (z - height * 0.5 + 0.5) * cell_size)
				_add_wall(pos, Vector3(wall_thickness, wall_height, cell_size + wall_thickness), material)

	for z in range(height + 1):
		for x in range(width):
			if horizontal_walls[z][x]:
				var pos := Vector3((x - width * 0.5 + 0.5) * cell_size, 0, (z - height * 0.5) * cell_size)
				_add_wall(pos, Vector3(cell_size + wall_thickness, wall_height, wall_thickness), material)

func _add_wall(local_pos: Vector3, box_size: Vector3, material: Material) -> void:
	var floor_y := _find_floor_y(local_pos)
	var body := StaticBody3D.new()
	body.name = "Wall%s" % wall_index
	wall_index += 1
	body.position = Vector3(local_pos.x, floor_y + wall_height * 0.5 - FLOOR_SINK, local_pos.z)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	add_child(body)
	if Engine.is_editor_hint():
		body.owner = get_tree().edited_scene_root
		collision.owner = get_tree().edited_scene_root
		mesh_instance.owner = get_tree().edited_scene_root

func _build_wall_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WALL_SHADER
	material.set_shader_parameter("base_color", wall_color)
	material.set_shader_parameter("line_color", wall_line_color)
	material.set_shader_parameter("brick_scale", wall_texture_scale)
	return material

func _build_guide() -> void:
	guide_node = Node3D.new()
	guide_node.name = "Guide"
	guide_node.visible = false
	add_child(guide_node)

	var material := StandardMaterial3D.new()
	var color: Color = DEFAULT_GUIDE_COLOR if guide_color == null else guide_color
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for i in range(solution_path.size()):
		var cell: Vector2i = solution_path[i]
		var next_cell: Vector2i = solution_path[min(i + 1, solution_path.size() - 1)]
		var marker := MeshInstance3D.new()
		var mesh := _build_arrow_mesh(material)
		marker.mesh = mesh
		var pos := _cell_center(cell)
		var floor_y := _find_floor_y(pos)
		marker.position = Vector3(pos.x, floor_y + GUIDE_Y_OFFSET, pos.z)
		marker.rotation.y = _direction_to_rotation(cell, next_cell)
		guide_node.add_child(marker)
		if Engine.is_editor_hint():
			marker.owner = get_tree().edited_scene_root

	if Engine.is_editor_hint():
		guide_node.owner = get_tree().edited_scene_root

func _toggle_guide() -> void:
	if guide_node == null:
		return
	guide_node.visible = not guide_node.visible

## Tecla K: some com o labirinto (visual + colisão) sem precisar editar a
## cena — útil pra testar a mansão sem o labirinto no caminho. Esconder só o
## visual deixaria paredes invisíveis travando o personagem; por isso também
## desliga cada CollisionShape3D da subárvore.
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

func _randomize_seed() -> void:
	seed = randi()
	regenerate()

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - width * 0.5 + 0.5) * cell_size, 0, (cell.y - height * 0.5 + 0.5) * cell_size)

func _build_arrow_mesh(material: StandardMaterial3D) -> ArrayMesh:
	var arrow_width := cell_size * 0.5
	var arrow_length := cell_size * 0.75
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	st.add_vertex(Vector3(0, 0, -arrow_length * 0.5))
	st.add_vertex(Vector3(-arrow_width * 0.5, 0, arrow_length * 0.5))
	st.add_vertex(Vector3(arrow_width * 0.5, 0, arrow_length * 0.5))
	st.add_vertex(Vector3(0, 0, -arrow_length * 0.5))
	st.add_vertex(Vector3(arrow_width * 0.5, 0, arrow_length * 0.5))
	st.add_vertex(Vector3(-arrow_width * 0.5, 0, arrow_length * 0.5))
	return st.commit()

func _direction_to_rotation(cell: Vector2i, next_cell: Vector2i) -> float:
	var dir: Vector2i = next_cell - cell
	if dir == Vector2i(1, 0):
		return deg_to_rad(-90.0)
	if dir == Vector2i(-1, 0):
		return deg_to_rad(90.0)
	if dir == Vector2i(0, 1):
		return deg_to_rad(180.0)
	return 0.0

func _find_floor_y(local_pos: Vector3) -> float:
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
