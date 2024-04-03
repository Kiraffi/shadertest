extends MeshInstance3D

@export var frameRender = 0;

#path to TextureRect node for visualisations
@onready var texture_rect = $"../TextureRect"
@onready var camera = $"../Camera3D"
# Create a local rendering device.
#@onready var rd := RenderingServer.create_local_rendering_device()
@onready var rd := RenderingServer.get_rendering_device()

#@onready var rd_render := RenderingServer.get_ren()

# Prepare our data. We use floats in the shader, so we need 32 bit.
var input0 : PackedVector3Array; #positions, xyz
var input1 : PackedVector3Array; #normals, xyz
var input2 : PackedInt32Array; #indices, int
var input3 : PackedVector2Array; #uvs xy

var frameIndex = 0;

# Create a storage buffer that can hold our values.
# Each blade holds 3 vertices.
var buffer0 : RID;
var buffer1 : RID;
var buffer2 : RID;
var buffer3 : RID;

var surface_array = []


var compute_pipeline: RID;
var uniform_set: RID;
var render_uniform_set: RID;

var blades = 1024 * 1024 * 2;
var vertices_per_blade = 3;




var vertSrc = "#version 450

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer MyPositionBuffer {
    float data[];
}
positionBuffer;

// A binding to the buffer we create in our script
layout(set = 0, binding = 1, std430) restrict buffer MyNormalBuffer {
    float data[];
}
normalBuffer;

// A binding to the buffer we create in our script
layout(set = 0, binding = 2, std430) restrict buffer MyIndexBuffer {
    int data[];
}
indexBuffer;

// A binding to the buffer we create in our script
layout(set = 0, binding = 3, std430) restrict buffer MyUVBuffer {
    float data[];
}
uvBuffer;


void main() {
    float x = positionBuffer.data[gl_VertexIndex * 3 + 0] * 0.125;
    float y = positionBuffer.data[gl_VertexIndex * 3 + 1] * 0.125;
    float z = positionBuffer.data[gl_VertexIndex * 3 + 2] * 0.125;
    gl_Position = vec4(x, y, z, 1.0);
}"

var fragSrc = "#version 450
layout(location = 0) out vec4 outColor;
void main() {
    outColor = vec4(1.0, 0.0, 0.0, 1.0);
}"

var clearColors := PackedColorArray([Color.TRANSPARENT])
var render_framebuffer: RID
var render_pipeline: RID
var render_shader: RID
var render_img_texture: RID


var computeSrc = "#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer MyPositionBuffer {
    float data[];
}
positionBuffer;

// A binding to the buffer we create in our script
layout(set = 0, binding = 1, std430) restrict buffer MyNormalBuffer {
    float data[];
}
normalBuffer;

// A binding to the buffer we create in our script
layout(set = 0, binding = 2, std430) restrict buffer MyIndexBuffer {
    int data[];
}
indexBuffer;

// A binding to the buffer we create in our script
layout(set = 0, binding = 3, std430) restrict buffer MyUVBuffer {
    float data[];
}
uvBuffer;



// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    uint index = gl_GlobalInvocationID.x;

    vec3 posOffset = vec3(index % 16, 0, index / 16);

    positionBuffer.data[index * 9 + 0] = -1.0 + posOffset.x;
    positionBuffer.data[index * 9 + 1] =  0.0 + posOffset.y;
    positionBuffer.data[index * 9 + 2] =  0.0 + posOffset.z;

    positionBuffer.data[index * 9 + 3] =  0.0 + posOffset.x;
    positionBuffer.data[index * 9 + 4] =  1.0 + posOffset.y;
    positionBuffer.data[index * 9 + 5] =  0.0 + posOffset.z;

    positionBuffer.data[index * 9 + 6] =  1.0 + posOffset.x;
    positionBuffer.data[index * 9 + 7] =  0.0 + posOffset.y;
    positionBuffer.data[index * 9 + 8] =  0.0 + posOffset.z;

    int i = 0;
    for(i = 0; i < 3; ++i)
    {
       normalBuffer.data[index * 9 + i * 3 + 0] = 0.0;
       normalBuffer.data[index * 9 + i * 3 + 1] = 0.0;
       normalBuffer.data[index * 9 + i * 3 + 2] = 1.0;
    }

    for(i = 0; i < 3; ++i)
    {
        indexBuffer.data[index * 3 + i] = int(index) * 3 + i;
    }

    uvBuffer.data[index * 6 + 0] = 0.0;
    uvBuffer.data[index * 6 + 1] = 0.0;

    uvBuffer.data[index * 6 + 2] = 0.5;
    uvBuffer.data[index * 6 + 3] = 1.0;

    uvBuffer.data[index * 6 + 4] = 1.0;
    uvBuffer.data[index * 6 + 5] = 0.0;
}"




