extends Node3D
@export_subgroup("Settings")
@export var MovementSpeed: float = 5.0;

var currentAngle: float = 0.0;

# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    var xDiff = 0;
    var yDiff = 0;
    if Input.is_action_pressed("move_down"):
        yDiff += delta * MovementSpeed
    if Input.is_action_pressed("move_up"):
        yDiff -= delta * MovementSpeed
    if Input.is_action_pressed("move_left"):
        xDiff -= delta * MovementSpeed
    if Input.is_action_pressed("move_right"):
        xDiff += delta * MovementSpeed

    global_position.x += xDiff;
    global_position.z += yDiff;

    if(xDiff != 0 || yDiff != 0):
        currentAngle = atan2(xDiff, yDiff)
    transform.basis = Basis(Quaternion(Vector3(0, 1, 0), currentAngle));
    #transform.basis = Quaternion(Vector3(0, 1, 0), -PI / 2.0);

