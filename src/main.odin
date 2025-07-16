#+private file
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

// cross function defer
DEINIT_PROCS: [dynamic]proc ()

last_time: u64

init_subsystem :: proc (name: string, init: proc () -> bool, deinit: proc ()) -> (ok: bool) {
    if !init() {
        log.errorf("Failed initializing '{}'", name)
        return false
    }
    if deinit != nil {
        append(&DEINIT_PROCS, deinit)
    }

    return true
}

wait_until_next_frame :: #force_inline proc(last_time_ns: u64) {
    fps := emulator_get_fps()

    frame_duration_ns := u64((1.0 / fps) * 1_000_000_000.0)
    elapsed_ns := sdl.GetTicksNS() - last_time_ns

    if elapsed_ns >= frame_duration_ns {
        return
    }

    remaining_ns := frame_duration_ns - elapsed_ns
    sdl.DelayPrecise(remaining_ns + audio_should_sleep_for())
}

app_init :: proc "c" (appstate: ^rawptr, argc: c.int, argv: [^]cstring) -> (res: sdl.AppResult) {
    context = state_get_context()

    res = .FAILURE

    GLOBAL_STATE.event_offset = sdl.RegisterEvents(len(Event))
    if GLOBAL_STATE.event_offset == 0 {
        log.error("Failed registering user events: {}", sdl.GetError())
        return
    }

    append(&DEINIT_PROCS, emulator_close)

    if !init_subsystem("Thread Pool", thread_pool_init, thread_pool_deinit) { return }
    if !init_subsystem("Config", config_init, config_deinit) { return }
    if !init_subsystem("Roms", rom_entries_load, rom_entries_unload) { return }
    if !init_subsystem("Video", video_init, video_deinit) { return }
    if !init_subsystem("GUI", gui_init, gui_deinit) { return }
    if !init_subsystem("Audio", audio_init, audio_deinit) { return }
    if !init_subsystem("Input", input_init, input_deinit) { return }
    if !init_subsystem("Scene", scene_init, nil) { return }
    // we can run without assets we don't exit on failure
    init_subsystem("Assets", assets_init, assets_deinit)
    init_subsystem("Covers", covers_init, covers_deinit)

    return .CONTINUE
}

app_iterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    context = state_get_context()
    defer free_all(context.temp_allocator)

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

    #reverse for func in DEINIT_PROCS {
        func()
    }

    sdl.ClearError()

    delete(DEINIT_PROCS)
    free_all(context.temp_allocator)
}

@(private="package")
main :: proc () {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger(opt={ .Level, .Terminal_Color })
        defer log.destroy_console_logger(context.logger)

		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		defer mem.tracking_allocator_destroy(&track)

        track_temp: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track_temp, context.temp_allocator)
        defer mem.tracking_allocator_destroy(&track_temp)

        compat: mem.Compat_Allocator
        mem.compat_allocator_init(&compat, mem.tracking_allocator(&track))

		context.allocator = mem.compat_allocator(&compat)
        context.temp_allocator = mem.tracking_allocator(&track_temp)

        print_leaked_allocations :: proc (track: ^mem.Tracking_Allocator) {
            if len(track.allocation_map) > 0 {
				log.errorf("=== %v allocations not freed ===\n", len(track.allocation_map))
                total: int
				for _, entry in track.allocation_map {
                    total += entry.size
					log.errorf("%v bytes @ %v", entry.size, entry.location)
				}

                log.errorf("Total memory leaked: {} bytes", total)
			}
        }

		defer {
            print_leaked_allocations(&track)
            print_leaked_allocations(&track_temp)
		}

        sdl.SetMemoryFunctions(
            malloc_func = proc "c" (size: uint) -> rawptr {
                context = state_get_context()

                if res, err := mem.alloc_bytes_non_zeroed(int(size)); err != nil {
                    log.errorf("Failed allocating memory: {}", err)
                    return nil
                } else {
                    return raw_data(res)
                }
            },
            calloc_func = proc "c" (nmemb: uint, size: uint) -> rawptr {
                context = state_get_context()

                if res, err := mem.alloc(int(nmemb * size)); err != nil {
                    log.errorf("Failed allocating memory: {}", err)
                    return nil
                } else {
                    return res
                }
            },
            realloc_func = proc "c" (ptr: rawptr, size: uint) -> rawptr {
                context = state_get_context()

                if res, err := mem.resize_non_zeroed(ptr, -1, int(size)); err != nil {
                    log.errorf("Failed allocating memory: {}", err)
                    return nil
                } else {
                    return res
                }
            },
            free_func = proc "c" (mem: rawptr) {
                context = state_get_context()
                free(mem)
            },
        )
        err := sdl.GetError()
        if err != "" {
            log.fatalf("Failed setting memory functions: {}", err)
            return
        }
	}

    GLOBAL_STATE.ctx = context

    argc := i32(len(runtime.args__))
    argv := raw_data(runtime.args__)
    sdl.EnterAppMainCallbacks(argc, argv, app_init, app_iterate, app_event, app_quit)
}
