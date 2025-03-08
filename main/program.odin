#+feature dynamic-literals
package main

import rl "vendor:raylib"
import "core:log"

VALID_STATE_CHANGES: map[States][]States = {
    .LOGIN = { .MENU },
    .MENU = { .RUNNING, .LOGIN },
    .RUNNING = { .PAUSED, .MENU },
    .PAUSED = { .MENU, .RUNNING },
}

quit :: proc () {
    unload_core()
}

is_valid_state_change :: proc (from, to: States) -> bool {
    for i in VALID_STATE_CHANGES[from] {
        if i == to { return true }
    }

    return false
}

change_state :: proc (new_state: States, location := #caller_location) {
    if !is_valid_state_change(STATE.state, new_state) {
        log.errorf(
            "Attempting invalid state change in %s. From %s to %s",
            location, STATE.state, new_state)
        return
    }

    STATE.state = new_state
}

login_with_user :: proc (username: string) {
    log.infof("User '%s' logging in...", username)

    STATE.current_user = username

    change_state(.MENU)
}

logout :: proc () {
    log.infof("User '%s' logging out...", STATE.current_user)

    STATE.current_user = ""

    change_state(.LOGIN)
}
