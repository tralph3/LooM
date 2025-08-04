package main

import cl "clay"
import sdl "vendor:sdl3"
import gl "vendor:OpenGL"
import "vendor:sdl3/ttf"
import "core:math"
import "core:log"
import "core:c"
import "core:strings"
import "gui"

@(private="file")
GUI_RENDERER_STATE := struct #no_copy {
    vbo: u32,
    vao: u32,
    rectangle_shader: u32,
    text_shader: u32,
    framebuffer_shader: u32,

    fonts: [gui.FontID]^ttf.Font,
} {}

@(private="file")
TEXT_TEXTURE_CACHE := CacheMemory(TextTextureCacheKey, u32){
    eviction_time_ms = 3000,
    item_free_proc = proc (key: TextTextureCacheKey, tex: u32) {
        texture_unload(tex)
    }
}

SoundEffectPaths :: [SoundID]cstring {
        .SelectPositive = "./assets/sounds/select_positive.wav",
        .SelectNegative = "./assets/sounds/select_negative.wav",
}

FontPaths :: [gui.FontID]struct { path: cstring, size: f32 } {
        .Default = { "./assets/fonts/Ubuntu.ttf", 32 },
        .Title = { "./assets/fonts/Gaegu.ttf", 32 },
}

vertex_rectangle_shader_src: cstring = #load("./shaders/rectangle.vert")
fragment_rectangle_shader_src: cstring = #load("./shaders/rectangle.frag")

vertex_text_shader_src: cstring = #load("./shaders/text.vert")
fragment_text_shader_src: cstring = #load("./shaders/text.frag")

vertex_framebuffer_shader_src: cstring = #load("./shaders/framebuffer.vert")
fragment_framebuffer_shader_src: cstring = #load("./shaders/framebuffer.frag")

crt_mattias_framebuffer_shader_src: cstring = #load("./shaders/crt-mattias.frag")

@(private="file")
RECTANGLE_SHADER_LOCS: struct {
    rect: i32,
    screenSize: i32,
    color: i32,

    radiusTL: i32,
    radiusTR: i32,
    radiusBR: i32,
    radiusBL: i32,

    border: i32,
    borderL: i32,
    borderR: i32,
    borderT: i32,
    borderB: i32,
}

@(private="file")
TEXT_SHADER_LOCS: struct {
    tex: i32,
}

@(private="file")
FRAMEBUFFER_SHADER_LOCS: struct {
    tex: i32,
    texSize: i32,
    uvSubregion: i32,
    flipY: i32,
    frameCount: i32,
    outputSize: i32,
    inputSize: i32,
}

@(private="file")
TextTextureCacheKey :: struct {
    fontId: u16,
    fontSize: u16,
    strId: cl.ElementId,
    color: cl.Color,
}

CustomRenderType :: enum {
    EmulatorFramebuffer = 1,
}

CustomRenderData :: struct {
    type: CustomRenderType,
    data: rawptr,
}

gui_renderer_set_framebuffer_shader :: proc (shader_src: cstring) {
    prog_id, ok := gl_load_shader(vertex_framebuffer_shader_src, shader_src, &FRAMEBUFFER_SHADER_LOCS)
    if !ok {
        log.error("Framebuffer shader loading failed. Aborting.")
        return
    }

    gl.DeleteProgram(GUI_RENDERER_STATE.framebuffer_shader)
    GUI_RENDERER_STATE.framebuffer_shader = prog_id
}

gui_renderer_init :: proc () -> (ok: bool) {
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    gl.GenBuffers(1, &GUI_RENDERER_STATE.vbo)
    gl.GenVertexArrays(1, &GUI_RENDERER_STATE.vao)

    {
        using GUI_RENDERER_STATE
        rectangle_shader = gl_load_shader(
            vertex_rectangle_shader_src, fragment_rectangle_shader_src, &RECTANGLE_SHADER_LOCS) or_return
        text_shader = gl_load_shader(
            vertex_text_shader_src, fragment_text_shader_src, &TEXT_SHADER_LOCS) or_return
        framebuffer_shader = gl_load_shader(
            vertex_framebuffer_shader_src, fragment_framebuffer_shader_src, &FRAMEBUFFER_SHADER_LOCS) or_return
    }

    gui_renderer_load_fonts() or_return

    return true
}

gui_renderer_load_fonts :: proc () -> (ok: bool) {
    for font_info, id in FontPaths {
        font := ttf.OpenFont(font_info.path, font_info.size)
        if font == nil {
            log.infof("Failed opening font '{}': {}", sdl.GetError())
            return false
        }

        GUI_RENDERER_STATE.fonts[id] = font
    }

    return true
}

