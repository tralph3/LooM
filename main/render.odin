package main

import "base:runtime"
import cl "clay"
import rl "vendor:raylib"

render :: proc () {
    cl.BeginLayout()

    switch STATE.state {
    case .RUNNING:
        ui_layout_running_screen()
    case .MENU:
        ui_layout_main_menu_screen()
    case .PAUSED:
        ui_layout_pause_screen()
    case .LOGIN:
        ui_layout_login_screen()
    }

    layout := cl.EndLayout()

    rl.BeginDrawing()

    rl.ClearBackground(rl.BLACK)
    cl.clayRaylibRender(&layout)
    rl.DrawFPS(0, 0)

    rl.EndDrawing()
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
