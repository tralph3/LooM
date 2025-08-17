package roms

import "core:os/os2"
import fp "core:path/filepath"
import "loom:rdb"
import "core:log"
import "core:slice"
import "core:strings"

DATABASE_EXTENSION :: ".rdb"

Platform :: struct {
    name: string,
    db: rdb.Database,
}

PlatformError :: union {
    os2.Error,
    rdb.Error,
}

platforms_read_all :: proc (path: string, allocator:=context.allocator) -> (res: []Platform, err: PlatformError) {
    // since we don't know how many db files there are, we use this to
    // count them all, then copy them into the main arena
    // memory. otherwise as the array grows it can move around which
    // would waste memory space
    platforms: [dynamic]Platform
    platforms.allocator = context.temp_allocator

    fd := os2.open(path) or_return
    defer os2.close(fd)

    it := os2.read_directory_iterator_create(fd)
    defer os2.read_directory_iterator_destroy(&it)

    // platform id 0 is always the catch-all unknown platform
    // TODO: name localization
    append(&platforms, Platform{
        name = "Unknown",
        db = nil,
    })

    for file in os2.read_directory_iterator(&it) {
        if fp.ext(file.name) != DATABASE_EXTENSION { continue }

        log.debugf("Reading database '{}'...", file.name)

        db := rdb.parse(file.fullpath, allocator) or_return
        append(&platforms, Platform{
            name = strings.clone(fp.stem(file.name), allocator),
            db = db,
        })
    }

    res = make([]Platform, len(platforms), allocator)
    copy(res, platforms[:])

    return
}
