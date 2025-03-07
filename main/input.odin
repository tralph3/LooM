package main

import rl "vendor:raylib"
import lr "libretro"

process_input :: proc () {
    using lr
    STATE.input[RetroDevice.IdJoypadLeft]   = i16(rl.IsKeyDown(.LEFT))
    STATE.input[RetroDevice.IdJoypadRight]  = i16(rl.IsKeyDown(.RIGHT))
    STATE.input[RetroDevice.IdJoypadUp]     = i16(rl.IsKeyDown(.UP))
    STATE.input[RetroDevice.IdJoypadDown]   = i16(rl.IsKeyDown(.DOWN))
    STATE.input[RetroDevice.IdJoypadSelect] = i16(rl.IsKeyDown(.BACKSPACE))
    STATE.input[RetroDevice.IdJoypadStart]  = i16(rl.IsKeyDown(.ENTER))
    STATE.input[RetroDevice.IdJoypadA]      = i16(rl.IsKeyDown(.D))
    STATE.input[RetroDevice.IdJoypadB]      = i16(rl.IsKeyDown(.X))
    STATE.input[RetroDevice.IdJoypadX]      = i16(rl.IsKeyDown(.W))
    STATE.input[RetroDevice.IdJoypadY]      = i16(rl.IsKeyDown(.A))

    if rl.IsKeyPressed(.ESCAPE) {
        #partial switch STATE.state {
        case .RUNNING:
            change_state(.PAUSED)
        case .MENU:
            logout()
        }
    }

    if rl.IsKeyPressed(.RIGHT) {
        ui_select_next_element()
    } else if rl.IsKeyPressed(.LEFT) {
        ui_select_prev_element()
    }

    if rl.IsKeyPressed(.ENTER) {
        ui_press_element()
    }
}