func updateBuffer(buffer, input):
    pass

func createBuffer(input_size):
    #var input_bytes := PackedByteArray(input.to_byte_array());
    return rd.storage_buffer_create(input_size); #, input_bytes)

func createUniform(index, buffer):
    var uniform := RDUniform.new()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    uniform.binding = index # this needs to match the "binding" in our shader file
    uniform.add_id(buffer)
    return uniform;




func gen_texture() -> RID:
    var tf = RDTextureFormat.new()
    tf.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
    tf.height = 1024
    tf.width = 1024
    tf.usage_bits =  RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
    tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
    var channels = 4
    var bytes_per_channel = 2



    var texture_rid = rd.texture_create(tf,RDTextureView.new())
    #texture_rect.texture.set_texture(texture_rid);
    return texture_rid


func create_framebuffer(imageTexture: RID):
    render_framebuffer = rd.framebuffer_create([imageTexture])


func create_render():
    var src := RDShaderSource.new()
    src.source_fragment = fragSrc
    src.source_vertex = vertSrc
    var spirv := rd.shader_compile_spirv_from_source(src)
    render_shader = rd.shader_create_from_spirv(spirv)
    render_img_texture = gen_texture()
    create_framebuffer(render_img_texture)

    var blend := RDPipelineColorBlendState.new()
    blend.attachments.push_back(RDPipelineColorBlendStateAttachment.new())
    render_pipeline = rd.render_pipeline_create(
        render_shader,
        rd.screen_get_framebuffer_format(),
        -1,
        RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
        RDPipelineRasterizationState.new(),
        RDPipelineMultisampleState.new(),
        RDPipelineDepthStencilState.new(),
        blend
    )


