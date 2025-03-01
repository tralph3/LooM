package main

import "base:runtime"
import cl "clay"
import rl "vendor:raylib"

render :: proc () {
    rl.BeginDrawing()

    if EMULATOR_STATE.running {
        render_core_framebuffer()
    } else {
        layout := build_ui_layout()
        rl.ClearBackground(rl.BLACK)
        cl.clayRaylibRender(&layout, context.temp_allocator)
    }

    rl.EndDrawing()
}

build_ui_layout :: proc () -> cl.ClayArray(cl.RenderCommand){
    cl.BeginLayout()

    if cl.UI()({
        id = cl.ID("Main Container"),
        layout = {
            sizing = { width = cl.SizingGrow({}), height = cl.SizingGrow({})},
        }
    }) {
        if cl.UI()({
            id = cl.ID("Side Container"),
            layout = {
                sizing = { width = cl.SizingFixed(230), height = cl.SizingGrow({}) },
                padding = { 10, 10, 10, 10, },
                childAlignment = {
                    x = .Center,
                    y = .Center,
                },
                layoutDirection = .TopToBottom,
            },
            backgroundColor = { 0x18, 0x18, 0x18, 255 },
        }) {
            sidebar_entry("Play", .PLAY)
            sidebar_entry("Settings", .SETTINGS)
            sidebar_entry("Quit", .QUIT)
        }

        if cl.UI()({
            id = cl.ID("Main Content Container"),
            layout = {
                layoutDirection = .TopToBottom,
                sizing = { width = cl.SizingGrow({}), height = cl.SizingGrow({})},
                childGap = 16,
                padding = { 20, 20, 20, 20, },
            },
        }) {
            #partial switch UI_STATE.selected_menu {
                case .PLAY:
                for i in 0..<len(game_entries) {
                    menu_entry(game_entries[i][0], game_entries[i][1], i)
                }
                case .SETTINGS:
                menu_entry("Setting 1", "This is a description, quite nice looking I'd say.", 0)
                menu_entry("Setting 2", "This is a description, quite nice looking I'd say.", 0)
                menu_entry("Setting 3", "This is a description, quite nice looking I'd say.", 0)
                menu_entry("Setting 4", "This is a description, quite nice looking I'd say.", 0)
            }

        }
    }

    return cl.EndLayout()
}

render_core_framebuffer :: proc () {
    rl.UpdateTexture(
        EMULATOR_STATE.frame_buffer.render_texture,
        EMULATOR_STATE.frame_buffer.data)

    rl.DrawTexturePro(
        EMULATOR_STATE.frame_buffer.render_texture,
        rl.Rectangle{0, 0, f32(EMULATOR_STATE.frame_buffer.width),f32(EMULATOR_STATE.frame_buffer.height)},
        rl.Rectangle{0, 0, f32(rl.GetScreenWidth()),f32(rl.GetScreenHeight())},
        rl.Vector2(0), 0, rl.WHITE)
}
