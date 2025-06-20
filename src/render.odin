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
gl_context: sdl.GLContext

VideoState :: struct {
    window: ^sdl.Window,
    renderer: ^sdl.Renderer,
    render_texture: ^sdl.Texture,
    text_engine: ^ttf.TextEngine,
    pixel_format: lr.RetroPixelFormat,
    fonts: [dynamic]^ttf.Font,

    shared_context: bool,
}

renderer_init :: proc () -> (ok: bool) {
    if !sdl.Init({ .VIDEO, .AUDIO, .EVENTS }) {
        log.errorf("Failed initializing SDL: {}", sdl.GetError())
        return false
    }

    if !ttf.Init() {
        log.errorf("Failed initializing text: {}", sdl.GetError())
        return false
    }

    GLOBAL_STATE.video_state.window = sdl.CreateWindow("Libretro Frontend", 800, 600, { .RESIZABLE })
    if GLOBAL_STATE.video_state.window == nil {
        log.errorf("Failed creating window: {}", sdl.GetError())
        return false
    }

    GLOBAL_STATE.video_state.renderer = sdl.CreateRenderer(GLOBAL_STATE.video_state.window, "")
    if GLOBAL_STATE.video_state.renderer == nil {
        log.errorf("Failed creating renderer: {}", sdl.GetError())
        return false
    }

    GLOBAL_STATE.video_state.text_engine = ttf.CreateRendererTextEngine(GLOBAL_STATE.video_state.renderer)
    if GLOBAL_STATE.video_state.text_engine == nil {
        log.errorf("Faield creating text engine: {}", sdl.GetError())
        return false
    }

    sdl.SetWindowResizable(GLOBAL_STATE.video_state.window, true)

    return true
}

