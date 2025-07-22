package main

import "core:log"
import fp "core:path/filepath"
import "core:os/os2"
import "core:strings"
import "core:testing"

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
    core: string,
    name: string,
    display_name: string,
    path: string,
    tags: bit_set[RomTag],
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

        cores_dir := config_get_cores_dir_path()

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
            clean_name, tags := rom_extract_tags_from_name(fp.stem(fp.base(rom.fullpath)))
            display_name := reorder_article_suffix(clean_name)
            append(&GLOBAL_STATE.rom_entries, RomEntry{
                display_name = display_name,
                name = strings.clone(fp.stem(fp.base(rom.fullpath))),
                path = strings.clone(rom.fullpath),
                core = strings.clone(full_core_path),
                tags = tags,
                category = strings.clone(system.name),
            })
        }
    }

    return true
}

rom_entries_unload :: proc () {
    for entry in GLOBAL_STATE.rom_entries {
        delete(entry.core)
        delete(entry.name)
        delete(entry.display_name)
        delete(entry.path)
        delete(entry.category)
    }
    delete(GLOBAL_STATE.rom_entries)
}

rom_extract_tags_from_name :: proc (name: string) -> (clean_name: string, tags: bit_set[RomTag]) {
    tag_start: int = -1
    first_tag_start : int = -1
    for char, i in name {
        if char == '(' {
            tag_start = i
        } else if tag_start != -1 &&  char == ')' {
            tags += recognize_tag(name[tag_start + 1:i])

            if tags != {} && first_tag_start == -1 {
                first_tag_start = tag_start
            }

            tag_start = -1
        } else if tag_start != -1 &&  char == ',' {
            tags += recognize_tag(name[tag_start + 1:i])

            if tags != {} && first_tag_start == -1 {
                first_tag_start = tag_start
            }

            tag_start = i
        }
    }

    if first_tag_start != -1 {
        clean_name = strings.trim(name[:first_tag_start], " ")
    } else {
        clean_name = name
    }

    return
}


@(private="file")
recognize_tag :: proc (tag_str: string) -> bit_set[RomTag] {
    tag_low := strings.to_lower(tag_str)
    defer delete(tag_low)

    switch strings.trim(tag_low, " ") {
    // Language codes
    case "en", "english":    return { .English }
    case "es", "spanish":    return { .Spanish }
    case "fr", "french":     return { .French }
    case "de", "german":     return { .German }
    case "it", "italian":    return { .Italian }
    case "pt", "portuguese": return { .Portuguese }
    case "ru", "russian":    return { .Russian }
    case "zh", "chinese":    return { .Chinese }
    case "ja", "japanese":   return { .Japanese }
    case "ko", "korean":     return { .Korean }
    case "hi", "hindi":      return { .Hindi }
    case "nl", "dutch":      return { .Dutch }
    case "sv", "swedish":    return { .Swedish }
    case "fi", "finnish":    return { .Finnish }
    case "da", "danish":     return { .Danish }
    case "tr", "turkish":    return { .Turkish }
    case "pl", "polish":     return { .Polish }
    case "af", "afrikaans":  return { .Afrikaans }

    // Country/region codes and names
    case "us", "usa", "united states", "america": return { .USA }
    case "eu", "europe": return { .Europe }
    case "asia": return { .Asia }
    case "can", "canada": return { .Canada }
    case "mex", "mexico": return { .Mexico }
    case "bra", "brazil": return { .Brazil }
    case "arg", "argentina": return { .Argentina }
    case "gb", "gbr", "united kingdom", "england", "britain": return { .UK }
    case "deu", "germany": return { .Germany }
    case "fra", "france": return { .France }
    case "ita", "italy": return { .Italy }
    case "esp", "spain": return { .Spain }
    case "rus", "russia": return { .Russia }
    case "chn", "china": return { .China }
    case "jpn", "japan": return { .Japan }
    case "kor", "south korea", "korea": return { .SouthKorea }
    case "ind", "india": return { .India }
    case "aus", "australia": return { .Australia }
    case "nld", "netherlands", "holland": return { .Netherlands }
    case "swe", "sweden": return { .Sweden }
    case "che", "switzerland": return { .Switzerland }
    case "tur", "turkey": return { .Turkey }
    case "pol", "poland": return { .Poland }
    case "zaf", "south africa": return { .SouthAfrica }
    case "world": return { .World }

    // Meta
    case "unl", "unl.", "unlicensed": return { .Unlicensed }
    case "demo", "sample": return { .Demo }
    case "proto", "prototype": return { .Prototype }
    case "beta": return { .Beta }
    }

    return {}
}

