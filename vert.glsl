#[vertex]
#version 450

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer MyPositionBuffer {
    float data[];
}
positionBuffer;


void main() {
    float x = positionBuffer.data[gl_VertexIndex * 2 + 0];
    float y = positionBuffer.data[gl_VertexIndex * 2 + 1];
    gl_Position = vec4(vec2(x, y) * 0.125, 0.0, 1.0);
}