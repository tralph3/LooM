package main

import cl "clay"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"
import "core:math"
import "core:log"
import "core:c"
import gl "vendor:OpenGL"

/* Global for convenience. Even in 4K this is enough for smooth curves (low radius or rect size coupled with
 * no AA or low resolution might make it appear as jagged curves) */
NUM_CIRCLE_SEGMENTS: int : 16

SDL_MeasureText :: proc "c" (text: cl.StringSlice, config: ^cl.TextElementConfig, user_data: rawptr) -> cl.Dimensions {
    context = GLOBAL_STATE.ctx

    fonts := GLOBAL_STATE.video_state.fonts
    font := fonts[config.fontId]

    width: i32
    height: i32

    if (!ttf.GetStringSize(font, cstring(text.chars), uint(text.length), &width, &height)) {
        log.errorf("Failed to measure text: {}", sdl.GetError())
    }

    return { f32(width), f32(height) }
}

// all rendering is performed by a single SDL call, avoiding multiple RenderRect + plumbing choice for circles.
SDL_Clay_RenderFillRoundedRect :: proc (rect: sdl.FRect, cornerRadius: f32, _color: cl.Color) {
    color: sdl.FColor = { _color.r/255, _color.g/255, _color.b/255, _color.a/255 };

    indexCount: int = 0
    vertexCount: int = 0

    minRadius: f32 = min(rect.w, rect.h) / 2.0
    clampedRadius: f32 = min(cornerRadius, minRadius)

    numCircleSegments: int = max(NUM_CIRCLE_SEGMENTS, int(clampedRadius * 0.5));

    totalVertices: int = 4 + (4 * (numCircleSegments * 2)) + 2 * 4
    totalIndices: int = 6 + (4 * (numCircleSegments * 3)) + 6 * 4

    vertices := make([]sdl.Vertex, totalVertices)
    defer delete(vertices)

    indices := make([]int, totalIndices)
    defer delete(indices)

    // define center rectangle
    vertices[vertexCount] = sdl.Vertex{ {rect.x + clampedRadius, rect.y + clampedRadius}, color, {0, 0} }; vertexCount += 1 //0 center TL
    vertices[vertexCount] = sdl.Vertex{ {rect.x + rect.w - clampedRadius, rect.y + clampedRadius}, color, {1, 0} }; vertexCount += 1 //1 center TR
    vertices[vertexCount] = sdl.Vertex{ {rect.x + rect.w - clampedRadius, rect.y + rect.h - clampedRadius}, color, {1, 1} }; vertexCount += 1 //2 center BR
    vertices[vertexCount] = sdl.Vertex{ {rect.x + clampedRadius, rect.y + rect.h - clampedRadius}, color, {0, 1} }; vertexCount += 1 //3 center BL

    indices[indexCount] = 0; indexCount += 1
    indices[indexCount] = 1; indexCount += 1
    indices[indexCount] = 3; indexCount += 1
    indices[indexCount] = 1; indexCount += 1
    indices[indexCount] = 2; indexCount += 1
    indices[indexCount] = 3; indexCount += 1

    //define rounded corners as triangle fans
    step: f32 = (math.PI / 2) / f32(numCircleSegments)
    for i in 0..<numCircleSegments {
        angle1: f32 = f32(i) * step
        angle2: f32 = (f32(i) + 1.0) * step

        for j in 0..<4 {  // Iterate over four corners
            cx: f32
            cy: f32
            signX: f32
            signY: f32

            switch j {
            case 0:
                cx = rect.x + clampedRadius; cy = rect.y + clampedRadius; signX = -1; signY = -1 // Top-left
            case 1:
                cx = rect.x + rect.w - clampedRadius; cy = rect.y + clampedRadius; signX = 1; signY = -1 // Top-right
            case 2:
                cx = rect.x + rect.w - clampedRadius; cy = rect.y + rect.h - clampedRadius; signX = 1; signY = 1 // Bottom-right
            case 3:
                cx = rect.x + clampedRadius; cy = rect.y + rect.h - clampedRadius; signX = -1; signY = 1 // Bottom-left
            case:
                return
            }

            vertices[vertexCount] = sdl.Vertex{ {cx + math.cos(angle1) * clampedRadius * signX, cy + math.sin(angle1) * clampedRadius * signY}, color, {0, 0} }; vertexCount += 1
            vertices[vertexCount] = sdl.Vertex{ {cx + math.cos(angle2) * clampedRadius * signX, cy + math.sin(angle2) * clampedRadius * signY}, color, {0, 0} }; vertexCount += 1

            indices[indexCount] = j; indexCount += 1 // Connect to corresponding central rectangle vertex
            indices[indexCount] = vertexCount - 2; indexCount += 1
            indices[indexCount] = vertexCount - 1; indexCount += 1
        }
    }

    // Define edge rectangles
    // Top edge
    vertices[vertexCount] = sdl.Vertex{ {rect.x + clampedRadius, rect.y}, color, {0, 0} }; vertexCount += 1 // TL
    vertices[vertexCount] = sdl.Vertex{ {rect.x + rect.w - clampedRadius, rect.y}, color, {1, 0} }; vertexCount += 1 // TR

    indices[indexCount] = 0; indexCount += 1
    indices[indexCount] = vertexCount - 2; indexCount += 1 // TL
    indices[indexCount] = vertexCount - 1; indexCount += 1 // TR
    indices[indexCount] = 1; indexCount += 1
    indices[indexCount] = 0; indexCount += 1
    indices[indexCount] = vertexCount - 1; indexCount += 1 // TR
    // Right edge
    vertices[vertexCount] = sdl.Vertex{ {rect.x + rect.w, rect.y + clampedRadius}, color, {1, 0} }; vertexCount += 1 // RT
    vertices[vertexCount] = sdl.Vertex{ {rect.x + rect.w, rect.y + rect.h - clampedRadius}, color, {1, 1} }; vertexCount += 1 // RB

    indices[indexCount] = 1; indexCount += 1
    indices[indexCount] = vertexCount - 2; indexCount += 1 // RT
    indices[indexCount] = vertexCount - 1; indexCount += 1 // RB
    indices[indexCount] = 2; indexCount += 1
    indices[indexCount] = 1; indexCount += 1
    indices[indexCount] = vertexCount - 1; indexCount += 1 // RB

    // Bottom edge
    vertices[vertexCount] = sdl.Vertex{ {rect.x + rect.w - clampedRadius, rect.y + rect.h}, color, {1, 1} }; vertexCount += 1 // BR
    vertices[vertexCount] = sdl.Vertex{ {rect.x + clampedRadius, rect.y + rect.h}, color, {0, 1} }; vertexCount += 1 // BL

    indices[indexCount] = 2; indexCount += 1
    indices[indexCount] = vertexCount - 2; indexCount += 1 // BR
    indices[indexCount] = vertexCount - 1; indexCount += 1 // BL
    indices[indexCount] = 3; indexCount += 1
    indices[indexCount] = 2; indexCount += 1
    indices[indexCount] = vertexCount - 1; indexCount += 1 // BL

    // Left edge
    vertices[vertexCount] = sdl.Vertex{ {rect.x, rect.y + rect.h - clampedRadius}, color, {0, 1} }; vertexCount += 1 // LB
    vertices[vertexCount] = sdl.Vertex{ {rect.x, rect.y + clampedRadius}, color, {0, 0} }; vertexCount += 1 // LT

    indices[indexCount] = 3; indexCount += 1
    indices[indexCount] = vertexCount - 2; indexCount += 1 // LB
    indices[indexCount] = vertexCount - 1; indexCount += 1 // LT
    indices[indexCount] = 0; indexCount += 1
    indices[indexCount] = 3; indexCount += 1
    indices[indexCount] = vertexCount - 1; indexCount += 1 // LT

    indices_c_int := make([]c.int, indexCount)
    for index, i in indices {
        indices_c_int[i] = c.int(index)
    }
    defer delete(indices_c_int)

    // Render everything
    sdl.RenderGeometry(GLOBAL_STATE.video_state.renderer, nil, raw_data(vertices), i32(vertexCount), raw_data(indices_c_int), i32(indexCount))
}

