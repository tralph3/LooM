#version 330 core

out vec4 fragColor;
in vec2 fragCoord;

uniform vec4 rect;
uniform vec2 screenSize;
uniform vec4 color;

uniform float radiusTL;
uniform float radiusTR;
uniform float radiusBR;
uniform float radiusBL;

// indicates whether we should draw a full rectangle
// or only the borders
uniform bool border;
uniform float borderL;
uniform float borderR;
uniform float borderT;
uniform float borderB;

float roundedCornerSDF(vec2 p, vec2 cornerCenter, float radius) {
    return length(p - cornerCenter) - radius;
}

void main() {
    vec2 pixelCoord = fragCoord * screenSize;
    vec2 local = pixelCoord - rect.xy;
    vec2 size = rect.zw;

    float dist = -1.0;

    // Rounded corners SDFs
    if (local.x < radiusTL && local.y < radiusTL) {
        dist = roundedCornerSDF(local, vec2(radiusTL, radiusTL), radiusTL);
    } else if (local.x > size.x - radiusTR && local.y < radiusTR) {
        dist = roundedCornerSDF(local, vec2(size.x - radiusTR, radiusTR), radiusTR);
    } else if (local.x > size.x - radiusBR && local.y > size.y - radiusBR) {
        dist = roundedCornerSDF(local, vec2(size.x - radiusBR, size.y - radiusBR), radiusBR);
    } else if (local.x < radiusBL && local.y > size.y - radiusBL) {
        dist = roundedCornerSDF(local, vec2(radiusBL, size.y - radiusBL), radiusBL);
    }

    // If border mode is enabled, discard pixels not in the border
    if (border) {
        // Define the inner rectangle (excluding borders)
        float innerLeft   = borderL;
        float innerRight  = size.x - borderR;
        float innerTop    = size.y - borderT;
        float innerBottom = borderB;

        // If the pixel lies entirely inside the inner region (not part of border), discard it
        if (local.x >= innerLeft && local.x < innerRight &&
            local.y >= innerBottom && local.y < innerTop) {
            fragColor = vec4(0.0);
            return;
        }
    }

    if (dist > 0.0) {
        float aa = 1.3;
        float alpha = color.a * (1.0 - smoothstep(0.0, aa, dist));
        if (alpha <= 0.0) alpha = 0.0;
        fragColor = vec4(color.rgb, alpha);
    } else {
        fragColor = color;
    }
}
