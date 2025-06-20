package main

import "base:runtime"
import cl "clay"
import sdl "vendor:sdl3"
import lr "libretro"
import "vendor:sdl3/ttf"
import "core:log"
import "core:c"
import gl "vendor:OpenGL"

fbo_id: u32
tex_id: u32
gl_context: sdl.GLContext

VideoState :: struct {
    window: ^sdl.Window,
    text_engine: ^ttf.TextEngine,
    pixel_format: lr.RetroPixelFormat,
    fonts: [dynamic]^ttf.Font,

    // dont use
    renderer: ^sdl.Renderer,
    render_texture: ^sdl.Texture,

    actual_width: u32,
    actual_height: u32,

    shared_context: bool,
}

renderer_init :: proc () -> (ok: bool) {
    if !sdl.Init({ .VIDEO, .AUDIO, .EVENTS }) {
        log.errorf("Failed initializing SDL: {}", sdl.GetError())
        return false
    }

    // if !ttf.Init() {
    //     log.errorf("Failed initializing text: {}", sdl.GetError())
    //     return false
    // }

    GLOBAL_STATE.video_state.window = sdl.CreateWindow("Libretro Frontend", 800, 600, { .RESIZABLE, .OPENGL })
    if GLOBAL_STATE.video_state.window == nil {
        log.errorf("Failed creating window: {}", sdl.GetError())
        return false
    }

    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_CORE))

    gl_context = sdl.GL_CreateContext(GLOBAL_STATE.video_state.window)
    if gl_context == nil {
        log.errorf("Failed creating OpenGL context: {}", sdl.GetError())
        return false
    }

    gl.load_up_to(3, 3, sdl.gl_set_proc_address)

    if !sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, gl_context) {
        log.errorf("Failed making OpenGL context current: {}", sdl.GetError())
        return false
    }

    // GLOBAL_STATE.video_state.text_engine = ttf.CreateTextEngine
    // if GLOBAL_STATE.video_state.text_engine == nil {
    //     log.errorf("Faield creating text engine: {}", sdl.GetError())
    //     return false
    // }

    return true
}

renderer_deinit :: proc () {
    sdl.DestroyTexture(GLOBAL_STATE.video_state.render_texture)

    for font in GLOBAL_STATE.video_state.fonts {
        ttf.CloseFont(font)
    }
    delete(GLOBAL_STATE.video_state.fonts)

    ttf.DestroyRendererTextEngine(GLOBAL_STATE.video_state.text_engine)
    sdl.DestroyRenderer(GLOBAL_STATE.video_state.renderer)
    sdl.DestroyWindow(GLOBAL_STATE.video_state.window)

    ttf.Quit()
    sdl.Quit()
}

renderer_load_font :: proc (path: cstring, size: f32) {
    font := ttf.OpenFont(path, size)
    if font == nil {
        log.errorf("Failed loading font: {}", sdl.GetError())
        return
    }

    append(&GLOBAL_STATE.video_state.fonts, font)
}

renderer_destroy_framebuffer :: proc () {

}

renderer_init_framebuffer :: proc () {
    gl.GenTextures(1, &tex_id)
    gl.BindTexture(gl.TEXTURE_2D, tex_id)
    gl.TexImage2D(
        gl.TEXTURE_2D, 0, gl.RGBA8,
        i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_width),
        i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_height),
        0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    gl.GenFramebuffers(1, &fbo_id)
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo_id)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex_id, 0)

    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
        log.errorf("Incomplete framebuffer: {}", gl.GetError())
    }
}

renderer_init_opengl_context :: proc (render_cb: ^lr.RetroHwRenderCallback) {
    sdl.GL_DestroyContext(gl_context)

    major_ver := render_cb.version_major
    minor_ver := render_cb.version_minor

    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, i32(major_ver))
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, i32(minor_ver))
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_CORE))

    gl_context = sdl.GL_CreateContext(GLOBAL_STATE.video_state.window)
    sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, gl_context)

    gl.load_up_to(int(major_ver), int(minor_ver), sdl.gl_set_proc_address)

    renderer_init_framebuffer()

    render_cb.get_proc_address = sdl.GL_GetProcAddress
    render_cb.get_current_framebuffer = proc "c" () -> c.uintptr_t {
        return c.uintptr_t(fbo_id)
    }
}

// build_ui_layout :: proc () -> cl.ClayArray(cl.RenderCommand){
//     cl.BeginLayout()

//     if cl.UI()({
//         id = cl.ID("Main Container"),
//         layout = {
//             sizing = { width = cl.SizingGrow({}), height = cl.SizingGrow({})},
//         }
//     }) {
//         if cl.UI()({
//             id = cl.ID("Side Container"),
//             layout = {
//                 sizing = { width = cl.SizingFixed(230), height = cl.SizingGrow({}) },
//                 padding = { 10, 10, 10, 10, },
//                 childAlignment = {
//                     x = .Center,
//                     y = .Center,
//                 },
//                 layoutDirection = .TopToBottom,
//             },
//             backgroundColor = { 0x18, 0x18, 0x18, 255 },
//         }) {
//             sidebar_entry("Play", .PLAY)
//             sidebar_entry("Settings", .SETTINGS)
//             sidebar_entry("Quit", .QUIT)
//         }

//         if cl.UI()({
//             id = cl.ID("Main Content Container"),
//             layout = {
//                 layoutDirection = .TopToBottom,
//                 sizing = { width = cl.SizingGrow({}), height = cl.SizingGrow({})},
//                 childGap = 16,
//                 padding = { 20, 20, 20, 20, },
//             },
//             scroll = { vertical = true },
//         }) {
//             #partial switch UI_STATE.selected_menu {
//                 case .PLAY:
//                 for i in 0..<len(game_entries) {
//                     menu_entry(game_entries[i][0], game_entries[i][1], i)
//                 }
//                 case .SETTINGS:

//                 #partial switch STATE.state {
//                     case .MENU:
//                     menu_entry("Setting 1", "This is a description, hopefully its size is correctly calculated.\nNow here comes a newline!", 0)
//                     menu_entry("Setting 2", "This is a description", 0)
//                     menu_entry("Setting 3", "This is a description", 0)
//                     menu_entry("Setting 4", "This is a description", 0)
//                     case .PAUSED:
//                     for i in 0..<len(STATE.core_options_definitions.definitions) {
//                         setting(i)
//                     }
//                 }

//             }

//         }
//     }

//     return cl.EndLayout()
// }

// render_core_framebuffer :: proc () {
//     rl.UpdateTexture(
//         STATE.video.render_texture,
//         STATE.video.data)

//     rl.DrawTexturePro(
//         STATE.video.render_texture,
//         rl.Rectangle{0, 0, f32(STATE.video.width),f32(STATE.video.height)},
//         rl.Rectangle{0, 0, f32(rl.GetScreenWidth()),f32(rl.GetScreenHeight())},
//         rl.Vector2(0), 0, rl.WHITE)
// }
