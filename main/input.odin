package main

import rl "vendor:raylib"
import lr "libretro"

process_input :: proc () {
    using lr
    STATE.input[RetroDevice.IdJoypadLeft]   = i16(rl.IsKeyDown(.LEFT)      || rl.IsGamepadButtonDown(0, .LEFT_FACE_LEFT))
    STATE.input[RetroDevice.IdJoypadRight]  = i16(rl.IsKeyDown(.RIGHT)     || rl.IsGamepadButtonDown(0, .LEFT_FACE_RIGHT))
    STATE.input[RetroDevice.IdJoypadUp]     = i16(rl.IsKeyDown(.UP)        || rl.IsGamepadButtonDown(0, .LEFT_FACE_UP))
    STATE.input[RetroDevice.IdJoypadDown]   = i16(rl.IsKeyDown(.DOWN)      || rl.IsGamepadButtonDown(0, .LEFT_FACE_DOWN))
    STATE.input[RetroDevice.IdJoypadSelect] = i16(rl.IsKeyDown(.BACKSPACE) || rl.IsGamepadButtonDown(0, .MIDDLE_LEFT))
    STATE.input[RetroDevice.IdJoypadStart]  = i16(rl.IsKeyDown(.ENTER)     || rl.IsGamepadButtonDown(0, .MIDDLE_RIGHT))
    STATE.input[RetroDevice.IdJoypadA]      = i16(rl.IsKeyDown(.D)         || rl.IsGamepadButtonDown(0, .RIGHT_FACE_RIGHT))
    STATE.input[RetroDevice.IdJoypadB]      = i16(rl.IsKeyDown(.X)         || rl.IsGamepadButtonDown(0, .RIGHT_FACE_DOWN))
    STATE.input[RetroDevice.IdJoypadX]      = i16(rl.IsKeyDown(.W)         || rl.IsGamepadButtonDown(0, .RIGHT_FACE_UP))
    STATE.input[RetroDevice.IdJoypadY]      = i16(rl.IsKeyDown(.A)         || rl.IsGamepadButtonDown(0, .RIGHT_FACE_LEFT))

    if rl.IsKeyPressed(.ESCAPE) || rl.IsGamepadButtonPressed(0, .MIDDLE_RIGHT) {
        if STATE.state == .RUNNING {
            change_state(.PAUSED)
        }
    }

    if rl.IsKeyPressed(.RIGHT) || rl.IsGamepadButtonPressed(0, .LEFT_FACE_RIGHT){
        ui_select_right()
    } else if rl.IsKeyPressed(.LEFT) || rl.IsGamepadButtonPressed(0, .LEFT_FACE_LEFT) {
        ui_select_left()
    } else if rl.IsKeyPressed(.UP) || rl.IsGamepadButtonPressed(0, .LEFT_FACE_UP) {
        ui_select_up()
    } else if rl.IsKeyPressed(.DOWN) || rl.IsGamepadButtonPressed(0, .LEFT_FACE_DOWN) {
        ui_select_down()
    } else if rl.IsKeyPressed(.ENTER) || rl.IsGamepadButtonPressed(0, .RIGHT_FACE_DOWN) {
        ui_press_element()
    }
}
