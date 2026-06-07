@tool
extends Node3D

@export_tool_button("Gerar / Atualizar Terreno") var regenerate_action: Callable = _regenerate

@export_range(8.0, 256.0, 1.0) var size: float = 64.0
@export_range(4, 128, 1) var resolution: int = 48
@export_range(0.0, 30.0, 0.1) var height_scale: float = 5.0
@export_range(0.001, 0.5, 0.001) var noise_frequency: float = 0.06
@export var noise_seed: int = 0
@export_range(0, 4, 1) var smoothing_passes: int = 2
@export var terrain_color: Color = Color(0.36, 0.55, 0.28)
@export_range(0.0, 1.0, 0.01) var terrain_roughness: float = 0.9

func _ready() -> void:
	_regenerate()

func _regenerate() -> void:
	if not is_inside_tree():
		return
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return

	for child in mesh_instance.get_children():
		if child is StaticBody3D or child.name == "EdgeWalls":
			child.queue_free()

	var noise := FastNoiseLite.new()
	noise.seed = noise_seed if noise_seed != 0 else randi()
	noise.frequency = noise_frequency
	# FBM com vários oitavos suaviza o relevo (colinas em vez de picos crus
	# de um único nível de ruído, que ficavam "grotescos").
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	mesh_instance.mesh = _build_mesh(noise)
	mesh_instance.create_trimesh_collision()
	_create_edge_walls(mesh_instance)

func _build_mesh(noise: FastNoiseLite) -> ArrayMesh:
	var step := size / resolution
	var half := size * 0.5
	var vertex_count := resolution + 1

	var heights := _sample_heights(noise, vertex_count, step, half)
	for _pass in smoothing_passes:
		heights = _smooth_heights(heights, vertex_count)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Um vértice por ponto da grade (em vez de 6 por quad): com índices
	# compartilhados, generate_normals() interpola normais entre faces
	# vizinhas — sombreamento suave em vez de "low-poly facetado".
	for iz in range(vertex_count):
		for ix in range(vertex_count):
			var x := -half + ix * step
			var z := -half + iz * step
			st.set_uv(Vector2(float(ix) / resolution, float(iz) / resolution))
			st.add_vertex(Vector3(x, heights[iz][ix], z))

	for iz in range(resolution):
		for ix in range(resolution):
			var i00 := iz * vertex_count + ix
			var i10 := i00 + 1
			var i01 := i00 + vertex_count
			var i11 := i01 + 1
			st.add_index(i00); st.add_index(i10); st.add_index(i01)
			st.add_index(i10); st.add_index(i11); st.add_index(i01)

	st.generate_normals()
	st.set_material(_build_material())
	return st.commit()

func _sample_heights(noise: FastNoiseLite, vertex_count: int, step: float, half: float) -> Array[PackedFloat32Array]:
	var heights: Array[PackedFloat32Array] = []
	for iz in range(vertex_count):
		var row := PackedFloat32Array()
		row.resize(vertex_count)
		for ix in range(vertex_count):
			var x := -half + ix * step
			var z := -half + iz * step
			row[ix] = noise.get_noise_2d(x, z) * height_scale
		heights.append(row)
	return heights

## Borrão 3x3: reduz picos/vales abruptos entre vizinhos sem achatar o relevo
## como um todo — é o que tira a aparência "grotesca" de blocos pontudos.
func _smooth_heights(heights: Array[PackedFloat32Array], vertex_count: int) -> Array[PackedFloat32Array]:
	var smoothed: Array[PackedFloat32Array] = []
	for iz in range(vertex_count):
		var row := PackedFloat32Array()
		row.resize(vertex_count)
		for ix in range(vertex_count):
			var total := 0.0
			var count := 0
			for dz in range(-1, 2):
				var nz := iz + dz
				if nz < 0 or nz >= vertex_count:
					continue
				for dx in range(-1, 2):
					var nx := ix + dx
					if nx < 0 or nx >= vertex_count:
						continue
					total += heights[nz][nx]
					count += 1
			row[ix] = total / count
		smoothed.append(row)
	return smoothed

func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = terrain_color
	material.roughness = terrain_roughness
	return material

func _create_edge_walls(parent: Node3D) -> void:
	var walls := Node3D.new()
	walls.name = "EdgeWalls"
	parent.add_child(walls)

	var half := size * 0.5
	var wall_height := 20.0
	var wall_thickness := 2.0
	_add_wall(walls, Vector3(0, wall_height * 0.5, -half), Vector3(size, wall_height, wall_thickness))
	_add_wall(walls, Vector3(0, wall_height * 0.5, half), Vector3(size, wall_height, wall_thickness))
	_add_wall(walls, Vector3(-half, wall_height * 0.5, 0), Vector3(wall_thickness, wall_height, size))
	_add_wall(walls, Vector3(half, wall_height * 0.5, 0), Vector3(wall_thickness, wall_height, size))

func _add_wall(parent: Node3D, position: Vector3, extents: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = extents
	shape.shape = box
	body.position = position
	body.add_child(shape)
	parent.add_child(body)
