package main

import "core:path/filepath"

// TODO: temp solution
users := []string {
    "tralph3",
    "xXx__slayer__xXx",
    "takenUser420",
}

Config :: struct {
    cores_path: string,
    roms_path: string,
    assets_path: string,
    config_path: string,
    users: []string,
}

config_load_default :: proc () -> Config {
    return {
        cores_path = "./cores",
        roms_path = "./roms",
        assets_path = "./assets",
        config_path = "./config.toml",
        users = users,
    }
}
