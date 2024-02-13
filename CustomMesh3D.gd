extends MeshInstance3D

# Create a local rendering device.
var rd := RenderingServer.create_local_rendering_device()

# Prepare our data. We use floats in the shader, so we need 32 bit.
var input0 : PackedVector3Array; #positions, xyz
var input1 : PackedVector3Array; #normals, xyz
var input2 : PackedInt32Array; #indices, int
var input3 : PackedVector2Array; #uvs xy

# Create a storage buffer that can hold our values.
# Each blade holds 3 vertices.
var buffer0 : RID;
var buffer1 : RID;
var buffer2 : RID;
var buffer3 : RID;

var surface_array = []

var blades = 128 * 128 * 2;
var vertices_per_blade = 3;

func updateBuffer(buffer, input):
    pass

func createBuffer(input):
    var input_bytes := PackedByteArray(input.to_byte_array());
    return rd.storage_buffer_create(input_bytes.size(), input_bytes)

func createUniform(index, buffer):
    var uniform := RDUniform.new()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    uniform.binding = index # this needs to match the "binding" in our shader file
    uniform.add_id(buffer)
    return uniform;


# Called when the node enters the scene tree for the first time.
func _ready():
    # positions per blade and xyz value
    input0.resize(blades * vertices_per_blade);
    buffer0 = createBuffer(input0)
    # normals per blade xyz
    input1.resize(blades * vertices_per_blade);
    buffer1 = createBuffer(input1)
    # indices per blade int
    input2.resize(blades * vertices_per_blade);
    buffer2 = createBuffer(input2)
    # uvs per blade xy
    input3.resize(blades * vertices_per_blade);
    buffer3 = createBuffer(input3)




    # Load GLSL shader
    var shader_file := load("res://compute.glsl")
    var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
    var shader := rd.shader_create_from_spirv(shader_spirv)

    # Create a uniform to assign the buffer to the rendering device
    var uniform0 = createUniform(0, buffer0);
    var uniform1 = createUniform(1, buffer1);
    var uniform2 = createUniform(2, buffer2);
    var uniform3 = createUniform(3, buffer3);

    var uniform_set := rd.uniform_set_create([uniform0, uniform1, uniform2, uniform3], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file

    # Create a compute pipeline
    var pipeline := rd.compute_pipeline_create(shader)
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
    rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
    rd.compute_list_dispatch(compute_list, blades / 128, 1, 1)
    rd.compute_list_end()



    surface_array.resize(Mesh.ARRAY_MAX)

    # PackedVector**Arrays for mesh construction.
    var verts = PackedVector3Array()
    var uvs = PackedVector2Array()
    var normals = PackedVector3Array()
    var indices = PackedInt32Array()



    verts.append(Vector3(-1, 0, 0));
    verts.append(Vector3(0, 1, 0));
    verts.append(Vector3(1, 0, 0));

    normals.append(Vector3(0, 0, 1));
    normals.append(Vector3(0, 0, 1));
    normals.append(Vector3(0, 0, 1));

    indices.append(0);
    indices.append(1);
    indices.append(2);

    uvs.append(Vector2(0.0, 0.0));
    uvs.append(Vector2(0.5, 1.0));
    uvs.append(Vector2(1.0, 0.0));

    # Assign arrays to surface array.
    surface_array[Mesh.ARRAY_VERTEX] = verts
    surface_array[Mesh.ARRAY_TEX_UV] = uvs
    surface_array[Mesh.ARRAY_NORMAL] = normals
    surface_array[Mesh.ARRAY_INDEX] = indices

    # Create mesh surface from mesh array.
    # No blendshapes, lods, or compression used.
    #self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)

    # Saves mesh to a .tres file with compression enabled.
    # ResourceSaver.save(mesh, "res://sphere.tres", ResourceSaver.FLAG_COMPRESS)

func convertFloatArrayToPackedVector3(arr : PackedFloat32Array):
    var tmp = PackedVector3Array();
    for n in arr.size() / 3:
        tmp.append(Vector3(arr[n * 3], arr[n * 3 + 1], arr[n * 3 + 2]))
    return tmp;

func convertFloatArrayToPackedVector2(arr : PackedFloat32Array):
    var tmp = PackedVector2Array();
    for n in arr.size() / 2:
        tmp.append(Vector2(arr[n * 2], arr[n * 2 + 1]))
    return tmp;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    pass
#    #rd.buffer_update(buffer0, 0, input0.size(), input0.to_byte_array(),
#    #    RenderingDevice.BARRIER_MASK_ALL_BARRIERS);
#    # Submit to GPU and wait for sync
#    rd.submit()
#    rd.sync()
#
#    # Read back the data from the buffer
#    var tmp0 = rd.buffer_get_data(buffer0).to_float32_array();
#    var tmp1 = rd.buffer_get_data(buffer1).to_float32_array();
#    var tmp2 = rd.buffer_get_data(buffer2).to_int32_array();
#    var tmp3 = rd.buffer_get_data(buffer3).to_float32_array();
#
#    #var output_bytes0 := Array(rd.buffer_get_data(buffer0).to_float32_array())
#    #var output_bytes1 := Array(rd.buffer_get_data(buffer1))
#    #var output_bytes2 := Array(rd.buffer_get_data(buffer2))
#    #var output_bytes3 := Array(rd.buffer_get_data(buffer3))
#
#
#    var output_bytes0 := rd.buffer_get_data(buffer0).to_float32_array()
#    var output_bytes1 := rd.buffer_get_data(buffer1).to_float32_array()
#    var output_bytes2 := rd.buffer_get_data(buffer2).to_int32_array()
#    var output_bytes3 := rd.buffer_get_data(buffer3).to_float32_array()
#    #var output := output_bytes.to_float32_array()
#
#    #var verts = PackedVector3Array()
#    #var uvs = PackedVector2Array()
#    #var normals = PackedVector3Array()
#    #var indices = PackedInt32Array()
#
#
#    #surface_array[Mesh.ARRAY_VERTEX] = bytes_to_var(output_bytes0);
#    #surface_array[Mesh.ARRAY_NORMAL] = bytes_to_var(output_bytes1)
#    #surface_array[Mesh.ARRAY_INDEX] = bytes_to_var(output_bytes2)
#    #surface_array[Mesh.ARRAY_TEX_UV] = output_bytes3
#
#
#    surface_array[Mesh.ARRAY_VERTEX] = convertFloatArrayToPackedVector3(output_bytes0)
#    surface_array[Mesh.ARRAY_NORMAL] = convertFloatArrayToPackedVector3(output_bytes1)
#    surface_array[Mesh.ARRAY_INDEX] = output_bytes2
#    surface_array[Mesh.ARRAY_TEX_UV] = convertFloatArrayToPackedVector2(output_bytes3)
#
#
#    #var verts : PackedVector3Array = PackedVector3Array(output_bytes0)
#    #var uvs : PackedVector2Array = PackedVector2Array(output_bytes1)
#    #var normals : PackedVector3Array = PackedVector3Array(output_bytes2)
#    #var indices : PackedInt32Array = PackedInt32Array(output_bytes3)
#
#    #surface_array[Mesh.ARRAY_VERTEX] = verts
#    #surface_array[Mesh.ARRAY_NORMAL] = normals
#    #surface_array[Mesh.ARRAY_INDEX] = indices
#    #surface_array[Mesh.ARRAY_TEX_UV] = uvs
#
#    #surface_array[Mesh.ARRAY_VERTEX] = bytes_to_var(output_bytes0)
#    #surface_array[Mesh.ARRAY_NORMAL] = bytes_to_var(output_bytes1)
#    #surface_array[Mesh.ARRAY_INDEX] = bytes_to_var(output_bytes2)
#    #surface_array[Mesh.ARRAY_TEX_UV] = bytes_to_var(output_bytes3)
#
#    #input[0] = input[0] + 1;
#    #print("Input: ", input)
#    #print("Output: ", output)
#
#
#    # Create mesh surface from mesh array.
#    # No blendshapes, lods, or compression used.
#    self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
