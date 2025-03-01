package main

import "clay"
import rl "vendor:raylib"
import "core:log"

main :: proc () {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

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

    emulator_main_loop()

    emulator_quit()
}
