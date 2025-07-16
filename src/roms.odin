package main

import "core:log"
import fp "core:path/filepath"
import "core:os/os2"
import "core:strings"

RomEntry :: struct {
    core: string,
    name: string,
    path: string,
    category: string,
}

rom_entries_load :: proc () -> (ok: bool) {
    roms_dir_path := config_get_roms_dir_path()

    roms_dir_fd, open_err := os2.open(roms_dir_path)
    if open_err != nil {
        return false
    }
    defer os2.close(roms_dir_fd)

    roms_dir_it: os2.Read_Directory_Iterator
    os2.read_directory_iterator_init(&roms_dir_it, roms_dir_fd)
    defer os2.read_directory_iterator_destroy(&roms_dir_it)

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
        defer delete(full_core_path)

        roms_path := fp.join({ roms_dir_path, system.name })
        defer delete(roms_path)

        roms_fd, open_err := os2.open(roms_path)
        if open_err != nil {
            return false
        }
        defer os2.close(roms_fd)

        roms_it: os2.Read_Directory_Iterator
        os2.read_directory_iterator_init(&roms_it, roms_fd)
        defer os2.read_directory_iterator_destroy(&roms_it)

        for rom in os2.read_directory_iterator(&roms_it) {
            append(&GLOBAL_STATE.rom_entries, RomEntry{
                name = strings.clone(fp.stem(fp.base(rom.fullpath))),
                path = strings.clone(rom.fullpath),
                core = strings.clone(full_core_path),
            })
        }
    }

    return true
}

rom_entries_unload :: proc () {
    for entry in GLOBAL_STATE.rom_entries {
        delete(entry.core)
        delete(entry.name)
        delete(entry.path)
    }
    delete(GLOBAL_STATE.rom_entries)
}
