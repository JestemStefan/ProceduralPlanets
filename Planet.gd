tool
extends Spatial

export var resolution: int = 2 setget set_resolution, get_resolution
export var _seed: int = 123456789 setget set_seed
export(int, 1, 64, 1) var _octaves = 4 setget set_octaves
export var _period: float = 1 setget set_period
export var _persistance: float = 0.8 setget set_persistance
export var _lacunarity: float = 2 setget set_lacunarity
export var _noise_strength: float = 0.5 setget set_noise_strength

var mdt: MeshDataTool = MeshDataTool.new()
var st: SurfaceTool = SurfaceTool.new()
var ground_noise: OpenSimplexNoise = OpenSimplexNoise.new()

export var surface_colors: Gradient

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass


func generate_sphere_mesh():
	ground_noise.seed = _seed
	ground_noise.octaves = _octaves
	ground_noise.period = _period
	ground_noise.persistence = _persistance
	ground_noise.lacunarity = _lacunarity

	var original_mesh: CubeMesh = CubeMesh.new()
	
	original_mesh.subdivide_depth = resolution
	original_mesh.subdivide_height = resolution
	original_mesh.subdivide_width = resolution
	
	var array_mesh: ArrayMesh = ArrayMesh.new()
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, original_mesh.get_mesh_arrays())
	
	mdt.create_from_surface(array_mesh, 0)
	
	var min_elevation :float = 0
	var max_elevation: float = 0
	
	# Threads
	var threads_amount: int = OS.get_processor_count()
	var vertex_count: int = mdt.get_vertex_count()
	
	var start_idx: int = 0
	var end_idx: int = 0
	
	var chunk_size: int = ceil(vertex_count/threads_amount)
	
	var thread_activated: Array = []
	
	for t in range(threads_amount - 1):
		var new_thread: Thread = Thread.new()
		thread_activated.append(new_thread)
		
		end_idx += chunk_size
		
		if end_idx > vertex_count:
			end_idx = vertex_count
		
		new_thread.start(self, "threaded_update_mesh", [start_idx, end_idx])
		
		start_idx = end_idx
	
	end_idx += chunk_size
		
	if end_idx > vertex_count:
		end_idx = vertex_count
	
	for i in range(start_idx, end_idx):
		
		var vertex: Vector3 = mdt.get_vertex(i)
		var v_normal: Vector3 = mdt.get_vertex_normal(i)
		vertex = vertex.normalized()
		mdt.set_vertex_normal(i, vertex)
		
		var elevation: float = ground_noise.get_noise_3dv(vertex)
		
		#min_elevation = min(min_elevation, elevation)
		#max_elevation = max(max_elevation, elevation)
		
		var point_on_gradient: float = range_lerp(elevation, -0.5, 0.5, 0, 1)
		
		mdt.set_vertex_color(i, surface_colors.interpolate(point_on_gradient))
		
		if elevation < 0:
			elevation = 0
		
		vertex += mdt.get_vertex_normal(i) * elevation * _noise_strength
		
		mdt.set_vertex(i, vertex)
	
	for t in thread_activated:
		(t as Thread).wait_to_finish()

	
	array_mesh.surface_remove(0)
	mdt.commit_to_surface(array_mesh)
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_smooth_group(true)
	st.append_from(array_mesh, 0, transform)
	
	
	st.generate_normals()
	array_mesh.surface_remove(0)
	st.commit(array_mesh)
	
	$PlanetMesh.mesh = array_mesh


func threaded_update_mesh(start_stop: Array):
	for i in range(start_stop[0], start_stop[1]):
		
		var vertex: Vector3 = mdt.get_vertex(i)
		var v_normal: Vector3 = mdt.get_vertex_normal(i)
		vertex = vertex.normalized()
		mdt.set_vertex_normal(i, vertex)
		
		var elevation: float = ground_noise.get_noise_3dv(vertex)
		
		#min_elevation = min(min_elevation, elevation)
		#max_elevation = max(max_elevation, elevation)
		
		var point_on_gradient: float = range_lerp(elevation, -0.5, 0.5, 0, 1)
		
		mdt.set_vertex_color(i, surface_colors.interpolate(point_on_gradient))
		
		if elevation < 0:
			elevation = 0
		
		vertex += mdt.get_vertex_normal(i) * elevation * _noise_strength
		
		mdt.set_vertex(i, vertex)
	
	print("ThreadDone")


func get_resolution():
	return resolution
	
func set_resolution(res):
	resolution = res
	generate_sphere_mesh()

func set_seed(s):
	_seed = s
	generate_sphere_mesh()
	
func set_octaves(o):
	_octaves = o
	generate_sphere_mesh()

func set_period(period):
	_period = period
	generate_sphere_mesh()

func set_persistance(p):
	_persistance = p
	generate_sphere_mesh()
	
func set_lacunarity(l):
	_lacunarity = l
	generate_sphere_mesh()
	
func set_noise_strength(ns):
	_noise_strength = ns
	generate_sphere_mesh()