SDL_Clay_RenderArc :: proc (center: sdl.FPoint, radius, startAngle, endAngle, thickness: f32, color: cl.Color) {
    sdl.SetRenderDrawColor(GLOBAL_STATE.video_state.renderer, u8(color.r), u8(color.g), u8(color.b), u8(color.a))

    radStart: f32 = startAngle * (math.PI / 180.0)
    radEnd: f32 = endAngle * (math.PI / 180.0)

    numCircleSegments: int = max(NUM_CIRCLE_SEGMENTS, int(radius * 1.5)) // increase circle segments for larger circles, 1.5 is arbitrary.

    angleStep: f32 = (radEnd - radStart) / f32(numCircleSegments)
    thicknessStep: f32 = 0.5 // arbitrary value to avoid overlapping lines. Changing THICKNESS_STEP or numCircleSegments might cause artifacts.

    for t := thicknessStep; t < thickness - thicknessStep; t += thicknessStep {
        points := make([]sdl.FPoint, numCircleSegments + 1)
        defer delete(points)

        clampedRadius: f32 = max(radius - t, 1.0)

        for i in 0..=numCircleSegments {
            angle: f32 = radStart + f32(i) * angleStep
            points[i] = {
                math.round(center.x + math.cos(angle) * clampedRadius),
                math.round(center.y + math.sin(angle) * clampedRadius),
            }
        }
        sdl.RenderLines(GLOBAL_STATE.video_state.renderer, raw_data(points), i32(numCircleSegments + 1))
    }
}

