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
    fps := emulator_get_fps()

    frame_duration_ns := u64((1.0 / fps) * 1_000_000_000.0)
    elapsed_ns := sdl.GetTicksNS() - last_time_ns

    if elapsed_ns >= frame_duration_ns {
        return
    }

    remaining_ns := frame_duration_ns - elapsed_ns
    sdl.DelayPrecise(remaining_ns)
}

app_init :: proc "c" (appstate: ^rawptr, argc: c.int, argv: [^]cstring) -> sdl.AppResult {
    context = state_get_context()

    config_init()
    game_entries_load()

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

    if !input_init() {
        log.error("Failed initializing input")
        return .FAILURE
    }

    GLOBAL_STATE.event_offset = sdl.RegisterEvents(len(Event))
    if GLOBAL_STATE.event_offset == 0 {
        log.error("Failed registering user events: {}", sdl.GetError())
        return .FAILURE
    }

    scene_init()

    return .CONTINUE
}

@(private="file")
last_time: u64

app_iterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    context = state_get_context()
    defer free_all(GLOBAL_STATE.ctx.temp_allocator)

    wait_until_next_frame(last_time)

    GLOBAL_STATE.delta_time = f32(sdl.GetTicksNS() - last_time) / 1_000_000_000.0
    last_time = sdl.GetTicksNS()

    gui_update()

    scene := scene_get(GLOBAL_STATE.current_scene_id)
    scene.update()
    scene.render()

    video_swap_window()

    GLOBAL_STATE.frame_counter += 1

    input_reset()

    return .CONTINUE
}

app_event :: proc "c" (appstate: rawptr, event: ^sdl.Event) -> sdl.AppResult {
    context = GLOBAL_STATE.ctx

    #partial switch event.type {
    case .QUIT:
        return .SUCCESS
    case .MOUSE_WHEEL, .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP, .MOUSE_MOTION:
        input_handle_mouse(event)
    case .GAMEPAD_ADDED, .GAMEPAD_REMOVED:
        input_open_gamepads()
    case .GAMEPAD_BUTTON_DOWN, .GAMEPAD_AXIS_MOTION:
        input_handle_gamepad_pressed(event)
    case .KEY_DOWN:
        input_handle_key_pressed(event)
        input_update_emulator_keyboard_state(event)
    case .KEY_UP:
        input_update_emulator_keyboard_state(event)
    case .WINDOW_RESIZED:
        video_handle_window_resize(event)
    case event_to_sdl_event(.SaveState):
        emulator_save_state()
        scene_change(.RUNNING)
    case event_to_sdl_event(.LoadState):
        emulator_load_state()
        scene_change(.RUNNING)
    }

    return .CONTINUE
}


app_quit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    context = state_get_context()

    game_entries_unload()
    emulator_close()
    input_deinit()
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
