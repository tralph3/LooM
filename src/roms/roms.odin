package roms

import "core:os/os2"
import "core:strings"
import fp "core:path/filepath"
import "core:testing"
import "core:slice"
import "loom:utils"
import "core:mem"
import "core:log"
import "loom:rdb"
import "loom:allocators"

RomID :: distinct u64

RomEntries :: struct {
    roms: []RomEntry,
    generation: u32,
}

RomTag :: enum {
    // Regions/Countries
    USA,
    Europe,
    Asia,
    Canada,
    Mexico,
    Brazil,
    Argentina,
    UK,
    Germany,
    France,
    Italy,
    Spain,
    Russia,
    China,
    Japan,
    SouthKorea,
    India,
    Australia,
    Netherlands,
    Sweden,
    Switzerland,
    Turkey,
    Poland,
    SouthAfrica,
    World,

    // Languages
    English,
    Spanish,
    French,
    German,
    Italian,
    Portuguese,
    Russian,
    Chinese,
    Japanese,
    Korean,
    Hindi,
    Dutch,
    Swedish,
    Finnish,
    Danish,
    Turkish,
    Polish,
    Afrikaans,

    // Meta
    Demo,
    Unlicensed,
    Prototype,
    Beta,
}

RomEntry :: struct {
    id: RomID,
    path: string,
    database_name: string,
    display_name: string,
    platform_id: u32,
    tags: bit_set[RomTag],
}

Roms :: struct {
    roms: RomEntries,
    platforms: []Platform,
    playlists: []Playlist,
    __dyn_arena_allocator: allocators.DynamicArena,
}

roms_load :: proc (roms_path: string, database_path: string, backing_allocator:=context.allocator) -> (roms: Roms) {
    dynamic_arena: allocators.DynamicArena
    // TODO: revise the block size if we eventually switch to indexed
    // databases
    allocators.dynamic_arena_init(&dynamic_arena, block_size=128 * mem.Megabyte, block_allocator=backing_allocator)

    roms.__dyn_arena_allocator = dynamic_arena
    context.allocator = allocators.dynamic_arena_allocator(&dynamic_arena)

    platforms, err := platforms_read_all(database_path)
    if err != nil {
        log.error(err)
        return
    }

    rom_entries, scan_err := scan_directory(roms_path, platforms)
    if scan_err != nil {
        log.error(scan_err)
        return
    }
    slice.sort_by_key(rom_entries.roms, proc (e: RomEntry) -> RomID {
        return e.id
    })

    plsts, plst_err := playlists_generate_platform_playlists(platforms, rom_entries)
    if plst_err != nil {
        log.error(plst_err)
        return
    }

    roms.roms = rom_entries
    roms.playlists = plsts
    roms.platforms = platforms

    return
}

roms_unload :: proc (roms: ^Roms) {
    allocators.dynamic_arena_destroy(&roms.__dyn_arena_allocator)
}

main :: proc () {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    rs := roms_load("../roms", "../database")
    log.info(rs.playlists)
    if len(rs.roms.roms) > 0 {
        log.infof("LENGTH: {}", len(rs.roms.roms))
        for r in rs.roms.roms[:8] {
            log.info(r)
        }
    }

    roms_unload(&rs)
}
