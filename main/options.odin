package main

import lr "libretro"

// clone_core_options_v2 :: proc (options_union: union { lr.RetroCoreOptionsV2, lr.RetroCoreOptionsV2Intl }) {
//     emulator_free_core_options_v2()

//     options: lr.RetroCoreOptionsV2

//     switch o in options_union {
//     case lr.RetroCoreOptionsV2:
//         options = o
//     case lr.RetroCoreOptionsV2Intl:
//         if o.local != nil {
//             options = o.local^
//         } else  {
//             options = o.us^
//         }
//     }

//     core_definitions: [^]lr.RetroCoreOptionV2Definition = raw_data(options.definitions)
//     core_categories: [^]lr.RetroCoreOptionV2Category = raw_data(options.categories)

//     def_count := 0
//     for true {
//         definition := core_definitions[def_count]
//         if definition.key == nil { break }
//         def_count += 1
//     }

//     STATE.core_options_definitions.definitions = make([]lr.RetroCoreOptionV2Definition, def_count)
//     STATE.core_options = make(map[cstring]cstring)

//     for i in 0..<def_count {
//     STATEATOR_STATE.core_options_definitions
//     STATEs[i].key                 = new_clone(core_definitions[i].key)^
//         definitions[i].display             = new_clone(core_definitions[i].display)^
//         definitions[i].display_categorized = new_clone(core_definitions[i].display_categorized)^
//         definiSTATE               = new_clone(core_definitions[i].info)^
//         definitions[i].info_categorized    = new_clone(core_definitions[i].info_categorized)^
//         definitions[i].category_key        = new_clone(core_definitions[i].category_key)^
//         definitions[i].default_value       = new_clone(core_definitions[i].default_value)^

//         for j in 0..<lr.RETRO_NUM_CORE_OPTION_VALUES_MAX {
//             definitions[i].values[j].value = new_clone(core_definitions[i].values[j].value)^
//             definitions[i].values[j].label = new_clone(core_definitions[i].values[j].label)^
//         }

//         if definitions[i].default_value != nil {
//             STATE.core_options[definitions[i].key] = definitions[i].default_value
//         } else {
//             STATE.core_options[definitions[i].key] = definitions[i].values[0].value
//         }
//     }STATE

//     log.warnSTATE%d core definitions", def_count)

//     cat_count := 0
//     for true {
//         category := core_categories[cat_count]
//         if category.key == nil { break }
//         cat_count += 1
//     }

//     STATE.core_options_definitions.categories = make([]lr.RetroCoreOptionV2Category, cat_count)

//     for i in 0..<cat_count {
//         using STATE.core_options_definitions
//     STATE[i].key     = new_clone(core_categories[i].key)^
//         categories[i].display = new_clone(core_categories[i].display)^
//         categories[i].info    = new_clone(core_categories[i].info)^
//     }STATE
// }

// emulator_clone_variables :: proc (variables: [^]lr.RetroVariable) {
//     emulator_free_core_options_v2()

//     def_count := 0
//     for true {
//         var := variables[def_count]
//         if var.key == nil {
//             break
//         }
//         def_count += 1
//     }

//     STATE.core_options_definitions.definitions = make([]lr.RetroCoreOptionV2Definition, def_count)

//     for i in 0..<def_count {
//         using STATE.core_options_definitions
//     STATEs[i].key = new_clone(variables[i].key)^
//         res := strings.split(string(variables[i].value), "; ")
//         assert(len(res) == 2)
//         definiSTATEay = strings.clone_to_cstring(res[0])
//         values := strings.split(string(res[1]), "|")

//         for j in 0..<len(values) {
//             val := values[j]
//             definitions[i].values[j].value = strings.clone_to_cstring(val)
//             definitions[i].values[j].label = definitions[i].values[j].value
//         }
//     }
// }

// emulator_free_core_options_v2 :: proc () {
//     // for definition in STATE.core_options_definitions.definitions {
//     //     delete(definition.key)
//     //     delete(definition.display)
//     //     delete(definition.display_categorized)
//     //     delete(definition.info)
//     //     delete(definition.info_categorized)
//     //     delete(definition.category_key)
//     //     delete(definition.default_value)

//     //     for i in 0..<lr.RETRO_NUM_CORE_OPTION_VALUES_MAX {
//     //         delete(definition.values[i].value)
//     //         delete(definition.values[i].label)
//     //     }
//     // }

//     // delete(STATE.core_options_definitions.definitions)

//     // for category in STATE.core_options_definitions.categories {
//     //     delete(category.key)
//     //     delete(category.display)
//     //     delete(category.info)
//     // }

//     // delete(STATE.core_options_definitions.categories)
//     // delete(STATE.core_options)
// }
