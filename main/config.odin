package main

import "core:path/filepath"

Config :: struct {
    cores_path: string,
    roms_path: string,
    assets_path: string,
}

config_load_default :: proc () -> Config {
    return {
        cores_path = "./cores",
        roms_path = "./roms",
        assets_path = "./assets",
    }
}