@(private="file")
// transform e.g. "Legend of Zelda, The" to "The Legend of Zelda"
reorder_article_suffix :: proc (str: string, allocator:=context.allocator) -> string {
    split := strings.split(str, " - ", context.temp_allocator)

    cut_index: int = -1
    space_encountered := false
    #reverse for char, i in split[0] {
        if strings.is_space(char) {
            if space_encountered {
                return strings.clone(str, allocator)
            } else {
                space_encountered = true
            }
        } else if char == ',' {
            if space_encountered {
                cut_index = i
                break
            } else {
                return strings.clone(str, allocator)
            }
        } else if space_encountered {
            return strings.clone(str, allocator)
        }
    }

    if cut_index == -1 {
        return strings.clone(str, allocator)
    }

    rest := split[0][:cut_index]
    article := split[0][cut_index + 2:]

    // extra byte for the space between the article and the rest
    res_size := len(rest) + len(article) + 1
    res := make([]byte, res_size, context.temp_allocator)

    for b, i in res {
        if i < len(article) {
            res[i] = article[i]
        } else if i == len(article) {
            res[i] = ' '
        } else {
            res[i] = rest[i - len(article) - 1]
        }
    }

    fixed := strings.string_from_ptr(raw_data(res), res_size)
    split[0] = fixed
    return strings.join(split, " - ", allocator)
}

@(test)
test_reorder_article_suffix :: proc(t: ^testing.T) {
    cases := []struct{
        input: string,
        expected: string,
    } {
        {"Legend of Zelda, The", "The Legend of Zelda"},
        {"Super Mario Bros, A", "A Super Mario Bros"},
        {"Chrono Trigger", "Chrono Trigger"},
        {"Mario, Super", "Super Mario"},
        {"Mario,Super", "Mario,Super"}, // no space after comma
        {"Mario , Super", "Super Mario "}, // space before comma
        {"Mario,  The", "Mario,  The"}, // double space after comma
        {", The", "The "},
        {" , The", "The  "},
        {"The", "The"},
        {"", ""},
        {"Rayman, L'", "L' Rayman"},
        // Not an article (contains space)
        {"Rayman, The Best", "Rayman, The Best"},
        {"Rayman, Le Grand", "Rayman, Le Grand"},
        // Comma in the middle of the title, not an article
        {"Mario, Luigi, The", "The Mario, Luigi"},
        {"Mario, Luigi, The, The", "The Mario, Luigi, The"}, // Only last is reordered
        // Edge cases
        {", A", "A "},
        {",", ","},
        {", ", " "},
        {",", ","},
        {" ,", " ,"},
        {" , ", "  "},
        {" , A", "A  "},
        {"A, The", "The A"},
        {"A,", "A,"},
        {"A, ", " A"},
        {"A,The", "A,The"},
        {"A, The Best", "A, The Best"},
        {"Compound, A - Title, The", "A Compound - Title, The"},
    }

    for c in cases {
        res := reorder_article_suffix(c.input, context.temp_allocator)
        testing.expect_value(t, res, c.expected)
    }
}

@(test)
test_rom_extract_tags_from_name :: proc(t: ^testing.T) {
    cases := []struct{
        input: string,
        expected_clean: string,
        expected_tags: bit_set[RomTag],
    } {
        {"Super Mario Bros", "Super Mario Bros", {}},
        {"Super Mario Bros (USA)", "Super Mario Bros", { .USA }},
        {"Super Mario Bros (USA, Demo)", "Super Mario Bros", { .USA, .Demo }},
        {"Super (USA) Mario Bros", "Super", { .USA }},
        {"Game Title (Special Edition) (Japan)", "Game Title (Special Edition)", { .Japan }},
        {"Game Title (Special Edition) (Japan, Demo)", "Game Title (Special Edition)", { .Japan, .Demo }},
        {"(USA, Demo)", "", { .USA, .Demo }},
        {"Game (  usa  ,  demo  )", "Game", { .USA, .Demo }},
        {"Game (EN)", "Game", { .English }},
        {"Game (FR)", "Game", { .French }},
        {"Game (EN, JA, USA)", "Game", { .English, .Japanese, .USA }},
        {"Game (Special)", "Game (Special)", {}},
        {"Game (Unl)", "Game", { .Unlicensed }},
        {"Game (Special Edition)", "Game (Special Edition)", {}},
        {"Game (Special) (USA)", "Game (Special)", { .USA }},
        {"Game (Special) (USA) (Demo)", "Game (Special)", { .USA, .Demo }},
        {"Game (USA,  Demo,  EN)", "Game", { .USA, .Demo, .English }},
    }

    for c in cases {
        clean, tags := rom_extract_tags_from_name(c.input)
        testing.expect_value(t, clean, c.expected_clean)
        testing.expect_value(t, tags, c.expected_tags)
    }
}
