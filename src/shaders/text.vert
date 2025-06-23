#version 330 core

layout (location = 0) in vec3 aPos;

out vec2 uvCoord;

void main() {
    uvCoord = vec2(
        (gl_VertexID == 0 || gl_VertexID == 1) ? 0.0 : 1.0,
        (gl_VertexID == 1 || gl_VertexID == 2) ? 1.0 : 0.0
        );

    vec3 aPosN = aPos * 2.0 - 1.0;
    gl_Position = vec4(aPosN, 1.0);
}
