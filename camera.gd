extends Camera3D

var player;


# Called when the node enters the scene tree for the first time.
func _ready():
    player = $"../Player"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    global_position.x = player.position.x;
    global_position.z = player.position.z + 3;
