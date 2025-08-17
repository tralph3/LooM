package roms

import fp "core:path/filepath"
import "core:os/os2"
import "core:slice"
import "core:hash"
import "core:mem"
import "loom:utils"
import "core:strings"
import "core:log"

ScanError :: union {
    os2.Error,
}

scan_directory :: proc (path: string, platforms: []Platform, allocator:=context.allocator) -> (res: RomEntries, err: ScanError) {
    roms: [dynamic]RomEntry
    roms.allocator = allocator

    fd := os2.open(path) or_return
    defer os2.close(fd)

    it := os2.read_directory_iterator_create(fd)
    defer os2.read_directory_iterator_destroy(&it)

    buf := make([]byte, 64 * mem.Megabyte, context.temp_allocator)

    for rom in os2.read_directory_iterator(&it) {
        if rom.type == .Directory {
            r := scan_directory(rom.fullpath, platforms, allocator) or_return
            append(&roms, ..r.roms)
            continue
        }

        if rom.type != .Regular { continue }
        if rom.size == 0 { continue }

        fd := os2.open(rom.fullpath) or_return
        defer os2.close(fd)

        n := os2.read(fd, buf) or_return
        hash := hash.crc32(buf[:n])

        rom_entry, ok := scan_rom(strings.clone(rom.fullpath, allocator), hash, platforms)
        if !ok { continue }

        append(&roms, rom_entry)
    }

    return {
        roms = roms[:],
        generation = 0,
    }, nil
}

scan_rom :: proc (path: string, hash: u32, platforms: []Platform) -> (rom: RomEntry, ok: bool) {
    for platform, index in platforms {
        rom_db_entry, found := platform.db[hash]
        if !found { continue }

        name, ok := rom_db_entry["name"].(string)
        if !ok {
            log.warnf("Rom did not have name: {}: {}", path, rom_db_entry)
            return
        }
        rom.id = auto_cast utils.string_hash(name)
        rom.path = path
        rom.database_name = name
        clean_name, tags := rom_extract_tags_from_name(name)
        rom.display_name = reorder_article_suffix(clean_name)
        rom.tags = tags
        rom.platform_id = u32(index)
        break
    }

    if rom == {} {
        name := fp.stem(fp.base(path))

        rom.id = auto_cast utils.string_hash(path)
        rom.path = path
        rom.platform_id = 0
        clean_name, tags := rom_extract_tags_from_name(name)
        rom.display_name = reorder_article_suffix(clean_name)
        rom.tags = tags
    }

    ok = true
    return
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


recognize_tag :: proc (tag_str: string) -> bit_set[RomTag] {
    tag_low := strings.to_lower(tag_str, context.temp_allocator)

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

    fixed := string(res)
    split[0] = fixed
    return strings.join(split, " - ", allocator)
}
