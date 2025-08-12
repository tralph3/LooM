package main

import "rdb"
import "core:os/os2"
import fp "core:path/filepath"
import "core:strings"
import "core:log"
import "core:hash"
import t "loom:types"

@(private="file")
DATABASES: map[string]rdb.Database

database_read_all :: proc () -> (err: rdb.Error) {
    db_dir_fd := os2.open("./database") or_return
    defer os2.close(db_dir_fd)

    db_dir_it: os2.Read_Directory_Iterator
    os2.read_directory_iterator_init(&db_dir_it, db_dir_fd)

    for db_file in os2.read_directory_iterator(&db_dir_it) {
        if db_file.name != "Nintendo - Super Nintendo Entertainment System.rdb" {
            continue
        }
        db, parse_err := rdb.parse(db_file.fullpath)
        if parse_err != nil {
            log.errorf("Failed reading database '{}': {}", db_file.fullpath, parse_err)
            continue
        }

        db_name := strings.clone(fp.stem(db_file.name))
        DATABASES[db_name] = db
    }

    for k in DATABASES {
        log.info(k)
    }

    return
}

database_unload_all :: proc () {
    for name, db in DATABASES {
        delete(name)
        rdb.delete_database(db)
    }

    delete(DATABASES)
}

database_fill_metadata :: proc (game_entry: ^t.RomEntry, system: string, crc: u32) -> bool {
    db := DATABASES[system] or_return
    data := db[crc] or_return

    name := strings.clone((data["name"] or_else "").(string) or_return)
    game_entry.name = name

    return true
}
