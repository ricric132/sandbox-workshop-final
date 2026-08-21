extends Node3D

@onready var cam: Camera3D = $"../Camera3D"
@onready var grid_corner: Node3D = $"../Grid/Floor/GridCorner"
@onready var building_parent: Node3D = $"../Grid/BuildingParent"

var grid : Array[Array] = []
const WIDTH = 30
const HEIGHT = 30
const TILE_SIZE = 1

var selected_building : building_template
@export var all_buildings : Array[building_template]

@export var preview_parent : Node
var active_preview : Node

const button_scene := preload("res://building_selector.tscn")
@export var button_container : Node

enum rot_dir {FORWARD = 0, RIGHT = 1, BACK = 2, LEFT = 3}
const rot_offset = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]
#basis for determinining x and y directions after roatation of a building
const rot_basis = [	[Vector2i(1, 0), Vector2i(0, 1)],
					[Vector2i(0, -1), Vector2i(1, 0)],
					[Vector2i(-1, 0), Vector2i(0, -1)],
					[Vector2i(0, 1), Vector2i(-1, 0)]
					]

var cur_rot : rot_dir = rot_dir.FORWARD

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_grid()
	setup_buttons()

func setup_grid() -> void:
	#create 2D array of size WIDTHxHEIGHT and populating with tile objects
	grid.resize(WIDTH)
	for x in range(WIDTH):
		grid[x]=Array()
		grid[x].resize(HEIGHT)
		for y in range(HEIGHT):
			grid[x][y] = Tile.new(x, y)

func setup_buttons() -> void:
	for building in all_buildings:
		var button = button_scene.instantiate()
		button_container.add_child(button)
		button.setup(building, self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var mousePos = get_viewport().get_mouse_position()
	
	# raycast to find where pointer is on the floor 
	var space_state = get_world_3d().direct_space_state
	var from = cam.project_ray_origin(mousePos)
	var to = from + cam.project_ray_normal(mousePos) * 1000
	var ray = PhysicsRayQueryParameters3D.create(from, to)
	ray.collision_mask = (1 << 1-1)
	var result = space_state.intersect_ray(ray)
	
	# rotate the build object
	if(Input.is_action_just_pressed("rot")):
		change_rot()
	
	# Checks if the cursor is on the platform and a buildig  is selected
	if(result && selected_building):
		# shows the preview build
		var coords : Vector2i = world_to_grid_coords(result.position)
		preview_parent.position = grid_to_world_position(coords.x, coords.y, cur_rot)
		preview_parent.rotation_degrees = Vector3(0, cur_rot*90, 0)
		preview_parent.show()
		active_preview.toggle_preview(check_valid(coords.x, coords.y, selected_building))
		
		# if player presses we attempt to build
		if Input.is_action_just_pressed("click"):
			build(coords.x, coords.y, selected_building)
	else:
		preview_parent.hide()
		



func build(x : int, y : int, building : building_template) -> void:
	# checks if the attempted build spot is valid
	if !check_valid(x, y, building):
		return
	
	# spawns in the building
	var built : Node = building.build_object.instantiate()
	building_parent.add_child(built)
	built.global_position = grid_to_world_position(x, y, cur_rot)
	built.rotation_degrees = Vector3(0, cur_rot*90, 0)
	
	# update grid tiles to track what tiles are occupied by what buildings
	for i in range(building.dimension.x):
		for j in range(building.dimension.y):
			var check_coord : Vector2i = Vector2i(x, y)
			
			# uses our basis to which direction the x and y of
			# the building face
			check_coord += rot_basis[cur_rot][0] * i
			check_coord += rot_basis[cur_rot][1] * j
			
			grid[check_coord.x][check_coord.y].building = built

func check_valid(x : int, y : int, building : building_template):
	for i in range(building.dimension.x):
		for j in range(building.dimension.y):
			var check_coord : Vector2i = Vector2i(x, y)
			
			# uses our basis to which direction the x and y of
			# the building face
			check_coord += rot_basis[cur_rot][0] * i
			check_coord += rot_basis[cur_rot][1] * j
			
			#checks in range and not occupied
			if check_coord.x >= WIDTH || check_coord.x < 0:
				return false
			if check_coord.y >= HEIGHT || check_coord.y < 0:
				return false
			if !grid[check_coord.x][check_coord.y].is_empty():
				return false
	
	return true

func grid_to_world_position(x : int, y : int, rot : rot_dir = rot_dir.FORWARD) -> Vector3:
	#offset the grid coordinates based off of rotation to recentre corner of building
	var offsetted_coord = Vector3(x, 0, y) + Vector3(rot_offset[rot].x, 0 ,rot_offset[rot].y)
	return grid_corner.global_position + offsetted_coord * TILE_SIZE

func world_to_grid_coords(pos : Vector3) -> Vector2i:
	var recentered_pos : Vector3 = pos - grid_corner.global_position
	return Vector2i(recentered_pos.x/TILE_SIZE, recentered_pos.z/TILE_SIZE)

func select_building(building : building_template):
	selected_building = building
	if(active_preview):
		active_preview.queue_free()
	
	active_preview = building.build_preview.instantiate()
	preview_parent.add_child(active_preview)


func change_rot():
	cur_rot = (cur_rot+1)%4
