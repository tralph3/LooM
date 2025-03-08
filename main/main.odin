package main

import "clay"
import rl "vendor:raylib"
import "core:log"
import "core:mem"

track :: proc(code: proc()) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	GLOBAL_CONTEXT.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			log.errorf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				log.errorf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			log.errorf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				log.errorf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		log.errorf("Peak memory allocated: %v\n", track.peak_memory_allocated)
		mem.tracking_allocator_destroy(&track)
	}

	code()
}

init :: proc () {
    ok_init_renderer := init_raylib()
    if !ok_init_renderer {
        log.panic("Failed initializing renderer")
    } else {
        log.debug("Successfully initialized renderer")
    }

    ok_init_clay := init_clay()
    if !ok_init_clay {
        log.panic("Failed initializing UI")
    } else {
        log.debug("Successfully initialized UI")
    }

    change_state(.LOGIN)

    main_loop()

    quit()
}

main :: proc () {
    GLOBAL_CONTEXT.logger = log.create_console_logger()
    defer log.destroy_console_logger(GLOBAL_CONTEXT.logger)
    context = GLOBAL_CONTEXT

    init()
}
