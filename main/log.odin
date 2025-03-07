package main

import "core:log"
import "core:strings"
import lr "libretro"

retro_log_callback :: proc "c" (level: lr.RetroLogLevel, fmt: cstring, args: rawptr) {
    context = GLOBAL_CONTEXT

    format := strings.clone_from_cstring(fmt)

    // TODO: figure out how to convert c variadic args to odin
    // currently this just prints the args address, but it can't
    // actually parse the arguments
    switch level {
    case .DEBUG:
        log.debugf(format, args)
    case .INFO:
        log.infof(format, args)
    case .WARN:
        log.warnf(format, args)
    case .ERROR:
        log.errorf(format, args)
    }

    delete(format)
}