gui_renderer_unload_fonts :: proc () {
    for font_info, id in FontPaths {
        ttf.CloseFont(GUI_RENDERER_STATE.fonts[id])
    }
}

gui_renderer_deinit :: proc () {
    gl.DeleteBuffers(1, &GUI_RENDERER_STATE.vbo)
    gl.DeleteVertexArrays(1, &GUI_RENDERER_STATE.vao)
    gui_renderer_unload_fonts()

    cache_delete(&TEXT_TEXTURE_CACHE)
}

gui_renderer_measure_text :: proc "c" (text: cl.StringSlice, config: ^cl.TextElementConfig, user_data: rawptr) -> cl.Dimensions {
    context = GLOBAL_STATE.ctx
    assert(text.length > 0)

    font := GUI_RENDERER_STATE.fonts[gui.FontID(config.fontId)]

    if !ttf.SetFontSize(font, f32(config.fontSize)) {
        log.errorf("CLAY: Measure text error: Failed setting font size: {}", sdl.GetError())
        return { 0, 0 }
    }

    width: i32
    height: i32
    if (!ttf.GetStringSize(font, cstring(text.chars), uint(text.length), &width, &height)) {
        log.errorf("CLAY: Measure text error: Failed measuring text: {}", sdl.GetError())
        return { 0, 0 }
    }

    return { f32(width), f32(height) }
}

