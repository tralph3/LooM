package main

@(private="file")
USER_STATE := struct #no_copy {
    name: string,
} {}

user_login :: proc (name: string) {
    USER_STATE.name = name
    scene_change(.MENU)
}
