package main

import lr "libretro"
import "core:strings"
import "core:log"
import "core:mem"
import "core:fmt"

clone_cstring :: proc (cstr: cstring, allocator := context.allocator) -> cstring {
    tmp := string(cstr)

    clone := make([^]byte, len(tmp), allocator=allocator)
    mem.copy_non_overlapping(clone, rawptr(cstr), len(tmp))

    return cstring(clone)
}

core_options_set_v2_intl :: proc (options: ^lr.RetroCoreOptionsV2Intl) {
    core_options_set_v2(options.us) // TODO: support internatinal options
}

core_options_set_v2 :: proc (options: ^lr.RetroCoreOptionsV2) {
    GLOBAL_STATE.emulator_state.options = make(type_of(GLOBAL_STATE.emulator_state.options))

    for i in 0..<lr.RETRO_NUM_CORE_OPTION_VALUES_MAX {
        definition := options.definitions[i]
        if definition == {} {
            break
        }

        option := CoreOption{
            display = clone_cstring(definition.display),
            info = clone_cstring(definition.info),
            current_value = clone_cstring(definition.default_value),
            default_value = clone_cstring(definition.default_value),
            visible = true,
        }

        for value, i in definition.values {
            if value == {} {
                break
            }

            append(&option.values, CoreOptionValue{
                value = clone_cstring(value.value),
                label = clone_cstring(value.label),
            })
        }

        key := clone_cstring(definition.key)
        GLOBAL_STATE.emulator_state.options[key] = option
    }
}

core_options_set_variables :: proc (options: [^]lr.RetroVariable) {
    option_loop: for i in 0..<lr.RETRO_NUM_CORE_OPTION_VALUES_MAX {
        option := options[i]

        if option == {} {
            break
        }

        core_option := CoreOption { visible = true }

        // value format: "Display; default|val2|val3"
        char_idx: int
        for {
            defer char_idx += 1
            char := ([^]byte)(option.value)[char_idx]
            if char == '\x00' {
                continue option_loop
            }
            if char == ';' {
                tmp := strings.string_from_ptr((^byte)(option.value), char_idx)
                core_option.display = strings.clone_to_cstring(tmp)
                break
            }
        }

        // skip space
        char_idx += 1

        // cast the cstring to a byte array, index it with char_idx,
        // take its reference, cast to cstring, and finally to string
        // from there
        values_str := string(cstring(&([^]byte)(option.value)[char_idx]))
        values := strings.split(values_str, "|")
        defer delete(values)

        core_option.default_value = strings.clone_to_cstring(values[0])
        core_option.current_value = strings.clone_to_cstring(values[0])

        for value in values {
            append(&core_option.values, CoreOptionValue{
                value = strings.clone_to_cstring(value)
            })
        }

        key := clone_cstring(option.key)
        GLOBAL_STATE.emulator_state.options[key] = core_option
    }
}

core_options_free :: proc () {
    for key, option in GLOBAL_STATE.emulator_state.options {
        delete(key)
        delete(option.display)
        delete(option.info)
        delete(option.current_value)
        delete(option.default_value)

        for value in option.values {
            delete(value.value)
            delete(value.label)
        }

        delete(option.values)
    }

    delete(GLOBAL_STATE.emulator_state.options)
}

core_option_get_values :: proc (key: cstring) -> (vals: []CoreOptionValue, ok: bool) {
    option := (&GLOBAL_STATE.emulator_state.options[key]) or_return
    return option.values[:], true
}

core_option_get :: proc (key: cstring) -> (val: cstring, ok: bool) {
    option := (&GLOBAL_STATE.emulator_state.options[key]) or_return
    return option.current_value, true
}

core_option_set :: proc (key: cstring, val: cstring) -> (ok: bool) {
    option := (&GLOBAL_STATE.emulator_state.options[key]) or_return
    delete(option.current_value)

    option.current_value = clone_cstring(val)

    core_options_set_dirty(true)

    return true
}

core_options_print_all :: proc () {
    for key, option in GLOBAL_STATE.emulator_state.options {
        fmt.println(key, " '", option.display, "'", " = ", option.current_value, sep="")
        for value in option.values {
            fmt.print(value.value, "|", sep="")
        }

        fmt.println("\n--------------")
    }
}

core_option_set_visibility :: proc (key: cstring, visible: bool) -> (ok: bool) {
    option := (&GLOBAL_STATE.emulator_state.options[key]) or_return
    option.visible = visible

    return true
}

core_options_set_dirty :: proc (status: bool) {
    GLOBAL_STATE.emulator_state.options_updated = status
}

core_options_get_dirty :: proc () -> bool {
    return GLOBAL_STATE.emulator_state.options_updated
}
