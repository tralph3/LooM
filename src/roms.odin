package main

import "core:log"
import fp "core:path/filepath"
import "core:os/os2"
import "core:strings"

RomEntry :: struct {
    core: string,
    name: string,
    path: string,
}

rom_entries_load :: proc () -> (err: os2.Error) {
    roms_dir_path := config_get_roms_dir_path()

    roms_dir_fd := os2.open(roms_dir_path) or_return
    defer os2.close(roms_dir_fd)

    roms_dir_it: os2.Read_Directory_Iterator
    os2.read_directory_iterator_init(&roms_dir_it, roms_dir_fd)

    for system in os2.read_directory_iterator(&roms_dir_it) {
        core_conf := config_get_system_config(system.name)
        if core_conf == nil { continue }

        cores_dir := config_get_core_dir_path()

        ext: string
        when ODIN_OS == .Windows {
            ext = ".dll"
        } else when ODIN_OS == .Darwin {
            ext = ".dylib"
        } else {
            ext = ".so"
        }

        core_file := strings.concatenate({ core_conf.core, ext })
        defer delete(core_file)

        rel_core_path := fp.join({ cores_dir, core_file })
        defer delete(rel_core_path)

        full_core_path, _ := fp.abs(rel_core_path)

        roms_path := fp.join({ roms_dir_path, system.name })
        defer delete(roms_path)

        roms_fd := os2.open(roms_path) or_return
        defer os2.close(roms_fd)

        roms_it: os2.Read_Directory_Iterator
        os2.read_directory_iterator_init(&roms_it, roms_fd)

        for rom in os2.read_directory_iterator(&roms_it) {
            append(&GLOBAL_STATE.rom_entries, RomEntry{
                path = strings.clone(rom.fullpath),
                core = full_core_path,
            })
        }
    }

    return nil
}

rom_entries_unload :: proc () {
    delete(GLOBAL_STATE.rom_entries)
}
