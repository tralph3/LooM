package main

import sdl "vendor:sdl3"
import lr "libretro"
import cl "clay"
import "core:log"
import "core:slice"
import "core:c"

INPUT_MAX_PLAYERS :: 8

InputPlayerState :: struct #no_copy {
    joypad: [lr.RetroDeviceIdJoypad]i16,
    analog: [max(lr.RetroDeviceIdJoypad)]i16,
    gamepad: ^sdl.Gamepad,
}

InputMouseState :: struct #no_copy {
    wheel_movement: [2]f32,
    clicked: bool,
    down: bool,
    position: [2]f32,
}

InputState :: struct #no_copy {
    players: [INPUT_MAX_PLAYERS]InputPlayerState,
    // there's no keyboard input per player
    // TODO: there's many wasted bytes here... not critical, but i
    // don't like it
    keyboard: #sparse [lr.RetroKey]i16,
    mouse: InputMouseState,
}

input_init :: proc () -> (ok: bool) {
    if !input_open_gamepads() {
        log.warn("A gamepad failed to open. Try reconnecting.")
    }
    return true
}

input_deinit :: proc () {
    input_close_gamepads()
}

input_close_gamepads :: proc () {
    for &player in GLOBAL_STATE.input_state.players {
        sdl.CloseGamepad(player.gamepad)
        player.gamepad = nil
    }
    emulator_update_plugged_controllers()
}

input_open_gamepads :: proc () -> (ok:bool) {
    input_close_gamepads()

    count: c.int
    gamepad_ids := sdl.GetGamepads(&count)
    if gamepad_ids == nil {
        log.errorf("Failed getting gamepads: {}", sdl.GetError())
        return false
    }
    defer sdl.free(gamepad_ids)

    ok = true
    for i in 0..<min(count, INPUT_MAX_PLAYERS) {
        gamepad_id := gamepad_ids[i]
        gamepad := sdl.OpenGamepad(gamepad_id)
        if gamepad == nil {
            log.errorf("Failed opening gamepad '{}': {}", gamepad_id, sdl.GetError())
            ok = false
        }

        GLOBAL_STATE.input_state.players[i].gamepad = gamepad
    }

    emulator_update_plugged_controllers()

    return
}

input_handle_key_pressed :: proc (event: ^sdl.Event) {
    if event.key.repeat { return }

    #partial switch event.key.scancode {
        // case .LEFT:
        //     gui_focus_left()
        // case .RIGHT:
        //     gui_focus_right()
        // case .UP:
        //     gui_focus_up()
        // case .DOWN:
        //     gui_focus_down()
    case .ESCAPE:
        scene_change(.PAUSE)
    // case .M:
    //     gui_renderer_set_framebuffer_shader(crt_mattias_shader_source)
    }

    when ODIN_DEBUG {
        if event.key.scancode == .F12 {
            cl.SetDebugModeEnabled(true)
        }
    }
}

input_handle_mouse :: proc (event: ^sdl.Event) {
    assert(event.type == .MOUSE_WHEEL ||
           event.type == .MOUSE_BUTTON_DOWN ||
           event.type == .MOUSE_BUTTON_UP ||
           event.type == .MOUSE_MOTION)

    #partial switch event.type {
    case .MOUSE_MOTION:
        GLOBAL_STATE.input_state.mouse.position = { event.motion.x, event.motion.y }
    case .MOUSE_BUTTON_DOWN:
        GLOBAL_STATE.input_state.mouse.clicked = true
        GLOBAL_STATE.input_state.mouse.down = true
    case .MOUSE_BUTTON_UP:
        GLOBAL_STATE.input_state.mouse.down = false
    case .MOUSE_WHEEL:
        GLOBAL_STATE.input_state.mouse.wheel_movement = { event.wheel.x, event.wheel.y }
    }
}

// Resets input state for things that should be active a single frame
input_reset :: proc () {
    GLOBAL_STATE.input_state.mouse.wheel_movement = {}
    GLOBAL_STATE.input_state.mouse.clicked = false
}

input_handle_gamepad_pressed :: proc (event: ^sdl.Event) {
    if event.type != .GAMEPAD_BUTTON_DOWN { return }
    #partial switch sdl.GamepadButton(event.gbutton.button) {
    case .GUIDE, .TOUCHPAD:
        scene_change(.PAUSE)
    }
}

input_set_rumble :: proc "c" (port: uint, effect: lr.RetroRumbleEffect, strength: u16) -> (did_rumble: bool) {
    if port >= INPUT_MAX_PLAYERS { return false }

    gamepad := GLOBAL_STATE.input_state.players[port].gamepad

    switch effect {
    case .Strong:
        sdl.RumbleGamepad(gamepad, 0, strength, 5000) or_return
    case .Weak:
        sdl.RumbleGamepad(gamepad, strength, 0, 5000) or_return
    }

    return true
}

input_update_emulator_keyboard_state :: proc (event: ^sdl.Event) {
    // TODO: not all keys are properly handled by this
    retro_keycode := lr.RetroKey(event.key.key)
    is_down := event.type == .KEY_DOWN ? true : false

    if retro_keycode < max(lr.RetroKey) {
        GLOBAL_STATE.input_state.keyboard[retro_keycode] = is_down ? 1 : 0
    }

    if GLOBAL_STATE.emulator_state.keyboard_callback == nil { return }

    modifiers := input_get_modifiers_bitmap(event.key.mod)
    // TODO: map utf32
    utf32: u32

    GLOBAL_STATE.emulator_state.keyboard_callback(is_down, retro_keycode, utf32, modifiers)
}

input_get_modifiers_bitmap :: proc (mod: sdl.Keymod) -> u16 {
    modifiers: u16 = 0

    if sdl.KMOD_SHIFT & mod != sdl.KMOD_NONE {
        modifiers |= u16(lr.RetroMod.Shift)
    }
    if sdl.KMOD_CTRL & mod != sdl.KMOD_NONE {
        modifiers |= u16(lr.RetroMod.Ctrl)
    }
    if sdl.KMOD_ALT & mod != sdl.KMOD_NONE {
        modifiers |= u16(lr.RetroMod.Alt)
    }
    if sdl.KMOD_GUI & mod != sdl.KMOD_NONE {
        modifiers |= u16(lr.RetroMod.Meta)
    }
    if sdl.KMOD_NUM & mod != sdl.KMOD_NONE {
        modifiers |= u16(lr.RetroMod.NumLock)
    }
    if sdl.KMOD_CAPS & mod != sdl.KMOD_NONE {
        modifiers |= u16(lr.RetroMod.CapsLock)
    }
    if sdl.KMOD_SCROLL & mod != sdl.KMOD_NONE {
        modifiers |= u16(lr.RetroMod.ScrolLock)
    }

    return modifiers
}
