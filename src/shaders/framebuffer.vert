#version 330 core

layout (location = 0) in vec3 aPos;

uniform vec4 uvSubregion;
uniform bool flipY;

out vec2 uvCoord;

void main() {
    vec2 baseUV;
    switch (gl_VertexID) {
        case 0: baseUV = vec2(0.0, 1.0); break; // bottom-left
        case 1: baseUV = vec2(0.0, 0.0); break; // top-left
        case 2: baseUV = vec2(1.0, 0.0); break; // top-right
        case 3: baseUV = vec2(1.0, 1.0); break; // bottom-right
    }

    if (flipY) {
        baseUV.y = 1.0 - baseUV.y;
    }

    uvCoord = uvSubregion.xy + baseUV * uvSubregion.zw;

    vec3 aPosN = aPos * 2.0 - 1.0;
    gl_Position = vec4(aPosN, 1.0);
}
