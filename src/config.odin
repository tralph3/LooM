package main

Config :: struct #no_copy {
    cores_path: string,
    roms_path: string,
}

config_init :: proc () {
    GLOBAL_STATE.config.cores_path = "./cores"
    GLOBAL_STATE.config.roms_path = "./roms"
}
