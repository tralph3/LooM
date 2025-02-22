package main

import "core:c"
import "core:strings"
import "core:dynlib"
import "core:time"
import rl "vendor:raylib"

AUDIO_BUFFER_SIZE_BYTES :: 16384

EmulatorState :: struct {
    input_state: [16]i16,
    frame_buffer: FrameBuffer,
    audio_buffer: AudioBuffer,
    av_info: SystemAvInfo,
    core: LibretroCore,
}

AudioBuffer :: struct {
    buffer: CircularBuffer(AUDIO_BUFFER_SIZE_BYTES),
    audio_stream: rl.AudioStream,
}

FrameBuffer :: struct {
    data: rawptr,
    width: u32,
    height: u32,
    pitch: u32,
    pixel_format: RetroPixelFormat,
    render_texture: rl.Texture2D,
}

@(private="file")
EMULATOR_STATE := EmulatorState{}

frame_buffer_init :: proc "c" () {
    render_texture := rl.LoadRenderTexture(
        i32(EMULATOR_STATE.av_info.geometry.base_width),
        i32(EMULATOR_STATE.av_info.geometry.base_height))
    defer rl.UnloadRenderTexture(render_texture)

    image := rl.LoadImageFromTexture(render_texture.texture)
    defer rl.UnloadImage(image)

    raylib_format: rl.PixelFormat = ---
    switch EMULATOR_STATE.frame_buffer.pixel_format {
    case RetroPixelFormat.F0RGB1555:
        raylib_format = rl.PixelFormat.UNKNOWN // TODO: what the fuck
    case RetroPixelFormat.FXRGB8888:
        raylib_format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
    case RetroPixelFormat.FRGB565:
        raylib_format = rl.PixelFormat.UNCOMPRESSED_R5G6B5
    }

    rl.ImageFormat(&image, raylib_format)

    EMULATOR_STATE.frame_buffer.render_texture = rl.LoadTextureFromImage(image)
}

frame_buffer_set_pixel_format :: proc "c" (format: RetroPixelFormat) {
    EMULATOR_STATE.frame_buffer.pixel_format = format
}

frame_buffer_update :: proc "c" (data: rawptr, width: u32, height: u32, pitch: u32) {
    if data == nil {
        return
    }

    EMULATOR_STATE.frame_buffer.data = data
    EMULATOR_STATE.frame_buffer.width = width
    EMULATOR_STATE.frame_buffer.height = height
    EMULATOR_STATE.frame_buffer.pitch = pitch

    if EMULATOR_STATE.frame_buffer.pixel_format == RetroPixelFormat.FXRGB8888 {
        xrgb_to_rgba(&EMULATOR_STATE.frame_buffer)
    }
}

frame_buffer_get_width :: proc "c" () -> u32 {
    return EMULATOR_STATE.frame_buffer.width
}

frame_buffer_get_height :: proc "c" () -> u32 {
    return EMULATOR_STATE.frame_buffer.height
}

input_state_set_button :: proc "c" (button_id: RetroDevice, value: i16) {
    EMULATOR_STATE.input_state[button_id] = value
}

input_state_get_button :: proc "c" (button_id: RetroDevice) -> i16 {
    return EMULATOR_STATE.input_state[button_id]
}

audio_buffer_push_batch :: proc "c" (src: ^i16, frames: i32) {
    circular_buffer_push(&EMULATOR_STATE.audio_buffer.buffer, src, u64(frames * 4))
}

audio_buffer_pop_batch :: proc "c" (dest: rawptr, frames: c.uint) {
    circular_buffer_pop(&EMULATOR_STATE.audio_buffer.buffer, dest, u64(frames * 4))
}

audio_buffer_init :: proc "c" () {
    EMULATOR_STATE.audio_buffer.audio_stream = rl.LoadAudioStream(
        u32(EMULATOR_STATE.av_info.timing.sample_rate), 16, 2)

    rl.PlayAudioStream(
        EMULATOR_STATE.audio_buffer.audio_stream)
    rl.SetAudioStreamCallback(
        EMULATOR_STATE.audio_buffer.audio_stream, raylib_audio_sample_batch_callback)
}

emulator_state_get_av_info :: proc "c" () -> ^SystemAvInfo {
    return &EMULATOR_STATE.av_info
}

emulator_init :: proc (core_path: string, rom_path: string) {
    core, ok_load_core := load_core(core_path)
    if !ok_load_core { return }

    initialize_core(&core)

    ok_load_rom := load_rom(&core, rom_path)
    if !ok_load_rom { return }

    EMULATOR_STATE.core = core

    av_info := SystemAvInfo{}
    core.get_system_av_info(&av_info)

    EMULATOR_STATE.av_info = av_info

    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(800, 600, "retrito");

    rl.InitAudioDevice()

    frame_buffer_init()
    audio_buffer_init()
}

emulator_poll_input :: proc "c" () {
    input_state_set_button(RetroDevice.IdJoypadLeft, i16(rl.IsKeyDown(rl.KeyboardKey.LEFT)))
    input_state_set_button(RetroDevice.IdJoypadRight, i16(rl.IsKeyDown(rl.KeyboardKey.RIGHT)))
    input_state_set_button(RetroDevice.IdJoypadUp, i16(rl.IsKeyDown(rl.KeyboardKey.UP)))
    input_state_set_button(RetroDevice.IdJoypadDown, i16(rl.IsKeyDown(rl.KeyboardKey.DOWN)))
    input_state_set_button(RetroDevice.IdJoypadSelect, i16(rl.IsKeyDown(rl.KeyboardKey.BACKSPACE)))
    input_state_set_button(RetroDevice.IdJoypadStart, i16(rl.IsKeyDown(rl.KeyboardKey.ENTER)))
    input_state_set_button(RetroDevice.IdJoypadA, i16(rl.IsKeyDown(rl.KeyboardKey.D)))
    input_state_set_button(RetroDevice.IdJoypadB, i16(rl.IsKeyDown(rl.KeyboardKey.X)))
    input_state_set_button(RetroDevice.IdJoypadX, i16(rl.IsKeyDown(rl.KeyboardKey.W)))
    input_state_set_button(RetroDevice.IdJoypadY, i16(rl.IsKeyDown(rl.KeyboardKey.A)))
}

emulator_draw :: proc "c" () {
    rl.BeginDrawing()

    rl.UpdateTexture(
        EMULATOR_STATE.frame_buffer.render_texture,
        EMULATOR_STATE.frame_buffer.data)

    rl.DrawTexturePro(
        EMULATOR_STATE.frame_buffer.render_texture,
        rl.Rectangle{0, 0, f32(frame_buffer_get_width()),f32(frame_buffer_get_height())},
        rl.Rectangle{0, 0, f32(rl.GetScreenWidth()),f32(rl.GetScreenHeight())},
        rl.Vector2(0), 0, rl.WHITE)

    rl.EndDrawing()
}

emulator_main_loop :: proc "c" () {
    frame_time := 1 / EMULATOR_STATE.av_info.timing.fps

    last_time := time.now()

    for !rl.WindowShouldClose() {
        elapsed_time := time.since(last_time)
        if time.duration_seconds(elapsed_time) < frame_time {
            continue
        }
        last_time = time.now()

        emulator_poll_input()

        EMULATOR_STATE.core.run()

        emulator_draw()
    }
}

emulator_quit :: proc () {
    dynlib.unload_library(EMULATOR_STATE.core.__handle)
    rl.UnloadTexture(EMULATOR_STATE.frame_buffer.render_texture)
}
