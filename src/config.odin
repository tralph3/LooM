package main

import "core:encoding/ini"
import "core:log"
import fp "core:path/filepath"
import "core:os/os2"
import "core:strings"
import t "loom:types"

CONFIG_HEADER :: "; All paths, unless absolute, are relative to the LooM executable\n\n"

CONFIG := struct #no_copy {
    config_path: string,

    cores_path: string,
    roms_path: string,
    users_path: string,

    //TEMP DELETETETETETETE
    system_path: string,

    users: map[string]t.UserConfig,

    systems: map[string]t.SystemConfig,
} {
    //TEMP DELETETETETETETE
    system_path = "./system",
}

config_init :: proc () -> (ok: bool) {
    config_set_default()

    if !os2.exists(CONFIG.config_path) {
        config_create_default() or_return
    }

    config_load_from_disk() or_return


    sys_fd, open_err := os2.open("./config/systems")
    if open_err != nil {
        return false
    }
    defer os2.close(sys_fd)

    it: os2.Read_Directory_Iterator
    os2.read_directory_iterator_init(&it, sys_fd)
    defer os2.read_directory_iterator_destroy(&it)

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

    return true
}

config_deinit :: proc () {
    delete(CONFIG.cores_path)
    delete(CONFIG.roms_path)
    delete(CONFIG.config_path)
    delete(CONFIG.users_path)

    for sys_identifier, system in CONFIG.systems {
        delete(sys_identifier)

        delete(system.core)
        delete(system.name)
    }

    delete(CONFIG.systems)
}

config_set_default :: proc () {
    CONFIG.config_path = strings.clone("./config/loom.ini")

    // these default values will be overriden by those found in the
    // config file, or alternatively, used to construct the default
    // config file initially
    CONFIG.cores_path = "./cores"
    CONFIG.roms_path = "./roms"
    CONFIG.users_path = "./config/users"
}

config_create_default :: proc () -> (ok: bool) {
    config_dir := fp.dir(CONFIG.config_path)
    defer delete(config_dir)

    if !os2.exists(config_dir) {
        if err := os2.make_directory_all(config_dir); err != nil {
            return false
        }
    }

    config_write_to_disk() or_return

    return true
}

config_load_from_disk :: proc () -> (ok: bool) {
    conf, err, ok_load := ini.load_map_from_path(CONFIG.config_path, context.temp_allocator)
    if err != nil || !ok_load {
        return false
    }

    loom := conf["loom"] or_else {}

    CONFIG.cores_path = loom["cores_path"] or_else "./cores"
    CONFIG.cores_path = strings.clone(CONFIG.cores_path)

    CONFIG.roms_path = loom["roms_path"] or_else "./roms"
    CONFIG.roms_path = strings.clone(CONFIG.roms_path)

    CONFIG.users_path = loom["users_path"] or_else "./users"
    CONFIG.users_path = strings.clone(CONFIG.users_path)

    return true
}

config_write_to_disk :: proc () -> (ok: bool) {
    conf: ini.Map
    defer ini.delete_map(conf)

    conf[strings.clone("loom")] = {}
    loom := &conf["loom"]
    loom[strings.clone("cores_path")] = strings.clone(CONFIG.cores_path)
    loom[strings.clone("roms_path")] = strings.clone(CONFIG.roms_path)
    loom[strings.clone("users_path")] = strings.clone(CONFIG.users_path)

    str := ini.save_map_to_string(conf, context.temp_allocator)

    fd, err := os2.create(CONFIG.config_path)
    if err != nil {
        return false
    }
    defer os2.close(fd)

    _, err = os2.write_string(fd, CONFIG_HEADER)
    if err != nil {
        return false
    }

    _, err = os2.write_string(fd, str)
    if err != nil {
        return false
    }

    return true
}

config_get_roms_dir_path :: proc () -> string {
    return CONFIG.roms_path
}

config_get_cores_dir_path :: proc () -> string {
    return CONFIG.cores_path
}

config_get_saves_dir_path :: proc () -> string {
    user := user_get_current()
    return CONFIG.users[user].saves_path
}

config_get_system_dir_path :: proc () -> string {
    return CONFIG.system_path
    // user := user_get_current()
    // return CONFIG.users[user].system_path
}

config_get_system_config :: proc (system: string) -> ^t.SystemConfig {
    return &CONFIG.systems[system] or_else nil
}
