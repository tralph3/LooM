#version 330 core

layout (location = 0) in vec3 aPos;

out vec2 fragCoord;

void main() {
    vec3 aPosN = aPos * 2.0 - 1.0;
    fragCoord = (aPosN.xy + 1) / 2.0;
    gl_Position = vec4(aPosN, 1.0);
}
