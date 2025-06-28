package main

import cl "clay"
import "core:math"
import "base:runtime"
import sdl "vendor:sdl3"
import gl "vendor:OpenGL"
import "vendor:sdl3/ttf"
import "core:log"
import "core:mem"
import lr "libretro"
import "core:time"
import "core:c"
import cb "circular_buffer"

wait_until_next_frame :: #force_inline proc(last_time_ns: u64) {
    fps := GLOBAL_STATE.emulator_state.av_info.timing.fps > 0 \
        ? GLOBAL_STATE.emulator_state.av_info.timing.fps \
        : 60

    frame_duration_ns := u64((1.0 / fps) * 1_000_000_000.0)
    elapsed_ns := sdl.GetTicksNS() - last_time_ns

    if elapsed_ns >= frame_duration_ns {
        return
    }

    remaining_ns := frame_duration_ns - elapsed_ns

    if remaining_ns > 1_000_000 {
        sdl.DelayNS(remaining_ns - 1_000_000)
    }

    target_ns := last_time_ns + frame_duration_ns
    for sdl.GetTicksNS() < target_ns {
        // active wait
    }
}

app_init :: proc "c" (appstate: ^rawptr, argc: c.int, argv: [^]cstring) -> sdl.AppResult {
    context = GLOBAL_STATE.ctx

    if !video_init() {
        log.error("Failed initializing video")
        return .FAILURE
    }

    if !gui_init() {
        log.error("Failed initializing GUI")
        return .FAILURE
    }

    if !audio_init() {
        log.error("Failed initializing audio")
        return .FAILURE
    }

    scene_init()

    //load_game("./cores/fceumm_libretro.so", "./roms/Legend of Zelda, The (U) (PRG1) [!].nes")
    //load_game("./cores/mesen_libretro.so", "./roms/Legend of Zelda, The (U) (PRG1) [!].nes")
    //load_game("./cores/bsnes_libretro_debug.so", "./roms/Super Castlevania IV (USA).sfc")
    //load_game("./cores/bsnes_libretro_debug.so", "./roms/Final Fantasy III (USA) (Rev 1).sfc")
    load_game("./cores/desmume_libretro.so", "./roms/Mario Kart DS (USA) (En,Fr,De,Es,It).nds")
    //load_game("./cores/desmume_libretro_debug.so", "./roms/Mario Kart DS (USA) (En,Fr,De,Es,It).nds")
    //load_game("./cores/mupen64plus_next_libretro.so", "./roms/Super Mario 64 (U) [!].z64")
    //load_game("./cores/mupen64plus_next_libretro_debug.so", "./roms/Super Mario 64 (U) [!].z64")
    //load_game("./cores/parallel_n64_libretro.so", "./roms/Super Mario 64 (U) [!].z64")

    return .CONTINUE
}

last_time: u64
app_iterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    context = GLOBAL_STATE.ctx

    if GLOBAL_STATE.should_exit {
        return .SUCCESS
    }

    if !GLOBAL_STATE.emulator_state.fast_forward {
        wait_until_next_frame(last_time)
    }

    last_time = sdl.GetTicksNS()

    gui_update()

    buffered_bytes := int(GLOBAL_STATE.audio_state.buffer.size)
    buffer_capacity := len(GLOBAL_STATE.audio_state.buffer.data)

    should_run_frame := buffered_bytes < AUDIO_BUFFER_OVERFLOW_LIMIT

    scene := scene_get(GLOBAL_STATE.current_scene_id)

    if GLOBAL_STATE.current_scene_id != .RUNNING || should_run_frame || GLOBAL_STATE.emulator_state.fast_forward {
        scene.update()
    }

    scene.render()

    sdl.GL_SwapWindow(GLOBAL_STATE.video_state.window)

    return .CONTINUE
}

app_event :: proc "c" (appstate: rawptr, event: ^sdl.Event) -> sdl.AppResult {
    context = GLOBAL_STATE.ctx

    #partial switch event.type {
    case .QUIT:
        GLOBAL_STATE.should_exit = true
    case .MOUSE_WHEEL:
        GLOBAL_STATE.input_state.mouse_wheel_y = event.wheel.y
    case .GAMEPAD_BUTTON_DOWN, .GAMEPAD_AXIS_MOTION:
        if !sdl.HideCursor() {
            log.warn("Failed hiding cursor: {}", sdl.GetError())
        }
    case .KEY_DOWN, .MOUSE_MOTION:
        if !sdl.ShowCursor() {
            log.warn("Failed showing cursor: {}", sdl.GetError())
        }

        input_handle_key_pressed(event)
    }

    return .CONTINUE
}


app_quit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    context = GLOBAL_STATE.ctx

    unload_game()
    audio_deinit()
    gui_deinit()
    video_deinit()
}

main :: proc () {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger(opt={ .Level, .Terminal_Color })
        defer log.destroy_console_logger(context.logger)

		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				log.errorf("=== %v allocations not freed ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					log.errorf("%v bytes @ %v", entry.size, entry.location)
				}
			}

			mem.tracking_allocator_destroy(&track)
		}
	}

    GLOBAL_STATE.ctx = context

    argc := i32(len(runtime.args__))
    argv := raw_data(runtime.args__)
    sdl.EnterAppMainCallbacks(argc, argv, app_init, app_iterate, app_event, app_quit);
}
