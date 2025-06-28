package main

import "core:os/os2"
import "base:runtime"
import cl "clay"
import sdl "vendor:sdl3"
import lr "libretro"
import "vendor:sdl3/ttf"
import "core:log"
import "core:c"
import gl "vendor:OpenGL"

FBO :: struct {
    framebuffer: u32,
    texture: u32,
    depth: u32,
    stencil: u32,
}

VideoState :: struct #no_copy {
    window: ^sdl.Window,
    pixel_format: lr.RetroPixelFormat,
    fonts: [dynamic]^ttf.Font,

    fbo: FBO,

    main_context: sdl.GLContext,
    emu_context: sdl.GLContext,

    actual_width: u32,
    actual_height: u32,

    shared_context: bool,
}

video_init :: proc () -> (ok: bool) {
    when ODIN_OS == .Linux {
        wayland_display := os2.get_env("WAYLAND_DISPLAY", allocator=context.allocator)
        defer delete(wayland_display)

        has_wayland := wayland_display != ""
        if has_wayland {
            // prioritize Wayland. if both DISPLAY and WAYLAND_DISPLAY
            // are set, SDL uses x11 by default
            sdl.SetHint(sdl.HINT_VIDEO_DRIVER, "wayland,x11")
        }
    }

    sdl.SetHint(sdl.HINT_VIDEO_ALLOW_SCREENSAVER, "0")

    if !sdl.Init({ .VIDEO, .AUDIO, .EVENTS, .GAMEPAD, .JOYSTICK }) {
        log.errorf("Failed initializing SDL: {}", sdl.GetError())
        return false
    }

    if !ttf.Init() {
        log.errorf("Failed initializing text: {}", sdl.GetError())
        return false
    }

    video_load_font("./assets/Ubuntu.ttf", 38)

    GLOBAL_STATE.video_state.window = sdl.CreateWindow("Libretro Frontend", 800, 600, { .RESIZABLE, .OPENGL })
    if GLOBAL_STATE.video_state.window == nil {
        log.errorf("Failed creating window: {}", sdl.GetError())
        return false
    }

    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_COMPATIBILITY))
    sdl.GL_SetAttribute(sdl.GL_SHARE_WITH_CURRENT_CONTEXT, 0)

    GLOBAL_STATE.video_state.main_context = sdl.GL_CreateContext(GLOBAL_STATE.video_state.window)
    if GLOBAL_STATE.video_state.main_context == nil {
        log.errorf("Failed creating OpenGL context: {}", sdl.GetError())
        return false
    }

    gl.load_up_to(3, 3, sdl.gl_set_proc_address)

    if !sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, GLOBAL_STATE.video_state.main_context) {
        log.errorf("Failed making OpenGL context current: {}", sdl.GetError())
        return false
    }

    return true
}

video_deinit :: proc () {
    for font in GLOBAL_STATE.video_state.fonts {
        ttf.CloseFont(font)
    }
    delete(GLOBAL_STATE.video_state.fonts)

    video_destroy_emulator_framebuffer()
    sdl.DestroyWindow(GLOBAL_STATE.video_state.window)

    ttf.Quit()
    sdl.Quit()
}

video_load_font :: proc (path: cstring, size: f32) {
    font := ttf.OpenFont(path, size)
    if font == nil {
        log.errorf("Failed loading font '{}': {}", path, sdl.GetError())
        return
    }

    append(&GLOBAL_STATE.video_state.fonts, font)
}

video_destroy_emulator_framebuffer :: proc () {
    fbo := GLOBAL_STATE.video_state.fbo
    if fbo.framebuffer  != 0 { gl.DeleteFramebuffers(1,  &fbo.framebuffer) }
    if fbo.depth        != 0 { gl.DeleteRenderbuffers(1, &fbo.depth)       }
    if fbo.stencil      != 0 { gl.DeleteRenderbuffers(1, &fbo.stencil)     }
    if fbo.texture      != 0 { gl.DeleteTextures(1,      &fbo.texture)     }
}

video_init_emulator_framebuffer :: proc (depth := false, stencil := false) {
    width := i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_width)
    height := i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_height)

    video_destroy_emulator_framebuffer()

    aspect := GLOBAL_STATE.emulator_state.av_info.geometry.aspect_ratio
    if aspect == 0.0 {
        aspect = 4.0 / 3.0
    }
    if width == 0 && height == 0 {
        width = 640
        height = i32(f32(width) / aspect)
    } else if width == 0 {
        width = i32(f32(height) * aspect)
    } else if height == 0 {
        height = i32(f32(width) / aspect)
    }

    fbo: FBO

    gl.GenFramebuffers(1, &fbo.framebuffer)
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo.framebuffer)
    defer gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    gl.GenTextures(1, &fbo.texture)
    gl.BindTexture(gl.TEXTURE_2D, fbo.texture)
    defer gl.BindTexture(gl.TEXTURE_2D, 0)

    gl.TexImage2D(
        gl.TEXTURE_2D, 0, gl.RGB8,
        width, height,
        0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fbo.texture, 0)

    if depth {
        gl.GenRenderbuffers(1, &fbo.depth)
        gl.BindRenderbuffer(gl.RENDERBUFFER, fbo.depth)
        defer gl.BindRenderbuffer(gl.RENDERBUFFER, 0)

        gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT24, width, height)
        gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, fbo.depth)
    }

    if stencil {
        gl.GenRenderbuffers(1, &fbo.stencil)
        gl.BindRenderbuffer(gl.RENDERBUFFER, fbo.stencil)
        defer gl.BindRenderbuffer(gl.RENDERBUFFER, 0)

        gl.RenderbufferStorage(gl.RENDERBUFFER, gl.STENCIL_INDEX8, width, height)
        gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.STENCIL_ATTACHMENT, gl.RENDERBUFFER, fbo.stencil)
    }

    framebuffer_status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
    if framebuffer_status != gl.FRAMEBUFFER_COMPLETE {
        log.errorf("Incomplete framebuffer: {}", framebuffer_status)
    }

    GLOBAL_STATE.video_state.fbo = fbo
}

video_init_opengl_context :: proc (render_cb: ^lr.RetroHwRenderCallback) {
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_COMPATIBILITY))
    sdl.GL_SetAttribute(sdl.GL_SHARE_WITH_CURRENT_CONTEXT, 1)

    GLOBAL_STATE.video_state.emu_context = sdl.GL_CreateContext(GLOBAL_STATE.video_state.window)
    if GLOBAL_STATE.video_state.emu_context == nil {
        log.errorf("Failed creating OpenGL context: {}", sdl.GetError())
        return
    }

    render_cb.get_proc_address = sdl.GL_GetProcAddress
    render_cb.get_current_framebuffer = proc "c" () -> c.uintptr_t {
        return c.uintptr_t(GLOBAL_STATE.video_state.fbo.framebuffer)
    }

    GLOBAL_STATE.emulator_state.hardware_render_callback = render_cb
}