renderer_update_texture_dimensions_and_format :: proc "contextless" () {
    context = GLOBAL_STATE.ctx

    pixel_format: sdl.PixelFormat
    switch GLOBAL_STATE.video_state.pixel_format {
    case .RGB565:
        pixel_format = .RGB565
    case .XRGB1555:
        pixel_format = .XRGB1555
    case .XRGB8888:
        pixel_format = .XRGB8888
    }

    texture_props := sdl.CreateProperties()
    defer sdl.DestroyProperties(texture_props)

    sdl.SetNumberProperty(texture_props, sdl.PROP_TEXTURE_CREATE_WIDTH_NUMBER, i64(GLOBAL_STATE.emulator_state.av_info.geometry.max_width))
    sdl.SetNumberProperty(texture_props, sdl.PROP_TEXTURE_CREATE_HEIGHT_NUMBER, i64(GLOBAL_STATE.emulator_state.av_info.geometry.max_height))
    sdl.SetNumberProperty(texture_props, sdl.PROP_TEXTURE_CREATE_ACCESS_NUMBER, i64(sdl.TextureAccess.TARGET))
    sdl.SetNumberProperty(texture_props, sdl.PROP_TEXTURE_CREATE_FORMAT_NUMBER, i64(pixel_format))

    sdl.DestroyTexture(GLOBAL_STATE.video_state.render_texture)
    GLOBAL_STATE.video_state.render_texture = sdl.CreateTextureWithProperties(
        GLOBAL_STATE.video_state.renderer,
        texture_props,
    )
    if GLOBAL_STATE.video_state.render_texture == nil {
        log.errorf("Failed creating texture: {}", sdl.GetError())
        return
    }
    sdl.SetTextureScaleMode(GLOBAL_STATE.video_state.render_texture, .NEAREST)
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

renderer_init_opengl_context :: proc (render_cb: ^lr.RetroHwRenderCallback) {
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, i32(render_cb.version_major))
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, i32(render_cb.version_minor))
    sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_CORE))

    // if render_cb.depth || render_cb.stencil {
    //     sdl.GL_SetAttribute(sdl.GL_DEPTH_SIZE, 24)
    //     sdl.GL_SetAttribute(sdl.GL_STENCIL_SIZE, 8)
    // }

    gl_context = sdl.GL_CreateContext(GLOBAL_STATE.video_state.window)
    if gl_context == nil {
        log.errorf("OpenGL context creation failed: %s", sdl.GetError())
        return
    }

    sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, gl_context)

    texture_props := sdl.CreateProperties()
    defer sdl.DestroyProperties(texture_props)

    gen_framebuffers := (proc "c" (i32, ^u32))(sdl.GL_GetProcAddress("glGenFramebuffers"))
    gen_textures := (proc "c" (i32, ^u32))(sdl.GL_GetProcAddress("glGenTextures"))
    gen_renderbuffers := (proc "c" (i32, ^u32))(sdl.GL_GetProcAddress("glGenRenderbuffers"))
    bind_texture := (proc "c" (i32, u32))(sdl.GL_GetProcAddress("glBindTexture"))
    bind_framebuffer := (proc "c" (i32, u32))(sdl.GL_GetProcAddress("glBindFramebuffer"))
    bind_renderbuffer := (proc "c" (i32, u32))(sdl.GL_GetProcAddress("glBindRenderbuffer"))
    renderbuffer_storage := (proc "c" (target: u32, internalformat: u32, width: i32, height: i32))(sdl.GL_GetProcAddress("glRenderbufferStorage"))
    tex_image_2d := (proc "c" (target: u32, level, internalformat, width, height, border: i32, format, type: u32, pixels: rawptr))(sdl.GL_GetProcAddress("glTexImage2D"))
    tex_parameteri := (proc "c" (target, pname: u32, param: i32))(sdl.GL_GetProcAddress("glTexParameteri"))
    framebuffer_parameteri := (proc "c" (target: u32, pname: u32, param: i32))(sdl.GL_GetProcAddress("glFramebufferParameteri"))
    framebuffer_texture_2d := (proc "c" (target: u32, attachment: u32, textarget: u32, texture: u32, level: i32))(sdl.GL_GetProcAddress("glFramebufferTexture2D"))
    framebuffer_renderbuffer := (proc "c" (target: u32, attachment: u32, renderbuffertarget: u32, renderbuffer: u32))(sdl.GL_GetProcAddress("glFramebufferRenderbuffer"))
    get_error := (proc "c" () -> u32)(sdl.GL_GetProcAddress("glGetError"))
    check_framebuffer_status := (proc "c" (u32) -> u32)(sdl.GL_GetProcAddress("glCheckFramebufferStatus"))

    gen_framebuffers(1, &fbo_id)
    bind_framebuffer(gl.FRAMEBUFFER, fbo_id)

    tex_id: u32
    gen_textures(1, &tex_id)
    bind_texture(gl.TEXTURE_2D, tex_id)
    tex_image_2d(gl.TEXTURE_2D, 0, gl.RGBA8, i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_width), i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_height), 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
    tex_parameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    tex_parameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

    framebuffer_texture_2d(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex_id, 0)


    // Create a depth renderbuffer
    // depth_rb: u32
    // gen_renderbuffers(1, &depth_rb)
    // bind_renderbuffer(gl.RENDERBUFFER, depth_rb)
    // renderbuffer_storage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT, i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_width), i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_height))

    // // Attach the depth renderbuffer to the FBO
    // framebuffer_renderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, depth_rb)

    if check_framebuffer_status(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
        log.errorf("Incomplete framebuffer: {}", get_error())
    }

    bind_framebuffer(gl.FRAMEBUFFER, 0)
    bind_texture(gl.TEXTURE_2D, 0)

    sdl.SetNumberProperty(texture_props, sdl.PROP_TEXTURE_CREATE_WIDTH_NUMBER, i64(GLOBAL_STATE.emulator_state.av_info.geometry.max_width))
    sdl.SetNumberProperty(texture_props, sdl.PROP_TEXTURE_CREATE_HEIGHT_NUMBER, i64(GLOBAL_STATE.emulator_state.av_info.geometry.max_height))
    sdl.SetNumberProperty(texture_props, sdl.PROP_TEXTURE_CREATE_ACCESS_NUMBER, i64(sdl.TextureAccess.TARGET))
    sdl.SetNumberProperty(texture_props, sdl.PROP_TEXTURE_CREATE_OPENGL_TEXTURE_NUMBER, i64(tex_id))

    sdl.DestroyTexture(GLOBAL_STATE.video_state.render_texture)
    GLOBAL_STATE.video_state.render_texture = sdl.CreateTextureWithProperties(
        GLOBAL_STATE.video_state.renderer,
        texture_props,
    )
    if GLOBAL_STATE.video_state.render_texture == nil {
        log.errorf("Failed creating texture: {}", sdl.GetError())
        return
    }
    sdl.SetTextureScaleMode(GLOBAL_STATE.video_state.render_texture, .NEAREST)

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
