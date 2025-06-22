package main

import cl "clay"
import sdl "vendor:sdl3"
import gl "vendor:OpenGL"
import "vendor:sdl3/ttf"
import "core:math"
import "core:log"
import "core:c"

/* Global for convenience. Even in 4K this is enough for smooth curves (low radius or rect size coupled with
 * no AA or low resolution might make it appear as jagged curves) */
NUM_CIRCLE_SEGMENTS: int : 16

vbo: u32
vao: u32
rectangle_shader: u32
text_shader: u32

vertex_rectangle_shader_src: cstring = #load("./shaders/rectangle.vert")
fragment_rectangle_shader_src: cstring = #load("./shaders/rectangle.frag")

vertex_text_shader_src: cstring = #load("./shaders/text.vert")
fragment_text_shader_src: cstring = #load("./shaders/text.frag")

load_shader :: proc (vert, frag: cstring) -> u32 {
    vert := vert
    frag := frag

    vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
    gl.ShaderSource(vertex_shader, 1, &vert, nil)
    gl.CompileShader(vertex_shader)

    success: i32
    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success);
    if !bool(success) {
        log.errorf("Vertex compilation failed")
        return 0
    }

    fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
    gl.ShaderSource(fragment_shader, 1, &frag, nil)
    gl.CompileShader(fragment_shader)

    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success);
    if !bool(success) {
        log.errorf("Fragment compilation failed")
        return 0
    }

    shader_program := gl.CreateProgram()
    gl.AttachShader(shader_program, vertex_shader)
    gl.AttachShader(shader_program, fragment_shader)
    gl.LinkProgram(shader_program)

    gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success);
    if !bool(success) {
        log.errorf("Program linking failed")
        return 0
    }

    gl.DeleteShader(vertex_shader)
    gl.DeleteShader(fragment_shader)

    return shader_program
}

gui_renderer_init :: proc () {
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    gl.GenBuffers(1, &vbo)
    gl.GenVertexArrays(1, &vao)

    rectangle_shader = load_shader(vertex_rectangle_shader_src, fragment_rectangle_shader_src)
    text_shader = load_shader(vertex_text_shader_src, fragment_text_shader_src)
}

gui_renderer_measure_text :: proc "c" (text: cl.StringSlice, config: ^cl.TextElementConfig, user_data: rawptr) -> cl.Dimensions {
    if text.length == 0 {
        return { 0, 0 }
    }

    context = GLOBAL_STATE.ctx

    fonts := GLOBAL_STATE.video_state.fonts
    font := fonts[config.fontId]

    _ = ttf.SetFontSize(font, f32(config.fontSize))

    width: i32
    height: i32
    if (!ttf.GetStringSize(font, cstring(text.chars), uint(text.length), &width, &height)) {
        log.errorf("Failed to measure text: {}", sdl.GetError())
    }

    return { f32(width), f32(height) }
}

