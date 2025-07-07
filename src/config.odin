package main

import "core:encoding/ini"
import "core:log"
import fp "core:path/filepath"
import "core:os/os2"
import "core:strings"

CONFIG := struct #no_copy {
    cores_path: string,
    roms_path: string,

    systems: map[string]SystemConfig,
} {}

SystemConfig :: struct {
    name: string,
    core: string,
}

config_init :: proc () -> (err: os2.Error) {
    CONFIG.cores_path = strings.clone("./cores")
    CONFIG.roms_path = strings.clone("./roms")

    sys_fd := os2.open("./config/systems") or_return
    defer os2.close(sys_fd)

    it: os2.Read_Directory_Iterator
    os2.read_directory_iterator_init(&it, sys_fd)

    for system in os2.read_directory_iterator(&it) {
        m, err, ok := ini.load_map_from_path(system.fullpath, allocator=context.allocator)
        defer ini.delete_map(m)

        if err != nil {
            log.errorf("Allocation error: {}", err)
            continue
        }

        if !ok {
            continue
        }

        sys_identifier := strings.clone(fp.stem(system.name))

        sys_name := m[""]["name"] or_else "Unknown"
        sys_core := m[""]["core"] or_else ""

        CONFIG.systems[sys_identifier] = {
            name = strings.clone(sys_name),
            core = strings.clone(sys_core),
        }
    }

    return nil
}

config_deinit :: proc () {
    delete(CONFIG.cores_path)
    delete(CONFIG.roms_path)

    for sys_identifier, system in CONFIG.systems {
        delete(sys_identifier)

        delete(system.core)
        delete(system.name)
    }

    delete(CONFIG.systems)
}

config_get_roms_dir_path :: proc () -> string {
    return CONFIG.roms_path
}

config_get_core_dir_path :: proc () -> string {
    return CONFIG.cores_path
}

config_get_system_config :: proc (system: string) -> ^SystemConfig {
    return &CONFIG.systems[system] or_else nil
}
