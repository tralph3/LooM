#+feature dynamic-literals
package main

import rl "vendor:raylib"
import "core:log"

VALID_STATE_CHANGES: map[PossibleStates][]PossibleStates = {
    .LOGIN = { .MENU },
    .MENU = { .RUNNING, .LOGIN },
    .RUNNING = { .PAUSED, .MENU },
    .PAUSED = { .MENU, .RUNNING },
}

quit :: proc () {
    unload_core()

    rl.CloseWindow()
}

is_valid_state_change :: proc (from, to: PossibleStates) -> bool {
    for i in VALID_STATE_CHANGES[from] {
        if i == to { return true }
    }

    return false
}

change_state :: proc (new_state: PossibleStates, location := #caller_location) {
    if !is_valid_state_change(STATE.state, new_state) {
        log.errorf(
            "Attempting invalid state change in %s. From %s to %s",
            location, STATE.state, new_state)
        return
    }

    STATE.state = new_state
}
