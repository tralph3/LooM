package types

import "core:mem"
import "loom:rdb"

RomList :: struct {
    roms: []RomEntry,
    generation: u32,
}

PlaylistEntry :: struct {
    id: u32,
    index: u32,
    generation: u32,
}

RomID :: distinct u64

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
    roms: []RomEntry,
    playlists: []Playlist,
    __allocator: mem.Allocator,
}

Playlist :: struct {
    name: string,
    roms: [dynamic]RomID,
}

Platform :: struct {
    name: string,
    db: rdb.Database,
}
