extends CharacterBody2D

@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var animation_tree: AnimationTree
@export var collision_shape: CollisionShape2D
@export var debug_label: Label
@export var raycast_top_left: RayCast2D
@export var raycast_top_right: RayCast2D

@export var SPEED: float = 300.0
@export var ACCELERATION: float = 20.0
@export var JUMP_VELOCITY: float = -400.0
@export var DASH_COULDOWN: float = 3.0

const default_collision_shape: CapsuleShape2D = preload("res://src/entities/shapes/player_default_collision_shape.tres")
const crouch_collision_shape: CapsuleShape2D = preload("res://src/entities/shapes/player_crouch_collision_shape.tres")

var DIRECTION: float = 0
var LAST_FACING: int = 1

var input := Input
var timer: Timer

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var debug_text = "SPEED: {SPEED} \nVELOCITY(x,y): {X}-{Y} \nROOT SM: {ROOT_STATE} \nSUB STATE: {SUB_STATE} \n DASH_COULDOWN: {COULDOWN}/seconde"

func _ready():
	animation_tree.set_active(true)
	
	timer = Timer.new()
	add_child(timer)
	timer.set_one_shot(true)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle Jump.
	if input.is_action_just_pressed("jump") and is_on_floor() and !input.is_action_pressed("ui_down"):
		velocity.y = JUMP_VELOCITY

	DIRECTION = input.get_axis("move_left", "move_right")
	if DIRECTION:
		velocity.x = move_toward(velocity.x, DIRECTION * SPEED, ACCELERATION)
	else:
		velocity.x = move_toward(velocity.x, 0, 20)
		
	debug_label.text = debug_text.format({
		"SPEED": SPEED,
		"X": velocity.x,
		"Y": velocity.y,
		"COULDOWN": snapped(timer.time_left, 0.01)
	})

	move_and_slide()
	_on_rotate_sprite()
	_on_root_state()

func _on_rotate_sprite() -> void:
	if(DIRECTION < 0):
		LAST_FACING = -1
		sprite.set_flip_h(true)
	elif(DIRECTION > 0):
		LAST_FACING = 1
		sprite.set_flip_h(false)

func _on_crouch_state() -> void:
	var crouch_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/crouch_machine/playback")
	
	collision_shape.shape = crouch_collision_shape
	collision_shape.position.y = 31.0
	
	if not input.is_action_pressed("move_down") and not (raycast_top_left.is_colliding() or raycast_top_right.is_colliding()):
		crouch_machine.stop()
	
	
	if crouch_machine.is_playing():
		debug_label.text = debug_label.text.format({"SUB_STATE": crouch_machine.get_current_node()})
		match crouch_machine.get_current_node():
			"roll":
				_handle_dash(SPEED * 3, ACCELERATION+20)
			_:
				SPEED = 75.0

func _on_move_state() -> void:
	var move_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/move_machine/playback")
	
	if velocity.x == 0:
		move_machine.stop()

	if(move_machine.is_playing()):
		debug_label.text = debug_label.text.format({"SUB_STATE": move_machine.get_current_node()})
		match move_machine.get_current_node():
			"walk":
				SPEED = 125
			"dash":
				_handle_dash(SPEED * 1.5, ACCELERATION + 60.0)
				timer.start(DASH_COULDOWN)
			_:
				SPEED = 300.0

func _on_root_state() -> void:
	var root_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	debug_label.text = debug_label.text.format({
		"ROOT_STATE": root_machine.get_current_node(),
	})

	collision_shape.shape = default_collision_shape
	collision_shape.position.x = 0
	collision_shape.position.y = 23.0
	collision_shape.rotation_degrees = 0
	
	match  root_machine.get_current_node():
		"idle":
			SPEED = 300
		"slide":
			collision_shape.position.x = DIRECTION * 5
			collision_shape.position.y = 36.0
			collision_shape.rotation_degrees = DIRECTION * 90.0
			
			if(SPEED > 0):
				SPEED -= 5
			_handle_dash(SPEED)
		"move_machine":
			_on_move_state()
		"crouch_machine":
			_on_crouch_state()

func _handle_dash(speed: float, acceleration: float = ACCELERATION) -> void:
	velocity.x = move_toward(velocity.x, speed * LAST_FACING, acceleration)