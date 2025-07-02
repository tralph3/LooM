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
    depth_stencil: u32,
}

@(private="file")
VIDEO_STATE := struct #no_copy {
    window: ^sdl.Window,
    window_size: [2]i32,

    fbo: FBO,

    pixel_format: lr.RetroPixelFormat,

    main_context: sdl.GLContext,
    emu_context: sdl.GLContext,
} {}

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

    VIDEO_STATE.window = sdl.CreateWindow("Libretro Frontend", 800, 600, { .RESIZABLE, .OPENGL })
    if VIDEO_STATE.window == nil {
        log.errorf("Failed creating window: {}", sdl.GetError())
        return false
    }

    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_COMPATIBILITY))
    sdl.GL_SetAttribute(sdl.GL_SHARE_WITH_CURRENT_CONTEXT, 0)

    VIDEO_STATE.main_context = sdl.GL_CreateContext(VIDEO_STATE.window)
    if VIDEO_STATE.main_context == nil {
        log.errorf("Failed creating OpenGL context: {}", sdl.GetError())
        return false
    }

    gl.load_up_to(3, 3, sdl.gl_set_proc_address)

    major, minor: i32
    gl.GetIntegerv(gl.MAJOR_VERSION, &major)
    gl.GetIntegerv(gl.MINOR_VERSION, &minor)
    gl.load_up_to(int(major), int(minor), sdl.gl_set_proc_address)

    sdl.GL_SetSwapInterval(0)

    if !sdl.GL_MakeCurrent(VIDEO_STATE.window, VIDEO_STATE.main_context) {
        log.errorf("Failed making OpenGL context current: {}", sdl.GetError())
        return false
    }

    return true
}

video_deinit :: proc () {
    video_destroy_emu_framebuffer()

    sdl.GL_DestroyContext(VIDEO_STATE.emu_context)
    sdl.GL_DestroyContext(VIDEO_STATE.main_context)

    sdl.DestroyWindow(VIDEO_STATE.window)

    ttf.Quit()
    sdl.Quit()
}

video_destroy_emu_framebuffer :: proc () {
    fbo := VIDEO_STATE.fbo
    if fbo.framebuffer   != 0 { gl.DeleteFramebuffers(1,  &fbo.framebuffer)   }
    if fbo.depth_stencil != 0 { gl.DeleteRenderbuffers(1, &fbo.depth_stencil) }
    if fbo.texture       != 0 { gl.DeleteTextures(1,      &fbo.texture)       }
}

video_init_emu_framebuffer :: proc (depth := false, stencil := false) {
    width := emulator_get_texture_size().x
    height := emulator_get_texture_size().y

    video_destroy_emu_framebuffer()

    aspect: f32 = 4.0 / 3.0
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

    if depth || stencil {
        gl.GenRenderbuffers(1, &fbo.depth_stencil)
        gl.BindRenderbuffer(gl.RENDERBUFFER, fbo.depth_stencil)
        defer gl.BindRenderbuffer(gl.RENDERBUFFER, 0)

        gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, width, height)
        gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, fbo.depth_stencil)
    }

    framebuffer_status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
    if framebuffer_status != gl.FRAMEBUFFER_COMPLETE {
        log.errorf("Incomplete framebuffer: {}", framebuffer_status)
    }

    VIDEO_STATE.fbo = fbo
}

video_init_emu_opengl_context :: proc (render_cb: ^lr.RetroHwRenderCallback) {
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_COMPATIBILITY))
    sdl.GL_SetAttribute(sdl.GL_SHARE_WITH_CURRENT_CONTEXT, 1)

    VIDEO_STATE.emu_context = sdl.GL_CreateContext(VIDEO_STATE.window)
    if VIDEO_STATE.emu_context == nil {
        log.errorf("Failed creating OpenGL context: {}", sdl.GetError())
        return
    }

    render_cb.get_proc_address = sdl.GL_GetProcAddress
    render_cb.get_current_framebuffer = proc "c" () -> c.uintptr_t {
        return c.uintptr_t(VIDEO_STATE.fbo.framebuffer)
    }

    emulator_set_hw_render_callback(render_cb^)
}

video_handle_window_resize :: proc (event: ^sdl.Event) {
    VIDEO_STATE.window_size = { event.window.data1, event.window.data2 }
}

video_upload_pixels_to_fbo :: proc "contextless" (pixels: rawptr, width, height, pitch: u32) {
    gl.BindTexture(gl.TEXTURE_2D, VIDEO_STATE.fbo.texture)
    defer gl.BindTexture(gl.TEXTURE_2D, 0)

    format: u32
    type: u32
    bbp: u32

    switch VIDEO_STATE.pixel_format {
    case .RGB565:
        format = gl.RGB
        type = gl.UNSIGNED_SHORT_5_6_5
        bbp = 2
    case .XRGB1555:
        format = gl.BGRA
        type = gl.UNSIGNED_SHORT_5_5_5_1
        bbp = 2
    case .XRGB8888:
        format = gl.BGRA
        type = gl.UNSIGNED_INT_8_8_8_8_REV
        bbp = 4
    }

    gl.PixelStorei(gl.UNPACK_ROW_LENGTH, i32(pitch / bbp))
    defer gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB8, i32(width), i32(height), 0, format, type, pixels)
}

video_get_fbo_texture_id :: proc "contextless" () -> u32 {
    return VIDEO_STATE.fbo.texture
}

video_get_window_dimensions :: proc "contextless" () -> [2]i32 {
    return VIDEO_STATE.window_size
}

video_run_inside_emu_context :: proc "contextless" (func: proc "c" ()) {
    if emulator_is_hw_rendered() {
        sdl.GL_MakeCurrent(VIDEO_STATE.window, VIDEO_STATE.emu_context)
        func()
        sdl.GL_MakeCurrent(VIDEO_STATE.window, VIDEO_STATE.main_context)
    } else {
        func()
    }
}

video_enable_emu_gl_context :: proc "contextless" () {
    if emulator_is_hw_rendered() {
        sdl.GL_MakeCurrent(VIDEO_STATE.window, VIDEO_STATE.emu_context)
    }
}

video_disable_emu_gl_context :: proc "contextless" () {
    sdl.GL_MakeCurrent(VIDEO_STATE.window, VIDEO_STATE.main_context)
}

video_swap_window :: proc "contextless" () {
    sdl.GL_SwapWindow(VIDEO_STATE.window)
}

video_destroy_emu_context :: proc "contextless" () {
    sdl.GL_DestroyContext(VIDEO_STATE.emu_context)
}

video_set_pixel_format :: proc "contextless" (format: lr.RetroPixelFormat) {
    VIDEO_STATE.pixel_format = format
}
