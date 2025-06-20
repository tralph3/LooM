package main

import lr "libretro"
import "core:strings"
import "core:log"

clone_cstring :: proc (cstr: cstring) -> cstring {
    tmp := strings.clone_from_cstring(cstr)
    defer delete(tmp)

    str, _ := strings.clone_to_cstring(tmp)
    return str
}

core_options_set_v2_intl :: proc (options: ^lr.RetroCoreOptionsV2Intl) {
    core_options_set_v2(options.us)
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

    // TODO: delete this...
    core_option_set("desmume_opengl_mode", "enabled")
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

    GLOBAL_STATE.emulator_state.options_updated = true

    return true
}
