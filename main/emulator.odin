package main

import "base:runtime"
import "libretro"
import cb "circular_buffer"
import "core:c"
import "core:strings"
import "core:dynlib"
import "core:time"
import rl "vendor:raylib"
import cl "clay"
import "core:log"
import "core:mem"

AUDIO_BUFFER_SIZE_BYTES :: 16384

EmulatorState :: struct {
    running: bool,
    input_state: [16]i16,
    frame_buffer: FrameBuffer,
    audio_buffer: AudioBuffer,
    av_info: libretro.SystemAvInfo,
    core: libretro.LibretroCore,
    core_options_definitions: libretro.RetroCoreOptionsV2,
    core_options: map[cstring]cstring,
}

AudioBuffer :: struct {
    buffer: cb.CircularBuffer(AUDIO_BUFFER_SIZE_BYTES),
    audio_stream: rl.AudioStream,
}

FrameBuffer :: struct {
    data: rawptr,
    width: u32,
    height: u32,
    pitch: u32,
    pixel_format: libretro.RetroPixelFormat,
    render_texture: rl.Texture2D,
}

EMULATOR_STATE := EmulatorState {
    running = false,
    frame_buffer = FrameBuffer {
        pixel_format = libretro.RetroPixelFormat.F0RGB1555
    },
    core = {
        loaded = false,
    },
    av_info = {
        timing = {
            fps = 60,
        }
    }
}

frame_buffer_init :: proc "c" () {
    render_texture := rl.LoadRenderTexture(
        i32(EMULATOR_STATE.av_info.geometry.base_width),
        i32(EMULATOR_STATE.av_info.geometry.base_height))
    defer rl.UnloadRenderTexture(render_texture)

    image := rl.LoadImageFromTexture(render_texture.texture)
    defer rl.UnloadImage(image)

    raylib_format: rl.PixelFormat = ---
    switch EMULATOR_STATE.frame_buffer.pixel_format {
    case libretro.RetroPixelFormat.F0RGB1555:
        raylib_format = rl.PixelFormat.UNKNOWN // TODO: what the fuck
    case libretro.RetroPixelFormat.FXRGB8888:
        raylib_format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
    case libretro.RetroPixelFormat.FRGB565:
        raylib_format = rl.PixelFormat.UNCOMPRESSED_R5G6B5
    }

    rl.ImageFormat(&image, raylib_format)

    EMULATOR_STATE.frame_buffer.render_texture = rl.LoadTextureFromImage(image)
}

frame_buffer_update :: proc "c" (data: rawptr, width: u32, height: u32, pitch: u32) {
    if data == nil {
        return
    }

    EMULATOR_STATE.frame_buffer.data = data
    EMULATOR_STATE.frame_buffer.width = width
    EMULATOR_STATE.frame_buffer.height = height
    EMULATOR_STATE.frame_buffer.pitch = pitch

    if EMULATOR_STATE.frame_buffer.pixel_format == libretro.RetroPixelFormat.FXRGB8888 {
        xrgb_to_rgba(&EMULATOR_STATE.frame_buffer)
    }
}

emulator_run_game :: proc (core_path: string, rom_path: string) {
    emulator_quit()

    core, ok_load_core := libretro.load_core(core_path)
    if !ok_load_core { return }

    callbacks := libretro.Callbacks {
        environment = environment_callback,
        video_refresh = video_refresh_callback,
        input_poll = input_poll_callback,
        input_state = input_state_callback,
        audio_sample = audio_sample_callback,
        audio_sample_batch = audio_sample_batch_callback,
    }

    libretro.initialize_core(&core, &callbacks)

    ok_load_rom := libretro.load_rom(&core, rom_path)
    if !ok_load_rom { return }

    EMULATOR_STATE.core = core

    av_info := libretro.SystemAvInfo{}
    core.get_system_av_info(&av_info)

    EMULATOR_STATE.av_info = av_info

    frame_buffer_init()
    audio_buffer_init()

    EMULATOR_STATE.running = true
}

emulator_poll_input :: proc "c" () {
    using libretro
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadLeft] = i16(rl.IsKeyDown(rl.KeyboardKey.LEFT))
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadRight] = i16(rl.IsKeyDown(rl.KeyboardKey.RIGHT))
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadUp] = i16(rl.IsKeyDown(rl.KeyboardKey.UP))
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadDown] = i16(rl.IsKeyDown(rl.KeyboardKey.DOWN))
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadSelect] = i16(rl.IsKeyDown(rl.KeyboardKey.BACKSPACE))
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadStart] = i16(rl.IsKeyDown(rl.KeyboardKey.ENTER))
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadA] = i16(rl.IsKeyDown(rl.KeyboardKey.D))
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadB] = i16(rl.IsKeyDown(rl.KeyboardKey.X))
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadX] = i16(rl.IsKeyDown(rl.KeyboardKey.W))
    EMULATOR_STATE.input_state[RetroDevice.IdJoypadY] = i16(rl.IsKeyDown(rl.KeyboardKey.A))

    if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
        EMULATOR_STATE.running = false
    }
}