gui_renderer_render_commands :: proc (rcommands: ^cl.ClayArray(cl.RenderCommand)) {
    window_size := video_get_window_dimensions()
    window_wf := f32(window_size.x)
    window_hf := f32(window_size.y)

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    gl.Viewport(0, 0, window_size.x, window_size.y)
    gl.ClearColor(0, 0, 0, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    for i in 0..<rcommands.length {
        rcmd := cl.RenderCommandArray_Get(rcommands, i)
        bounding_box: cl.BoundingBox = rcmd.boundingBox
        rect: sdl.FRect = { math.round(bounding_box.x), math.round(bounding_box.y), math.round(bounding_box.width), math.round(bounding_box.height) }

        // flip y coord because OpenGL is ass
        rect.y = window_hf - rect.y - rect.h

        switch rcmd.commandType {
        case .Rectangle, .Border: {
            vertices: [12]c.float = {
                rect.x / window_wf, (rect.y + rect.h) / window_hf, 0,
                rect.x / window_wf, rect.y / window_hf, 0,
                (rect.x + rect.w) / window_wf, rect.y / window_hf, 0,
                (rect.x + rect.w) / window_wf, (rect.y + rect.h) / window_hf, 0,
            }

            gl.BindVertexArray(GUI_RENDERER_STATE.vao)
            gl.BindBuffer(gl.ARRAY_BUFFER, GUI_RENDERER_STATE.vbo)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices[:]), gl.DYNAMIC_DRAW)
            gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(c.float), uintptr(0))
            gl.EnableVertexAttribArray(0)
            gl.UseProgram(GUI_RENDERER_STATE.rectangle_shader)

            gl.Uniform4f(RECTANGLE_SHADER_LOCS.rect, rect.x, rect.y, rect.w, rect.h)
            gl.Uniform2f(RECTANGLE_SHADER_LOCS.screenSize, window_wf, window_hf)

            if rcmd.commandType == .Rectangle {
                config: ^cl.RectangleRenderData = &rcmd.renderData.rectangle

                gl.Uniform1i(RECTANGLE_SHADER_LOCS.border, 0)

                gl.Uniform1f(RECTANGLE_SHADER_LOCS.radiusTL, config.cornerRadius.topLeft)
                gl.Uniform1f(RECTANGLE_SHADER_LOCS.radiusTR, config.cornerRadius.topRight)
                gl.Uniform1f(RECTANGLE_SHADER_LOCS.radiusBR, config.cornerRadius.bottomRight)
                gl.Uniform1f(RECTANGLE_SHADER_LOCS.radiusBL, config.cornerRadius.bottomLeft)

                gl.Uniform4f(RECTANGLE_SHADER_LOCS.color,
                             f32(config.backgroundColor[0])/255.0,
                             f32(config.backgroundColor[1])/255.0,
                             f32(config.backgroundColor[2])/255.0,
                             f32(config.backgroundColor[3])/255.0,
                            )
            } else if rcmd.commandType == .Border {
                config: ^cl.BorderRenderData = &rcmd.renderData.border

                gl.Uniform1i(RECTANGLE_SHADER_LOCS.border, 1)

                gl.Uniform1f(RECTANGLE_SHADER_LOCS.radiusTL, config.cornerRadius.topLeft)
                gl.Uniform1f(RECTANGLE_SHADER_LOCS.radiusTR, config.cornerRadius.topRight)
                gl.Uniform1f(RECTANGLE_SHADER_LOCS.radiusBR, config.cornerRadius.bottomRight)
                gl.Uniform1f(RECTANGLE_SHADER_LOCS.radiusBL, config.cornerRadius.bottomLeft)

                gl.Uniform1f(RECTANGLE_SHADER_LOCS.borderL, f32(config.width.left))
                gl.Uniform1f(RECTANGLE_SHADER_LOCS.borderR, f32(config.width.right))
                gl.Uniform1f(RECTANGLE_SHADER_LOCS.borderT, f32(config.width.top))
                gl.Uniform1f(RECTANGLE_SHADER_LOCS.borderB, f32(config.width.bottom))

                gl.Uniform4f(RECTANGLE_SHADER_LOCS.color,
                             f32(config.color[0])/255.0,
                             f32(config.color[1])/255.0,
                             f32(config.color[2])/255.0,
                             f32(config.color[3])/255.0,
                            )
            }

            gl.DrawArrays(gl.TRIANGLE_FAN, 0, 4)
        }
        case .Text: {
            config: ^cl.TextRenderData = &rcmd.renderData.text
            str := strings.string_from_ptr(config.stringContents.chars, int(config.stringContents.length))

            key := TextTextureCacheKey{ config.fontId, config.fontSize, cl.ID(str), config.textColor }
            font_texture := cache_get(&TEXT_TEXTURE_CACHE, key)

            if font_texture == nil {
                font: ^ttf.Font = GUI_RENDERER_STATE.fonts[gui.FontID(config.fontId)]
                if !ttf.SetFontSize(font, f32(config.fontSize)) {
                    log.errorf("Failed setting font size: {}", sdl.GetError())
                    continue
                }

                color := sdl.Color { u8(config.textColor.r), u8(config.textColor.g), u8(config.textColor.b), u8(config.textColor.a) }
                surface := ttf.RenderText_Blended(font, cstring(config.stringContents.chars), uint(config.stringContents.length), color)
                if surface == nil {
                    log.errorf("Failed rendering text: {}", sdl.GetError())
                    continue
                }
                defer sdl.DestroySurface(surface)

                bytes_per_pixel: i32 = i32(sdl.BITSPERPIXEL(surface.format) / 8.0)

                cached_texture: u32
                gl.GenTextures(1, &cached_texture)
                gl.BindTexture(gl.TEXTURE_2D, cached_texture)
                gl.PixelStorei(gl.UNPACK_ROW_LENGTH, surface.pitch / bytes_per_pixel)
                gl.TexImage2D(
                    gl.TEXTURE_2D, 0, gl.RGBA8,
                    surface.w, surface.h,
                    0, gl.BGRA, gl.UNSIGNED_INT_8_8_8_8_REV, surface.pixels)
                gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
                gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

                gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)

                cache_set(&TEXT_TEXTURE_CACHE, key, cached_texture)
                font_texture = cache_get(&TEXT_TEXTURE_CACHE, key)
            }

            vertices: [12]c.float = {
                rect.x / window_wf, (rect.y + rect.h) / window_hf, 0,
                rect.x / window_wf, rect.y / window_hf, 0,
                (rect.x + rect.w) / window_wf, rect.y / window_hf, 0,
                (rect.x + rect.w) / window_wf, (rect.y + rect.h) / window_hf, 0,
            }

            gl.BindVertexArray(GUI_RENDERER_STATE.vao)
            gl.BindBuffer(gl.ARRAY_BUFFER, GUI_RENDERER_STATE.vbo)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices[:]), gl.DYNAMIC_DRAW)
            gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(c.float), uintptr(0))
            gl.EnableVertexAttribArray(0)
            gl.ActiveTexture(gl.TEXTURE0)
            gl.BindTexture(gl.TEXTURE_2D, font_texture^)

            gl.UseProgram(GUI_RENDERER_STATE.text_shader)
            gl.Uniform1i(TEXT_SHADER_LOCS.tex, 0)

            gl.DrawArrays(gl.TRIANGLE_FAN, 0, 4)
        }
        case .ScissorStart: {
            gl.Enable(gl.SCISSOR_TEST)
            gl.Scissor(i32(rect.x), i32(rect.y), i32(rect.w), i32(rect.h))
        }
        case .ScissorEnd: {
            gl.Disable(gl.SCISSOR_TEST)
        }
        case .Image: {
            texture_id := u32(uintptr(rcmd.renderData.image.imageData))

            vertices: [12]c.float = {
                rect.x / window_wf, (rect.y + rect.h) / window_hf, 0,
                rect.x / window_wf, rect.y / window_hf, 0,
                (rect.x + rect.w) / window_wf, rect.y / window_hf, 0,
                (rect.x + rect.w) / window_wf, (rect.y + rect.h) / window_hf, 0,
            }

            gl.BindVertexArray(GUI_RENDERER_STATE.vao)
            gl.BindBuffer(gl.ARRAY_BUFFER, GUI_RENDERER_STATE.vbo)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices[:]), gl.DYNAMIC_DRAW)
            gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(c.float), uintptr(0))
            gl.EnableVertexAttribArray(0)
            gl.ActiveTexture(gl.TEXTURE0)
            gl.BindTexture(gl.TEXTURE_2D, texture_id)

            gl.UseProgram(GUI_RENDERER_STATE.text_shader)
            gl.Uniform1i(TEXT_SHADER_LOCS.tex, 0)

            gl.DrawArrays(gl.TRIANGLE_FAN, 0, 4)
        }
        case .Custom: {
            type := CustomRenderType(uintptr(rcmd.renderData.custom.customData))
            switch type {
            case .EmulatorFramebuffer: {
                vertices: [12]c.float = {
                    rect.x / window_wf, (rect.y + rect.h) / window_hf, 0,
                    rect.x / window_wf, rect.y / window_hf, 0,
                    (rect.x + rect.w) / window_wf, rect.y / window_hf, 0,
                    (rect.x + rect.w) / window_wf, (rect.y + rect.h) / window_hf, 0,
                }

                gl.BindVertexArray(GUI_RENDERER_STATE.vao)
                gl.BindBuffer(gl.ARRAY_BUFFER, GUI_RENDERER_STATE.vbo)
                gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices[:]), gl.DYNAMIC_DRAW)
                gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(c.float), uintptr(0))
                gl.EnableVertexAttribArray(0)
                gl.ActiveTexture(gl.TEXTURE0)
                gl.BindTexture(gl.TEXTURE_2D, video_get_fbo_texture_id())

                gl.UseProgram(GUI_RENDERER_STATE.framebuffer_shader)
                gl.Uniform1i(FRAMEBUFFER_SHADER_LOCS.tex, 0)

                if emulator_framebuffer_is_bottom_left_origin() {
                    gl.Uniform1i(FRAMEBUFFER_SHADER_LOCS.flipY, 0)
                } else {
                    gl.Uniform1i(FRAMEBUFFER_SHADER_LOCS.flipY, 1)
                }

                texture_size := emulator_get_texture_size()
                image_size := emulator_get_image_size()

                normalized_image_size: [2]f32 = {
                    f32(image_size.x) / f32(texture_size.x),
                    f32(image_size.y) / f32(texture_size.y),
                }

                if emulator_is_hw_rendered() {
                    gl.Uniform4f(FRAMEBUFFER_SHADER_LOCS.uvSubregion, 0, 0, normalized_image_size.x, normalized_image_size.y)
                } else {
                    gl.Uniform4f(FRAMEBUFFER_SHADER_LOCS.uvSubregion, 0, 0, 1, 1)
                }

                if FRAMEBUFFER_SHADER_LOCS.frameCount != -1 {
                    gl.Uniform1i(FRAMEBUFFER_SHADER_LOCS.frameCount, i32(GLOBAL_STATE.frame_counter))
                }
                if FRAMEBUFFER_SHADER_LOCS.outputSize != -1 {
                    gl.Uniform2f(FRAMEBUFFER_SHADER_LOCS.outputSize, rect.w, rect.h)
                }
                if FRAMEBUFFER_SHADER_LOCS.texSize != -1 {
                    gl.Uniform2f(FRAMEBUFFER_SHADER_LOCS.texSize, f32(image_size.x), f32(image_size.y))
                }
                if FRAMEBUFFER_SHADER_LOCS.inputSize != -1 {
                    gl.Uniform2f(FRAMEBUFFER_SHADER_LOCS.inputSize, f32(image_size.x), f32(image_size.y))
                }

                gl.DrawArrays(gl.TRIANGLE_FAN, 0, 4)
            }}
        }
        case .None: {
            log.warn("CLAY: Attempted to render None render command")
        }}
    }

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    gl.UseProgram(0)
    gl.BindTexture(gl.TEXTURE_2D, 0)
    gl.DisableVertexAttribArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    cache_evict(&TEXT_TEXTURE_CACHE)
}