currentClippingRectangle: sdl.Rect

SDL_Clay_RenderClayCommands :: proc (rcommands: ^cl.ClayArray(cl.RenderCommand)) {
    for i in 0..<rcommands.length {
        rcmd := cl.RenderCommandArray_Get(rcommands, i)
        bounding_box: cl.BoundingBox = rcmd.boundingBox
        rect: sdl.FRect = { math.round(bounding_box.x), math.round(bounding_box.y), math.round(bounding_box.width), math.round(bounding_box.height) }

        switch rcmd.commandType {
        case .Rectangle: {
            config: ^cl.RectangleRenderData = &rcmd.renderData.rectangle
            sdl.SetRenderDrawBlendMode(GLOBAL_STATE.video_state.renderer, sdl.BLENDMODE_BLEND)
            sdl.SetRenderDrawColor(GLOBAL_STATE.video_state.renderer, u8(config.backgroundColor.r), u8(config.backgroundColor.g), u8(config.backgroundColor.b), u8(config.backgroundColor.a))
            if (config.cornerRadius.topLeft > 0) {
                SDL_Clay_RenderFillRoundedRect(rect, config.cornerRadius.topLeft, config.backgroundColor)
            } else {
                sdl.RenderFillRect(GLOBAL_STATE.video_state.renderer, &rect)
            }
        }
        case .Text: {
            config: ^cl.TextRenderData = &rcmd.renderData.text
            font: ^ttf.Font = GLOBAL_STATE.video_state.fonts[config.fontId]
            text: ^ttf.Text = ttf.CreateText(GLOBAL_STATE.video_state.text_engine, font, cstring(config.stringContents.chars), uint(config.stringContents.length))
            _ = ttf.SetTextColor(text, u8(config.textColor.r), u8(config.textColor.g), u8(config.textColor.b), u8(config.textColor.a))
            _ = ttf.DrawRendererText(text, rect.x, rect.y)
            ttf.DestroyText(text)
        }
        case .Border: {
            config: ^cl.BorderRenderData = &rcmd.renderData.border

            minRadius: f32 = min(rect.w, rect.h) / 2.0
            clampedRadii := cl.CornerRadius{
                topLeft = min(config.cornerRadius.topLeft, minRadius),
                topRight = min(config.cornerRadius.topRight, minRadius),
                bottomLeft = min(config.cornerRadius.bottomLeft, minRadius),
                bottomRight = min(config.cornerRadius.bottomRight, minRadius),
            }

            //edges
            sdl.SetRenderDrawColor(GLOBAL_STATE.video_state.renderer, u8(config.color.r), u8(config.color.g), u8(config.color.b), u8(config.color.a))
            if (config.width.left > 0) {
                starting_y: f32 = rect.y + clampedRadii.topLeft
                length: f32 = rect.h - clampedRadii.topLeft - clampedRadii.bottomLeft
                line: sdl.FRect = { rect.x, starting_y, f32(config.width.left), length }
                sdl.RenderFillRect(GLOBAL_STATE.video_state.renderer, &line)
            }
            if (config.width.right > 0) {
                starting_x: f32 = rect.x + rect.w - f32(config.width.right)
                starting_y: f32 = rect.y + clampedRadii.topRight
                length: f32 = rect.h - clampedRadii.topRight - clampedRadii.bottomRight
                line: sdl.FRect = { starting_x, starting_y, f32(config.width.right), length }
                sdl.RenderFillRect(GLOBAL_STATE.video_state.renderer, &line)
            }
            if (config.width.top > 0) {
                starting_x: f32= rect.x + clampedRadii.topLeft
                length: f32= rect.w - clampedRadii.topLeft - clampedRadii.topRight
                line: sdl.FRect = { starting_x, rect.y, length, f32(config.width.top) }
                sdl.RenderFillRect(GLOBAL_STATE.video_state.renderer, &line)
            }
            if (config.width.bottom > 0) {
                starting_x: f32 = rect.x + clampedRadii.bottomLeft
                starting_y: f32 = rect.y + rect.h - f32(config.width.bottom)
                length: f32 = rect.w - clampedRadii.bottomLeft - clampedRadii.bottomRight
                line: sdl.FRect = { starting_x, starting_y, length, f32(config.width.bottom) }
                sdl.SetRenderDrawColor(GLOBAL_STATE.video_state.renderer, u8(config.color.r), u8(config.color.g), u8(config.color.b), u8(config.color.a))
                sdl.RenderFillRect(GLOBAL_STATE.video_state.renderer, &line)
            }
            //corners
            if (config.cornerRadius.topLeft > 0) {
                centerX: f32 = rect.x + clampedRadii.topLeft
                centerY: f32 = rect.y + clampedRadii.topLeft
                SDL_Clay_RenderArc({centerX, centerY}, clampedRadii.topLeft,
                                   180.0, 270.0, f32(config.width.top), config.color)
            }
            if (config.cornerRadius.topRight > 0) {
                centerX: f32 = rect.x + rect.w - clampedRadii.topRight
                centerY: f32 = rect.y + clampedRadii.topRight
                SDL_Clay_RenderArc(sdl.FPoint{centerX, centerY}, clampedRadii.topRight,
                                   270.0, 360.0, f32(config.width.top), config.color)
            }
            if (config.cornerRadius.bottomLeft > 0) {
                centerX: f32 = rect.x + clampedRadii.bottomLeft
                centerY: f32 = rect.y + rect.h - clampedRadii.bottomLeft
                SDL_Clay_RenderArc({centerX, centerY}, clampedRadii.bottomLeft,
                                   90.0, 180.0, f32(config.width.bottom), config.color)
            }
            if (config.cornerRadius.bottomRight > 0) {
                centerX: f32 = rect.x + rect.w - clampedRadii.bottomRight
                centerY: f32 = rect.y + rect.h - clampedRadii.bottomRight
                SDL_Clay_RenderArc({centerX, centerY}, clampedRadii.bottomRight,
                                   0.0, 90.0, f32(config.width.bottom), config.color)
            }
        }
        case .ScissorStart: {
            boundingBox: cl.BoundingBox = rcmd.boundingBox
            currentClippingRectangle = sdl.Rect{
                x = i32(boundingBox.x),
                y = i32(boundingBox.y),
                w = i32(boundingBox.width),
                h = i32(boundingBox.height),
            }
            sdl.SetRenderClipRect(GLOBAL_STATE.video_state.renderer, &currentClippingRectangle)
        }
        case .ScissorEnd: {
            sdl.SetRenderClipRect(GLOBAL_STATE.video_state.renderer, nil)
        }
        case .Image: {
            bind_framebuffer := (proc "c" (i32, u32))(sdl.GL_GetProcAddress("glBindFramebuffer"))
            read_pixels := (proc "c" (x, y, width, height: i32, format, type: u32, pixels: rawptr))(sdl.GL_GetProcAddress("glReadPixels"))
            blit_framebuffer := (proc "c" (srcX0: i32, srcY0: i32, srcX1: i32, srcY1: i32, dstX0: i32, dstY0: i32, dstX1: i32, dstY1: i32, mask: u32, filter: u32))(sdl.GL_GetProcAddress("glBlitFramebuffer"))
            get_error := (proc "c" () -> u32)(sdl.GL_GetProcAddress("glGetError"))
            read_buffer := (proc "c" (u32))(sdl.GL_GetProcAddress("glReadBuffer"))
            get_tex_image := (proc "c" (target: u32,  level: i32, format, type: u32, pixels: rawptr))(sdl.GL_GetProcAddress("glGetTexImage"))
            check_framebuffer_status := (proc "c" (u32) -> u32)(sdl.GL_GetProcAddress("glCheckFramebufferStatus"))

            dest: sdl.FRect = { rect.x, rect.y, rect.w, rect.h }

            bind_framebuffer(gl.READ_FRAMEBUFFER, fbo_id)
            bind_framebuffer(gl.DRAW_FRAMEBUFFER, 0)
            blit_framebuffer(
                0, i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_height), i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_width), 0,
                i32(rect.x), i32(rect.y), i32(rect.w), i32(rect.h),
                gl.COLOR_BUFFER_BIT, gl.NEAREST
            )
            // texture := (^sdl.Texture)(rcmd.renderData.image.imageData)

            // sdl.RenderTexture(GLOBAL_STATE.video_state.renderer, texture, nil, &dest)
        }
        case .Custom: {
            log.warn("CLAY: Custom render command is not used")
        }
        case .None: {
            log.warn("CLAY: Attemted to render None render command")
        }
        }
    }
}
