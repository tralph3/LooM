#version 330 core

in vec2 uvCoord;
out vec4 fragColor;

uniform sampler2D tex;

uniform int frameCount;
uniform vec2 outputSize;
uniform vec2 texSize;
uniform vec2 inputSize;

float CURVATURE = 0.25f;
float SCANSPEED = 1.5f;

#define iTime (float(frameCount) / 60.0)
#define iResolution outputSize
#define iChannel0 tex
#define fragCoord gl_FragCoord.xy

vec3 sample_(sampler2D tex, vec2 tc)
{
    return pow(texture(tex, tc).rgb, vec3(2.2));
}

vec3 blur(sampler2D tex, vec2 tc, float offs)
{
    vec4 xoffs = offs * vec4(-2.0, -1.0, 1.0, 2.0) / (iResolution.x * texSize.x / inputSize.x);
    vec4 yoffs = offs * vec4(-2.0, -1.0, 1.0, 2.0) / (iResolution.y * texSize.y / inputSize.y);
    tc = tc * inputSize / texSize;

    vec3 color = vec3(0.0);
    float weights[5] = float[](0.00366, 0.01465, 0.02564, 0.01465, 0.00366);
    float weightsMid[5] = float[](0.01465, 0.05861, 0.09524, 0.05861, 0.01465);

    for (int i = 0; i < 5; ++i) {
        for (int j = 0; j < 5; ++j) {
            float w = (i == 2) ? weightsMid[j] : weights[j];
            color += sample_(tex, tc + vec2(xoffs[j], yoffs[i])) * w;
        }
    }

    return color;
}

float rand(vec2 co)
{
    float a = 12.9898;
    float b = 78.233;
    float c = 43758.5453;
    float dt = dot(co.xy ,vec2(a,b));
    float sn = mod(dt, 3.14);
    return fract(sin(sn) * c);
}

vec2 curve(vec2 uv)
{
    uv = (uv - 0.5) * 2.0;
    uv *= 1.1;
    uv.x *= 1.0 + pow(abs(uv.y) / 5.0, 2.0);
    uv.y *= 1.0 + pow(abs(uv.x) / 4.0, 2.0);
    uv = (uv / 2.0) + 0.5;
    uv = uv * 0.92 + 0.04;
    return uv;
}

void main()
{
    vec2 q = uvCoord * texSize / inputSize;
    vec2 uv = mix(q, curve(q), CURVATURE) * inputSize / texSize;
    vec3 col;

    float o = 2.0 * mod(fragCoord.y, 2.0) / iResolution.x;
    uv = uv * texSize / inputSize;

    col.r = blur(iChannel0, uv + vec2(0.0009, 0.0009), 1.2).x + 0.005;
    col.g = blur(iChannel0, uv + vec2(0.0, -0.0015), 1.2).y + 0.005;
    col.b = blur(iChannel0, uv + vec2(-0.0015, 0.0), 1.2).z + 0.005;

    col.r += 0.2 * blur(iChannel0, uv + vec2(0.0009, 0.0009), 2.25).x - 0.005;
    col.g += 0.2 * blur(iChannel0, uv + vec2(0.0, -0.0015), 1.75).y - 0.005;
    col.b += 0.2 * blur(iChannel0, uv + vec2(-0.0015, 0.0), 1.25).z - 0.005;

    float ghs = 0.05;
    col.r += ghs * (1.0 - 0.299) * blur(iChannel0, 0.75 * vec2(0.01, -0.027) + uv + vec2(0.001, 0.001), 7.0).x;
    col.g += ghs * (1.0 - 0.587) * blur(iChannel0, 0.75 * vec2(-0.022, -0.02) + uv + vec2(0.0, -0.002), 5.0).y;
    col.b += ghs * (1.0 - 0.114) * blur(iChannel0, 0.75 * vec2(-0.02, 0.0) + uv + vec2(-0.002, 0.0), 3.0).z;

    col = clamp(col * 0.4 + 0.6 * col * col, 0.0, 1.0);

    float vig = pow(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y), 0.3);
    col *= vec3(vig);

    col *= vec3(0.95, 1.05, 0.95);
    col = mix(col, col * col, 0.3) * 3.8;

    float scans = clamp(0.35 + 0.15 * sin(3.5 * (iTime * SCANSPEED) + uv.y * iResolution.y * 1.5), 0.0, 1.0);
    col *= vec3(pow(scans, 0.9));

    col *= 1.0 + 0.0015 * sin(300.0 * iTime);
    col *= 1.0 - 0.15 * vec3(clamp((mod(fragCoord.x + o, 2.0) - 1.0) * 2.0, 0.0, 1.0));
    col *= vec3(1.0) - 0.25 * vec3(
        rand(uv + 0.0001 * iTime),
        rand(uv + 0.0001 * iTime + 0.3),
        rand(uv + 0.0001 * iTime + 0.5)
    );

    col = pow(col, vec3(0.45));

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        col *= 0.0;

    fragColor = vec4(col, 1.0);
}