gui_renderer_render_commands :: proc (rcommands: ^cl.ClayArray(cl.RenderCommand)) {
    window_x: i32
    window_y: i32
    sdl.GetWindowSize(GLOBAL_STATE.video_state.window, &window_x, &window_y)

    window_w := f32(window_x)
    window_h := f32(window_y)

    gl.Viewport(0, 0, window_x, window_y)
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    for i in 0..<rcommands.length {
        rcmd := cl.RenderCommandArray_Get(rcommands, i)
        bounding_box: cl.BoundingBox = rcmd.boundingBox
        rect: sdl.FRect = { math.round(bounding_box.x), math.round(bounding_box.y), math.round(bounding_box.width), math.round(bounding_box.height) }

        // flip y coord because OpenGL is ass
        rect.y = window_h - rect.y - rect.h

        switch rcmd.commandType {
        case .Rectangle, .Border: {
            vertices: [12]c.float = {
                rect.x / window_w, (rect.y + rect.h) / window_h, 0,
                rect.x / window_w, rect.y / window_h, 0,
                (rect.x + rect.w) / window_w, rect.y / window_h, 0,
                (rect.x + rect.w) / window_w, (rect.y + rect.h) / window_h, 0,
            }
            vertices = vertices * 2 - 1

            gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
            gl.BindVertexArray(vao)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices[:]), gl.DYNAMIC_DRAW)
            gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(c.float), uintptr(0))
            gl.EnableVertexAttribArray(0)
            gl.UseProgram(rectangle_shader)

            gl.Uniform4f(gl.GetUniformLocation(rectangle_shader, "rect"), rect.x, rect.y, rect.w, rect.h)
            gl.Uniform2f(gl.GetUniformLocation(rectangle_shader, "screenSize"), window_w, window_h)

            if rcmd.commandType == .Rectangle {
                config: ^cl.RectangleRenderData = &rcmd.renderData.rectangle

                gl.Uniform1i(gl.GetUniformLocation(rectangle_shader, "border"), 0)

                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "radiusTL"), config.cornerRadius.topLeft)
                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "radiusTR"), config.cornerRadius.topRight)
                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "radiusBR"), config.cornerRadius.bottomRight)
                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "radiusBL"), config.cornerRadius.bottomLeft)

                gl.Uniform4f(gl.GetUniformLocation(rectangle_shader, "color"),
                             f32(config.backgroundColor[0])/255.0,
                             f32(config.backgroundColor[1])/255.0,
                             f32(config.backgroundColor[2])/255.0,
                             f32(config.backgroundColor[3])/255.0,
                            )
            } else if rcmd.commandType == .Border {
                config: ^cl.BorderRenderData = &rcmd.renderData.border

                gl.Uniform1i(gl.GetUniformLocation(rectangle_shader, "border"), 1)

                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "radiusTL"), config.cornerRadius.topLeft)
                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "radiusTR"), config.cornerRadius.topRight)
                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "radiusBR"), config.cornerRadius.bottomRight)
                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "radiusBL"), config.cornerRadius.bottomLeft)

                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "borderL"), f32(config.width.left))
                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "borderR"), f32(config.width.right))
                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "borderT"), f32(config.width.top))
                gl.Uniform1f(gl.GetUniformLocation(rectangle_shader, "borderB"), f32(config.width.bottom))

                gl.Uniform4f(gl.GetUniformLocation(rectangle_shader, "color"),
                             f32(config.color[0])/255.0,
                             f32(config.color[1])/255.0,
                             f32(config.color[2])/255.0,
                             f32(config.color[3])/255.0,
                            )
            }

            gl.DrawArrays(gl.TRIANGLE_FAN, 0, 4)

            gl.BindBuffer(gl.ARRAY_BUFFER, 0)
            gl.BindVertexArray(0)
        }
        case .Text: {
            config: ^cl.TextRenderData = &rcmd.renderData.text
            font: ^ttf.Font = GLOBAL_STATE.video_state.fonts[config.fontId]
            _ = ttf.SetFontSize(font, f32(config.fontSize))
            color := sdl.Color { u8(config.textColor.r), u8(config.textColor.g), u8(config.textColor.b), u8(config.textColor.a) }
            surface := ttf.RenderText_Blended(font, cstring(config.stringContents.chars), uint(config.stringContents.length), color)

            converted_surface := sdl.ConvertSurface(surface, sdl.PixelFormat.ARGB8888)
            sdl.DestroySurface(surface)
            surface = converted_surface

            if surface == nil {
                log.errorf("Failed rendering text: {}", sdl.GetError())
                continue
            }

            vertices: [12]c.float = {
                rect.x / window_w, (rect.y + rect.h) / window_h, 0,
                rect.x / window_w, rect.y / window_h, 0,
                (rect.x + rect.w) / window_w, rect.y / window_h, 0,
                (rect.x + rect.w) / window_w, (rect.y + rect.h) / window_h, 0,
            }
            vertices = vertices * 2 - 1

            font_texture: u32
            gl.GenTextures(1, &font_texture)
            gl.BindTexture(gl.TEXTURE_2D, font_texture)
            gl.TexImage2D(
                gl.TEXTURE_2D, 0, gl.RGBA8,
                surface.w, surface.h,
                0, gl.BGRA, gl.UNSIGNED_INT_8_8_8_8_REV, surface.pixels)
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

            gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
            gl.BindVertexArray(vao)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices[:]), gl.DYNAMIC_DRAW)
            gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(c.float), uintptr(0))
            gl.EnableVertexAttribArray(0)
            gl.ActiveTexture(gl.TEXTURE0)
            gl.BindTexture(gl.TEXTURE_2D, font_texture)

            gl.UseProgram(text_shader)
            gl.Uniform1i(gl.GetUniformLocation(text_shader, "tex"), 0)

            gl.DrawArrays(gl.TRIANGLE_FAN, 0, 4)

            gl.DeleteTextures(1, &font_texture)
            sdl.DestroySurface(surface)

            gl.BindBuffer(gl.ARRAY_BUFFER, 0)
            gl.BindVertexArray(0)
        }
        case .ScissorStart: {
            gl.Enable(gl.SCISSOR_TEST)
            gl.Scissor(i32(rect.x), i32(rect.y), i32(rect.w), i32(rect.h))
        }
        case .ScissorEnd: {
            gl.Disable(gl.SCISSOR_TEST)
        }
        case .Image: {
            gl.BindFramebuffer(gl.READ_FRAMEBUFFER, fbo_id)
            gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)
            gl.BlitFramebuffer(
                0, i32(GLOBAL_STATE.video_state.actual_height), i32(GLOBAL_STATE.video_state.actual_width), 0,
                i32(rect.x), i32(rect.y), i32(rect.w + rect.x), i32(rect.h + rect.y),
                gl.COLOR_BUFFER_BIT, gl.NEAREST
            )
            gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
        }
        case .Custom: {
            log.warn("CLAY: Custom render command is not used")
        }
        case .None: {
            log.warn("CLAY: Attemted to render None render command")
        }
        }
    }

    gl.UseProgram(0)
    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    gl.BindRenderbuffer(gl.RENDERBUFFER, 0)
    gl.BindTexture(gl.TEXTURE_2D, 0)
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, 0)
    gl.ActiveTexture(gl.TEXTURE0)
    gl.Disable(gl.SCISSOR_TEST)
    gl.Disable(gl.DEPTH_TEST)
    gl.Disable(gl.STENCIL_TEST)
    gl.Disable(gl.CULL_FACE)
    gl.Viewport(0, 0, window_x, window_y) // If needed
}
