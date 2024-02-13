#[compute]
#version 450



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


}



/*
layout(set = 0, binding = 0, std430) restrict buffer CameraData
{
    mat4 cameraToWorld;
    float cameraFov;
    float cameraFarPlane;
    float cameraNearPlane;
} camera_data;
/


layout(set = 0, binding = 0, std430) buffer MyBuffer
{
    vec4 data[];
} image_out;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

void main()
{
    image_out.data[gl_GlobalInvocationID.x] = vec4(1.0);
}
*/




