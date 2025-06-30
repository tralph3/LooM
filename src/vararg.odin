package main

import lr "libretro"
import "core:c"
import "core:strings"
import "core:log"

when ODIN_OS == .Windows {
    foreign import vararg "vararg.obj"
} else {
    foreign import vararg "vararg.o"
}

foreign vararg {
    c_log_callback :: proc "c" (lr.RetroLogLevel, cstring, #c_vararg ..any) ---
}

@(export)
odin_log_callback :: proc "c" (log_level: lr.RetroLogLevel, msg: cstring, n: c.int) {
    context = GLOBAL_STATE.ctx

    msg_str := strings.string_from_ptr((^u8)(msg), int(n))
    trimmed_msg := strings.trim_space(msg_str)

    full_msg := strings.concatenate({"CORE: ", trimmed_msg})
    defer delete(full_msg)

    switch log_level {
    case .Debug:
        log.debug(full_msg)
    case .Info:
        log.info(full_msg)
    case .Warn:
        log.warn(full_msg)
    case .Error:
        log.error(full_msg)
    }
}