emulator_main_loop :: proc () {
    last_time := time.now()

    for !rl.WindowShouldClose() {
        frame_time := 1 / EMULATOR_STATE.av_info.timing.fps

        elapsed_time := time.since(last_time)
        if time.duration_seconds(elapsed_time) < frame_time {
            continue
        }
        last_time = time.now()

        cl.SetLayoutDimensions({ width = f32(rl.GetScreenWidth()), height = f32(rl.GetScreenHeight()) })
        cl.SetPointerState(
            { rl.GetMousePosition().x, rl.GetMousePosition().y },
            rl.IsMouseButtonDown(.LEFT),
        )
        cl.UpdateScrollContainers(
            true,
            { rl.GetMouseWheelMoveV().x, rl.GetMouseWheelMoveV().y } * 5,
            rl.GetFrameTime(),
        )

        emulator_poll_input()

        if EMULATOR_STATE.running {
            EMULATOR_STATE.core.run()
        }

        render()
    }
}

emulator_quit :: proc () {
    if EMULATOR_STATE.core.loaded {
        libretro.unload_core(EMULATOR_STATE.core)
        rl.UnloadTexture(EMULATOR_STATE.frame_buffer.render_texture)
        rl.UnloadAudioStream(EMULATOR_STATE.audio_buffer.audio_stream)
        cb.circular_buffer_clear(&EMULATOR_STATE.audio_buffer.buffer)
    }
}

emulator_clone_core_options_v2 :: proc (options_union: union { libretro.RetroCoreOptionsV2, libretro.RetroCoreOptionsV2Intl }) {
    delete(EMULATOR_STATE.core_options)

    options: libretro.RetroCoreOptionsV2

    switch o in options_union {
    case libretro.RetroCoreOptionsV2:
        options = o
    case libretro.RetroCoreOptionsV2Intl:
        // if o.local != nil {
        //     options = o.local^
        // } else  {
            options = o.us^
        // }
    }

    definitions: [^]libretro.RetroCoreOptionV2Definition = raw_data(options.definitions)
    categories: [^]libretro.RetroCoreOptionV2Category = raw_data(options.categories)

    def_count := 0
    for true {
        definition := definitions[def_count]
        if definition.key == nil { break }
        def_count += 1
    }

    EMULATOR_STATE.core_options_definitions.definitions = make_slice([]libretro.RetroCoreOptionV2Definition, def_count)
    EMULATOR_STATE.core_options = make(map[cstring]cstring)

    for i in 0..<def_count {
        clone_cstring(&EMULATOR_STATE.core_options_definitions.definitions[i].key, definitions[i].key)
        clone_cstring(&EMULATOR_STATE.core_options_definitions.definitions[i].display, definitions[i].display)
        clone_cstring(&EMULATOR_STATE.core_options_definitions.definitions[i].display_categorized, definitions[i].display_categorized)
        clone_cstring(&EMULATOR_STATE.core_options_definitions.definitions[i].info, definitions[i].info)
        clone_cstring(&EMULATOR_STATE.core_options_definitions.definitions[i].info_categorized, definitions[i].info_categorized)
        clone_cstring(&EMULATOR_STATE.core_options_definitions.definitions[i].category_key, definitions[i].category_key)
        clone_cstring(&EMULATOR_STATE.core_options_definitions.definitions[i].default_value, definitions[i].default_value)

        for j in 0..<libretro.RETRO_NUM_CORE_OPTION_VALUES_MAX {
            clone_cstring(&EMULATOR_STATE.core_options_definitions.definitions[i].values[j].value, definitions[i].values[j].value)
            clone_cstring(&EMULATOR_STATE.core_options_definitions.definitions[i].values[j].label, definitions[i].values[j].label)
        }

        if EMULATOR_STATE.core_options_definitions.definitions[i].default_value != nil {
            EMULATOR_STATE.core_options[EMULATOR_STATE.core_options_definitions.definitions[i].key] = EMULATOR_STATE.core_options_definitions.definitions[i].default_value
        } else {
            EMULATOR_STATE.core_options[EMULATOR_STATE.core_options_definitions.definitions[i].key] = EMULATOR_STATE.core_options_definitions.definitions[i].values[0].value
        }
    }

    cat_count := 0
    for true {
        category := categories[cat_count]
        if category.key == nil { break }
        cat_count += 1
    }

    EMULATOR_STATE.core_options_definitions.categories = make_slice([]libretro.RetroCoreOptionV2Category, cat_count)

    for i in 0..<cat_count {
        clone_cstring(&EMULATOR_STATE.core_options_definitions.categories[i].key, categories[i].key)
        clone_cstring(&EMULATOR_STATE.core_options_definitions.categories[i].display, categories[i].display)
        clone_cstring(&EMULATOR_STATE.core_options_definitions.categories[i].info, categories[i].info)
    }
}

clone_cstring :: proc (dest: ^cstring, src: cstring) {
    str := strings.clone_from_cstring(src)
    dest^ = strings.unsafe_string_to_cstring(str)
}
