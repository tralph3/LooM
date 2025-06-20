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

    if remaining_ns > 500_000 {
        sdl.DelayNS(remaining_ns - 500_000)
    }

    target_ns := last_time_ns + frame_duration_ns
    for sdl.GetTicksNS() < target_ns {
        // active wait
    }
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

    if !renderer_init() {
        log.error("Failed initializing renderer")
        return
    }
    defer renderer_deinit()

    //renderer_load_font("./assets/Ubuntu.ttf", 16)

    if !gui_init() {
        log.error("Failed initializing GUI")
        return
    }
    defer gui_deinit()

    if !audio_init() {
        log.error("Failed initializing audio")
        return
    }
    defer audio_deinit()

    //load_game("./cores/fceumm_libretro.so", "./roms/Legend of Zelda, The (U) (PRG1) [!].nes")
    //load_game("./cores/bsnes_libretro_debug.so", "./roms/Super Castlevania IV (USA).sfc")
    //load_game("./cores/bsnes_libretro_debug.so", "./roms/Final Fantasy III (USA) (Rev 1).sfc")
    //load_game("./cores/desmume_libretro.so", "./roms/Mario Kart DS (USA) (En,Fr,De,Es,It).nds")
    //load_game("./cores/desmume_libretro_debug.so", "./roms/Mario Kart DS (USA) (En,Fr,De,Es,It).nds")
    defer unload_game()

    t: f32
    for !GLOBAL_STATE.should_exit {
        last_time := sdl.GetTicksNS()

        GLOBAL_STATE.input_state.mouse_wheel_y = 0
        sdl_events_handle()

        gui_update()

        r := (math.sin(t) + 1.0) * 0.5
        g := (math.sin(t + 2.0) + 1.0) * 0.5
        b := (math.sin(t + 4.0) + 1.0) * 0.5

        scene := scene_get(GLOBAL_STATE.current_scene_id)

        scene.update()

        window_x: i32
        window_y: i32
        sdl.GetWindowSize(GLOBAL_STATE.video_state.window, &window_x, &window_y)

        gl.BindFramebuffer(gl.READ_FRAMEBUFFER, fbo_id)
        gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)
        gl.BlitFramebuffer(
            0, i32(GLOBAL_STATE.emulator_state.av_info.geometry.base_height), i32(GLOBAL_STATE.emulator_state.av_info.geometry.base_width), 0,
            0, 0, window_x, window_y,
            gl.COLOR_BUFFER_BIT, gl.NEAREST
        )
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

        //scene.render()

        sdl.GL_SwapWindow(GLOBAL_STATE.video_state.window)
        wait_until_next_frame(last_time)
    }
}
