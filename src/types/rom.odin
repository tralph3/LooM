package types

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
    id: u64,
    core: string,
    name: string,
    display_name: string,
    path: string,
    category: string,
    tags: bit_set[RomTag],
}

RomList :: struct {
    roms: []RomEntry,
    generation: u32,
}

PlaylistEntry :: struct {
    id: u64,
    index: u32,
    generation: u32,
}

Playlist :: struct {
    name: string,
    entries: [dynamic]PlaylistEntry,
}
