package main

import rl "vendor:raylib"

quit :: proc () {
    unload_core()

    delete(STATE.clay_arena.memory[:STATE.clay_arena.capacity])

    rl.CloseWindow()
}
