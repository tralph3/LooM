package main

import "core:os/os2"
import "core:strings"
import "core:log"
import sdl "vendor:sdl3"
import pt "core:path/filepath"

GameEntry :: struct {
    core: string,
    name: string,
    path: string,
}

game_entries_load :: proc (allocator:=context.allocator) {
    // log.info("Generating game entries...")

    // core_path_cstr := strings.clone_to_cstring(GLOBAL_STATE.config.cores_path, allocator=allocator)
    // defer delete(core_path_cstr)

    // count: i32
    // cores := sdl.GlobDirectory(core_path_cstr, "*.so", { .CASEINSENSITIVE }, &count)

    // for i in 0..<count {
    //     core_path := cores[i]
    //     full_core_path := pt.join({ string(core_path_cstr), string(cstring(core_path)) }, allocator=allocator)

    //     core := core_load(full_core_path) or_continue
    //     defer core_unload(&core)

    //     extensions := core_get_valid_extensions(&core)
    //     defer delete(extensions)

    //     for ext in extensions {
    //         pattern := strings.concatenate({"*.", ext}, allocator=allocator)
    //         defer delete(pattern)

    //         pattern_cstr := strings.clone_to_cstring(pattern)
    //         defer delete(pattern_cstr)

    //         rom_path_cstr := strings.clone_to_cstring(GLOBAL_STATE.config.roms_path, allocator=allocator)
    //         defer delete(rom_path_cstr)

    //         rom_count: i32
    //         roms := sdl.GlobDirectory(rom_path_cstr, pattern_cstr, { .CASEINSENSITIVE }, &rom_count)

    //         for j in 0..<rom_count {
    //             rom_path := roms[j]
    //             full_rom_path := pt.join({ string(rom_path_cstr), string(cstring(rom_path)) }, allocator=allocator)

    //             append(&GLOBAL_STATE.game_entries, GameEntry{
    //                 core = full_core_path,
    //                 path = full_rom_path,
    //             })
    //         }
    //     }
    // }

    // for entry in GLOBAL_STATE.game_entries {
    //     log.info(entry)
    // }

    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/b2_libretro.so", path="./roms/Legend of Zelda, The (U) (PRG1) [!].nes"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/mesen_libretro.so", path="./roms/Legend of Zelda, The (U) (PRG1) [!].nes"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/mesen_libretro.so", path="./roms/Super Mario Bros. (Europe) (Rev A).nes"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/bsnes_libretro.so", path="./roms/Super Castlevania IV (USA).sfc"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/bsnes_libretro.so", path="./roms/Donkey Kong Country (USA).sfc"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/bsnes_libretro_debug.so", path="./roms/Super Mario World 2 - Yoshi's Island (USA) (Rev-A).sfc"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/bsnes_libretro_debug.so", path="./roms/Final Fantasy III (USA) (Rev 1).sfc"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/desmume_libretro_debug.so", path="./roms/Mario Kart DS (USA) (En,Fr,De,Es,It).nds"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/melondsds_libretro.so", path="./roms/Mario Kart DS (USA) (En,Fr,De,Es,It).nds"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/mupen64plus_next_libretro_debug.so", path="./roms/Super Mario 64 (U) [!].z64"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/mupen64plus_next_libretro.so", path="./roms/Doshin the Giant (J) [64DD].n64"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/parallel_n64_libretro.so", path="./roms/Super Mario 64 (U) [!].z64"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/gambatte_libretro.so", path="./roms/Donkey Kong Country (UE).gbc"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/mednafen_psx_hw_libretro.so", path="./roms/Silent Hill (USA).cue"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/swanstation_libretro.so", path="./roms/Final Fantasy VII (Spain) (Disc 1) (Rev 1).cue"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/swanstation_libretro.so", path="./roms/padtest.cue"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/azahar_libretro.so", path="./roms/Tetris Ultimate (USA) (En,Fr,Es,Pt).3ds"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/dosbox_pure_libretro.so", path="/home/tralph3/Downloads/tomb3dem.zip"})
    append(&GLOBAL_STATE.game_entries, GameEntry{core="./cores/pcsx2_libretro.so", path="./roms/SAN_ANDREAS.ISO"})
}

game_entries_unload :: proc () {
    delete(GLOBAL_STATE.game_entries)
}
