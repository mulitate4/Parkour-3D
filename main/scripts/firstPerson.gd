extends KinematicBody

var h_rot

# SPEED
export var speed_type = {"walk": 7, "sprint": 20}
onready var speed = speed_type["walk"]

# ACCELERATION
var accel_type = {"default": 40, "air": 20}
onready var accel = accel_type["default"]

# JUMPING
var gravity = 30
var jump = 10
var double_jump = 2

# WALL RUN
var tilt = 0
var max_tilt = 4
var was_on_wall: bool
var wall_jump_strength: int = 15

# SETTINGS
var mouse_sens = 0.05
var min_fov = 70

# VECTORS
var direction = Vector3()
var velocity = Vector3()
var grav_vec = Vector3()
var movement = Vector3()

# NODES
onready var head = $Head
onready var camera = $Head/Camera
onready var leftDetectRay = $Head/leftDetect
onready var rightDetectRay = $Head/rightDetect


# CUSTOM FUNCTIONS
func is_moving() -> bool:
	return movement != Vector3.ZERO

func untilt_camera(delta):
	if tilt > 0 or tilt < 0:
		tilt = lerp(tilt, 0, (2*delta)/0.2)

func wall_run(delta):
	head.rotation.z = deg2rad(tilt)

	if (not Input.is_action_pressed("move_forward")) or (is_on_floor()) or (not is_on_wall()):
		untilt_camera(delta)
		return
	
	if not ( Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right") ):
		untilt_camera(delta)
		return
	
	var colliding: bool = false

	# Use raycast instead
	if leftDetectRay.is_colliding():
		colliding = true
		
		tilt = lerp(tilt, -max_tilt, (2 * delta)/0.2)

		if Input.is_action_just_pressed("jump"):
			grav_vec = Vector3(wall_jump_strength, jump, 0).rotated(Vector3.UP, h_rot)
			double_jump = 1
			return
	
	elif rightDetectRay.is_colliding():
		colliding = true
		
		tilt = lerp(tilt, max_tilt, (2 * delta)/0.2)

		if Input.is_action_just_pressed("jump"):
			grav_vec = Vector3(-wall_jump_strength, jump, 0).rotated(Vector3.UP, h_rot)
			double_jump = 1
			return
	
	if colliding == true:
		movement = Vector3.ZERO
		grav_vec.y = 0
		double_jump = 2

func sprint(delta):	
	# If shift is pressed, and player is moving, and is moving forward.
	if (not Input.is_action_pressed("sprint")) or (not is_moving()) or (not Input.get_action_strength("move_forward") > 0) or is_on_wall():
		speed = speed_type["walk"]
		return

	speed = speed_type["sprint"]


# INNATE FUNCTIONS
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	camera.fov = min_fov

func _input(event):
	# To make cursor visible when escape is pressed
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# To get mouse back into the game when clicked on window
	if event.is_action_pressed("shoot"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_tree().set_input_as_handled()
	
	# Move Camera around
	if event is InputEventMouseMotion and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		rotate_y(deg2rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg2rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg2rad(-90), deg2rad(90))

func _physics_process(delta):
	global_transform.basis.get_euler().y
	
	# MOVEMENT SECTION
	# Reset the Vector3 to (0, 0, 0)
	direction = Vector3.ZERO

	# This gets the radians rotated around the Y axis
	h_rot = global_transform.basis.get_euler().y
	var f_input = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	var h_input = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	# Gets Vector3 of direction passed, and rotates that vector3 according to the Earlier Radians.
	direction = Vector3(h_input, 0, f_input).rotated(Vector3.UP, h_rot).normalized()

	# JUMPING SECTION
	if is_on_floor():
		double_jump = 2
		accel = accel_type["default"]
		
		grav_vec = Vector3.DOWN

	elif not is_on_floor():
		accel = accel_type["air"]
		
		if grav_vec.x > 0 or grav_vec.x < 0:
			grav_vec.x = lerp(grav_vec.x, 0, 2*delta)
		
		grav_vec += Vector3.DOWN * gravity * delta

	# If space pressed and double jump is not disabled
	if Input.is_action_just_pressed("jump") and double_jump != 0:
		grav_vec = Vector3.UP * jump
		double_jump -= 1

	# SPRINT SECTION
	sprint(delta)

	# WALLRUN SECTION
	wall_run(delta)

	#make it move
	velocity = velocity.linear_interpolate(direction * speed, (accel * delta)/3)
	#velocity = direction * speed
	movement = velocity + grav_vec
	
	move_and_slide(movement, Vector3.UP)
