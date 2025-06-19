package main

import "base:runtime"
import cl "clay"
import sdl "vendor:sdl3"
import lr "libretro"
import "vendor:sdl3/ttf"
import "core:log"

VideoState :: struct {
    window: ^sdl.Window,
    renderer: ^sdl.Renderer,
    render_texture: ^sdl.Texture,
    text_engine: ^ttf.TextEngine,
    pixel_format: lr.RetroPixelFormat,
    fonts: [dynamic]^ttf.Font,
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

    GLOBAL_STATE.video_state.window = sdl.CreateWindow("Libretro Frontend", 800, 600, {.RESIZABLE})
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
    pixel_format: sdl.PixelFormat
    switch GLOBAL_STATE.video_state.pixel_format {
    case .RGB565:
        pixel_format = .RGB565
    case .XRGB1555:
        pixel_format = .XRGB1555
    case .XRGB8888:
        pixel_format = .XRGB8888
    }

    sdl.DestroyTexture(GLOBAL_STATE.video_state.render_texture)
    GLOBAL_STATE.video_state.render_texture = sdl.CreateTexture(
        GLOBAL_STATE.video_state.renderer,
        pixel_format,
        .TARGET,
        i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_width),
        i32(GLOBAL_STATE.emulator_state.av_info.geometry.max_height),
    )
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