# Called when the node enters the scene tree for the first time.
func _ready():
    create_render();

    # positions per blade and xyz value
    #input0.resize(blades * vertices_per_blade);
    buffer0 = createBuffer(3 * 4 * blades * vertices_per_blade)
    # normals per blade xyz
    #input1.resize(blades * vertices_per_blade);
    buffer1 = createBuffer(3 * 4 * blades * vertices_per_blade)
    # indices per blade int
    #input2.resize(blades * vertices_per_blade);
    buffer2 = createBuffer(1 * 4 * blades * vertices_per_blade)
    # uvs per blade xy
    #input3.resize(blades * vertices_per_blade);
    buffer3 = createBuffer(2 * 4 * blades * vertices_per_blade)




    # Load GLSL shader
    #var shader_file := load("res://compute.glsl")
    #var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
    #var shader := rd.shader_create_from_spirv(shader_spirv)

    var src := RDShaderSource.new();
    src.source_compute = computeSrc;
    var spirv := rd.shader_compile_spirv_from_source(src)
    var shader := rd.shader_create_from_spirv(spirv)

    # Create a uniform to assign the buffer to the rendering device
    var uniform0 = createUniform(0, buffer0);
    var uniform1 = createUniform(1, buffer1);
    var uniform2 = createUniform(2, buffer2);
    var uniform3 = createUniform(3, buffer3);

    uniform_set = rd.uniform_set_create([uniform0, uniform1, uniform2, uniform3], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file
    render_uniform_set = rd.uniform_set_create([uniform0, uniform1, uniform2, uniform3], render_shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file

    # Create a compute pipeline
    compute_pipeline = rd.compute_pipeline_create(shader)

    #var renderpipeline := rd.render_pipeline_create()
    #var render_list := rd.draw_list_bind_render_pipeline()

    surface_array.resize(Mesh.ARRAY_MAX)

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



func update_texture():
    var data = rd.texture_get_data(render_img_texture, 0)
    var dynImage = Image.create_from_data(1024, 1024, false, Image.FORMAT_RGBAH, data)
    var imageTexture = ImageTexture.create_from_image(dynImage)
    texture_rect.texture = imageTexture

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    print("cam: ", camera.get_camera_transform())
    #pass
    #rd.buffer_update(buffer0, 0, input0.size(), input0.to_byte_array(),
    #    RenderingDevice.BARRIER_MASK_ALL_BARRIERS);
    # Submit to GPU and wait for sync
    print("delta:", delta);
    print("frameindex:", frameIndex);
    #if frameIndex == frameRender:
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, compute_pipeline)
    rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
    rd.compute_list_dispatch(compute_list, blades / 128, 1, 1)
    rd.compute_list_end()

    # handle resizing
    if not rd.framebuffer_is_valid(render_framebuffer):
        print("Issue")
    var draw_list := rd.draw_list_begin(render_framebuffer,
        RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_READ,
        RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_READ,
        clearColors)
    rd.draw_list_bind_render_pipeline(draw_list, render_pipeline)
    rd.draw_list_bind_uniform_set(draw_list, render_uniform_set, 0);
    rd.draw_list_draw(draw_list, false, 1, blades * vertices_per_blade)
    rd.draw_list_end()
    update_texture()


        #rd.submit()
#    elif(frameIndex == (frameRender + 1) % 4):
#
#        #rd.sync()
#        for i in Mesh.ARRAY_MAX:
#            if surface_array[i]:
#                surface_array[i].clear();
#
#
#
#
#        # Read back the data from the buffer
#        var tmp0 = rd.buffer_get_data(buffer0).to_float32_array();
#        var tmp1 = rd.buffer_get_data(buffer1).to_float32_array();
#        var tmp2 = rd.buffer_get_data(buffer2).to_int32_array();
#        var tmp3 = rd.buffer_get_data(buffer3).to_float32_array();
#
#        #var output_bytes0 := Array(rd.buffer_get_data(buffer0).to_float32_array())
#        #var output_bytes1 := Array(rd.buffer_get_data(buffer1))
#        #var output_bytes2 := Array(rd.buffer_get_data(buffer2))
#        #var output_bytes3 := Array(rd.buffer_get_data(buffer3))
#
#
#        var output_bytes0 := rd.buffer_get_data(buffer0).to_float32_array()
#        var output_bytes1 := rd.buffer_get_data(buffer1).to_float32_array()
#        var output_bytes2 := rd.buffer_get_data(buffer2).to_int32_array()
#        var output_bytes3 := rd.buffer_get_data(buffer3).to_float32_array()
#        #var output := output_bytes.to_float32_array()
#
#        #var verts = PackedVector3Array()
#        #var uvs = PackedVector2Array()
#        #var normals = PackedVector3Array()
#        #var indices = PackedInt32Array()
#
#
#        #surface_array[Mesh.ARRAY_VERTEX] = bytes_to_var(output_bytes0);
#        #surface_array[Mesh.ARRAY_NORMAL] = bytes_to_var(output_bytes1)
#        #surface_array[Mesh.ARRAY_INDEX] = bytes_to_var(output_bytes2)
#        #surface_array[Mesh.ARRAY_TEX_UV] = output_bytes3
#
#
#        surface_array[Mesh.ARRAY_VERTEX] = convertFloatArrayToPackedVector3(output_bytes0)
#        surface_array[Mesh.ARRAY_NORMAL] = convertFloatArrayToPackedVector3(output_bytes1)
#        surface_array[Mesh.ARRAY_INDEX] = output_bytes2
#        surface_array[Mesh.ARRAY_TEX_UV] = convertFloatArrayToPackedVector2(output_bytes3)
#
#
#        #var verts : PackedVector3Array = PackedVector3Array(output_bytes0)
#        #var uvs : PackedVector2Array = PackedVector2Array(output_bytes1)
#        #var normals : PackedVector3Array = PackedVector3Array(output_bytes2)
#        #var indices : PackedInt32Array = PackedInt32Array(output_bytes3)
#
#        #surface_array[Mesh.ARRAY_VERTEX] = verts
#        #surface_array[Mesh.ARRAY_NORMAL] = normals
#        #surface_array[Mesh.ARRAY_INDEX] = indices
#        #surface_array[Mesh.ARRAY_TEX_UV] = uvs
#
#        #surface_array[Mesh.ARRAY_VERTEX] = bytes_to_var(output_bytes0)
#        #surface_array[Mesh.ARRAY_NORMAL] = bytes_to_var(output_bytes1)
#        #surface_array[Mesh.ARRAY_INDEX] = bytes_to_var(output_bytes2)
#        #surface_array[Mesh.ARRAY_TEX_UV] = bytes_to_var(output_bytes3)
#
#        #input[0] = input[0] + 1;
#        #print("Input: ", input)
#        #print("Output: ", output)
#
#
#        # Create mesh surface from mesh array.
#        # No blendshapes, lods, or compression used.
#        self.mesh.clear_surfaces();
#        self.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array);

    frameIndex = (frameIndex + 1) % 4;
