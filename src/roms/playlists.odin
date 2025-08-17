package roms

import "core:slice"
import "core:mem"

Playlist :: struct {
    name: string,
    roms: [dynamic]PlaylistEntry,
}

PlaylistEntry :: struct {
    rom_id: RomID,
    index: u32,
    generation: u32,
}

playlists_generate_platform_playlists :: proc (platforms: []Platform, entries: RomEntries, allocator:=context.allocator) -> (res: []Playlist, err: mem.Allocator_Error) {
    playlists: map[u32]Playlist
    playlists.allocator = context.temp_allocator

    for rom, index in entries.roms {
        _, plst, _ := map_entry(&playlists, rom.platform_id) or_return

        platform := platforms[rom.platform_id]
        plst.name = platform.name
        plst.roms.allocator = allocator

        append(&plst.roms, PlaylistEntry{
            rom_id     = rom.id,
            index      = u32(index),
            generation = 0,
        })
    }

    res = make([]Playlist, len(playlists), allocator)

    i: int
    for _, v in playlists {
        res[i] = v
        i += 1
    }

    return
}

playlists_get_rom :: proc (roms: RomEntries, plst_entry: ^PlaylistEntry) -> ^RomEntry {
    if plst_entry.generation < roms.generation {
        found_index := find_rom_binary_search(roms.roms, plst_entry.rom_id)
        if found_index == -1 {
            panic("Not implemented")
        }

        plst_entry.index = u32(found_index)
        plst_entry.generation = roms.generation
    }

    return &roms.roms[plst_entry.index]
}

find_rom_binary_search :: proc (roms: []RomEntry, key: RomID) -> int {
    low := 0
    high := len(roms) - 1

    for low <= high {
        mid := (low + high) / 2
        id := roms[mid].id

        if id < key {
            low = mid + 1
        } else if id > key {
            high = mid - 1
        } else {
            return mid
        }
    }

    return -1
}
