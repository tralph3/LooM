package main

UserState :: struct #no_copy {
    name: string,
}

user_login :: proc (name: string) {
    GLOBAL_STATE.user_state.name = name
    scene_change(.MENU)
}
