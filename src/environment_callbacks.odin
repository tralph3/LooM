package main

import lr "libretro"
import fp "core:path/filepath"
import "core:fmt"
import "core:mem"
import "core:c"
import "core:c/libc"
import "base:runtime"
import "core:log"
import "core:strings"
import "core:path/filepath"

process_env_callback :: proc "c" (command: lr.RetroEnvironment, data: rawptr) -> bool {
    context = GLOBAL_STATE.ctx

    // remove the experimental bit
    command := lr.RetroEnvironment(u32(command) & ~u32(lr.RetroEnvironment.Experimental))

    //log.debugf("Processing env callback: '{}'", command)

    #partial switch command {
        case .GetCoreOptionsVersion: return env_callback_get_core_options_version(data)
        case .GetCanDupe: return env_callback_get_can_dupe(data)
        case .SetPixelFormat: return env_callback_set_pixel_format(data)
        case .GetLogInterface: return env_callback_get_log_interface(data)
        case .SetPerformanceLevel: return env_callback_set_performance_level(data)
        case .SetVariables: return env_callback_set_variables(data)
        case .SetCoreOptionsV2: return env_callback_set_core_options_v2(data)
        case .SetCoreOptionsV2Intl: return env_callback_set_core_options_v2_intl(data)
        case .GetVariable: return env_callback_get_variable(data)
        case .GetVariableUpdate: return env_callback_get_variable_update(data)
        case .SetHwSharedContext: return env_callback_set_hw_shared_context(data)
        case .GetPreferredHwRender: return env_callback_get_preferred_hw_render(data)
        case .SetHwRender: return env_callback_set_hw_render(data)
        case .GetSystemDirectory: return env_callback_get_system_directory(data)
        case .GetSaveDirectory: return env_callback_get_save_directory(data)
        case .GetFastforwarding: return env_callback_get_fastforwarding(data)
        case .SetGeometry: return env_callback_set_geometry(data)
        case .SetSystemAvInfo: return env_callback_set_system_av_info(data)
        case .SetCoreOptionsDisplay: return env_callback_set_core_options_display(data)
        case .GetInputBitmasks: return env_callback_get_input_bitmasks(data)
        case .GetRumbleInterface: return env_callback_get_rumble_interface(data)
        case .SetKeyboardCallback: return env_callback_set_keyboard_callback(data)
        case .SetSupportNoGame: return env_callback_set_support_no_game(data)
        case .GetLibretroPath: return env_callback_get_libretro_path(data)
        case .SetHwRenderContextNegotiationInterface: return env_callback_set_hw_render_context_negotiation_interface(data)
        case .GetHwRenderInterface: return env_callback_get_hw_render_interface(data)
        case .SetSupportAchievements: return env_callback_set_support_achievements(data)
        case: log.warnf("Callback not supported: '{}'", command)
    }

    return false
}

/**
 * Requests the frontend to set the screen rotation.
 *
 * @param[in] data <tt>const unsigned*</tt>.
 * Valid values are 0, 1, 2, and 3.
 * These numbers respectively set the screen rotation to 0, 90, 180, and 270 degrees counter-clockwise.
 * @returns \c true if the screen rotation was set successfully.
 */
env_callback_set_rotation :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Queries whether the core should use overscan or not.
 *
 * @param[out] data <tt>bool*</tt>.
 * Set to \c true if the core should use overscan,
 * \c false if it should be cropped away.
 * @returns \c true if the environment call is available.
 * Does \em not indicate whether overscan should be used.
 * @deprecated As of 2019 this callback is considered deprecated in favor of
 * using core options to manage overscan in a more nuanced, core-specific way.
 */
env_callback_get_overscan :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Queries whether the frontend supports frame duping,
 * in the form of passing \c NULL to the video frame callback.
 *
 * @param[out] data <tt>bool*</tt>.
 * Set to \c true if the frontend supports frame duping.
 * @returns \c true if the environment call is available.
 * @see retro_video_refresh_t
 */
env_callback_get_can_dupe :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    (^bool)(data)^ = true
    return true
}

/*
 * Environ 4, 5 are no longer supported (GET_VARIABLE / SET_VARIABLES),
 * and reserved to avoid possible ABI clash.
 */

/**
 * @brief Displays a user-facing message for a short time.
 *
 * Use this callback to convey important status messages,
 * such as errors or the result of long-running operations.
 * For trivial messages or logging, use \c RETRO_ENVIRONMENT_GET_LOG_INTERFACE or \c stderr.
 *
 * \code{.c}
 * void set_message_example(void)
 * {
 *    struct retro_message msg;
 *    msg.frames = 60 * 5; // 5 seconds
 *    msg.msg = "Hello world!";
 *
 *    environ_cb(RETRO_ENVIRONMENT_SET_MESSAGE, &msg);
 * }
 * \endcode
 *
 * @deprecated Prefer using \c RETRO_ENVIRONMENT_SET_MESSAGE_EXT for new code,
 * as it offers more features.
 * Only use this environment call for compatibility with older cores or frontends.
 *
 * @param[in] data <tt>const struct retro_message*</tt>.
 * Details about the message to show to the user.
 * Behavior is undefined if <tt>NULL</tt>.
 * @returns \c true if the environment call is available.
 * @see retro_message
 * @see RETRO_ENVIRONMENT_GET_LOG_INTERFACE
 * @see RETRO_ENVIRONMENT_SET_MESSAGE_EXT
 * @see RETRO_ENVIRONMENT_SET_MESSAGE
 * @see RETRO_ENVIRONMENT_GET_MESSAGE_INTERFACE_VERSION
 * @note The frontend must make its own copy of the message and the underlying string.
 */
env_callback_set_message :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Requests the frontend to shutdown the core.
 * Should only be used if the core can exit on its own,
 * such as from a menu item in a game
 * or an emulated power-off in an emulator.
 *
 * @param data Ignored.
 * @returns \c true if the environment call is available.
 */
env_callback_shutdown :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Gives a hint to the frontend of how demanding this core is on the system.
 * For example, reporting a level of 2 means that
 * this implementation should run decently on frontends
 * of level 2 and above.
 *
 * It can be used by the frontend to potentially warn
 * about too demanding implementations.
 *
 * The levels are "floating".
 *
 * This function can be called on a per-game basis,
 * as a core may have different demands for different games or settings.
 * If called, it should be called in <tt>retro_load_game()</tt>.
 * @param[in] data <tt>const unsigned*</tt>.
*/
env_callback_set_performance_level :: proc (data: rawptr) -> bool { // TODO: Get performance level of device and compare the two
    if data == nil { return false }

    emulator_set_performance_level((^uint)(data)^)
    return true
}

/**
 * Returns the path to the frontend's system directory,
 * which can be used to store system-specific configuration
 * such as BIOS files or cached data.
 *
 * @param[out] data <tt>const char**</tt>.
 * Pointer to the \c char* in which the system directory will be saved.
 * The string is managed by the frontend and must not be modified or freed by the core.
 * May be \c NULL if no system directory is defined,
 * in which case the core should find an alternative directory.
 * @return \c true if the environment call is available,
 * even if the value returned in \c data is <tt>NULL</tt>.
 * @note Historically, some cores would use this folder for save data such as memory cards or SRAM.
 * This is now discouraged in favor of \c RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY.
 * @see RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY
 */
env_callback_get_system_directory :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    system_dir, err := dir_path_with_trailing_slash_cstr(config_get_system_dir_path())
    if err != nil {
        return false
    }
    defer delete(system_dir)

    (^cstring)(data)^ = system_dir
    return true
}

/**
 * Sets the internal pixel format used by the frontend for rendering.
 * The default pixel format is \c RETRO_PIXEL_FORMAT_0RGB1555 for compatibility reasons,
 * although it's considered deprecated and shouldn't be used by new code.
 *
 * @param[in] data <tt>const enum retro_pixel_format *</tt>.
 * Pointer to the pixel format to use.
 * @returns \c true if the pixel format was set successfully,
 * \c false if it's not supported or this callback is unavailable.
 * @note This function should be called inside \c retro_load_game()
 * or <tt>retro_get_system_av_info()</tt>.
 * @see retro_pixel_format
 */
env_callback_set_pixel_format :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    format := (^lr.RetroPixelFormat)(data)^
    if format < min(lr.RetroPixelFormat) || format > max(lr.RetroPixelFormat) {
        return false
    }

    video_set_pixel_format(format)
    return true
}

/**
 * Sets an array of input descriptors for the frontend
 * to present to the user for configuring the core's controls.
 *
 * This function can be called at any time,
 * preferably early in the core's life cycle.
 * Ideally, no later than \c retro_load_game().
 *
 * @param[in] data <tt>const struct retro_input_descriptor *</tt>.
 * An array of input descriptors terminated by one whose
 * \c retro_input_descriptor::description field is set to \c NULL.
 * Behavior is undefined if \c NULL.
 * @return \c true if the environment call is recognized.
 * @see retro_input_descriptor
 */
env_callback_set_input_descriptors :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Sets a callback function used to notify the core about keyboard events.
 * This should only be used for cores that specifically need keyboard input,
 * such as for home computer emulators or games with text entry.
 *
 * @param[in] data <tt>const struct retro_keyboard_callback *</tt>.
 * Pointer to the callback function.
 * Behavior is undefined if <tt>NULL</tt>.
 * @return \c true if the environment call is recognized.
 * @see retro_keyboard_callback
 * @see retro_key
 */
env_callback_set_keyboard_callback :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    emulator_set_keyboard_callback((^lr.RetroKeyboardCallback)(data).callback)
    return true
}

/**
 * Sets an interface that the frontend can use to insert and remove disks
 * from the emulated console's disk drive.
 * Can be used for optical disks, floppy disks, or any other game storage medium
 * that can be swapped at runtime.
 *
 * This is intended for multi-disk games that expect the player
 * to manually swap disks at certain points in the game.
 *
 * @deprecated Prefer using \c RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE
 * over this environment call, as it supports additional features.
 * Only use this callback to maintain compatibility
 * with older cores or frontends.
 *
 * @param[in] data <tt>const struct retro_disk_control_callback *</tt>.
 * Pointer to the callback functions to use.
 * May be \c NULL, in which case the existing disk callback is deregistered.
 * @return \c true if this environment call is available,
 * even if \c data is \c NULL.
 * @see retro_disk_control_callback
 * @see RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE
 */
env_callback_set_disk_control_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Requests that a frontend enable a particular hardware rendering API.
 *
 * If successful, the frontend will create a context (and other related resources)
 * that the core can use for rendering.
 * The framebuffer will be at least as large as
 * the maximum dimensions provided in <tt>retro_get_system_av_info</tt>.
 *
 * @param[in, out] data <tt>struct retro_hw_render_callback *</tt>.
 * Pointer to the hardware render callback struct.
 * Used to define callbacks for the hardware-rendering life cycle,
 * as well as to request a particular rendering API.
 * @return \c true if the environment call is recognized
 * and the requested rendering API is supported.
 * \c false if \c data is \c NULL
 * or the frontend can't provide the requested rendering API.
 * @see retro_hw_render_callback
 * @see retro_video_refresh_t
 * @see RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER
 * @note Should be called in <tt>retro_load_game()</tt>.
 * @note If HW rendering is used, pass only \c RETRO_HW_FRAME_BUFFER_VALID or
 * \c NULL to <tt>retro_video_refresh_t</tt>.
 */
env_callback_set_hw_render :: proc (data: rawptr) -> bool { // TODO: add other apis
    if data == nil { return false }

    render_cb := (^lr.RetroHwRenderCallback)(data)
    #partial switch render_cb.context_type {
    case .OPENGL_CORE, .OPENGL:
        video_init_emu_opengl_context(render_cb)
        return true
    case .VULKAN:
        video_init_emu_vulkan_context(render_cb)
        return true
    }

    return false
}

/**
 * Retrieves a core option's value from the frontend.
 * \c retro_variable::key should be set to an option key
 * that was previously set in \c RETRO_ENVIRONMENT_SET_VARIABLES
 * (or a similar environment call).
 *
 * @param[in,out] data <tt>struct retro_variable *</tt>.
 * Pointer to a single \c retro_variable struct.
 * See the documentation for \c retro_variable for details
 * on which fields are set by the frontend or core.
 * May be \c NULL.
 * @returns \c true if the environment call is available,
 * even if \c data is \c NULL or the key it specifies is not found.
 * @note Passing \c NULL in to \c data can be useful to
 * test for support of this environment call without looking up any variables.
 * @see retro_variable
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2
 * @see RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE
 */
env_callback_get_variable :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return true }

    var := (^lr.RetroVariable)(data)
    opt := emulator_get_options()
    var.value = opt.options[var.key].current_value

    core_options_set_dirty(opt, false)
    return true
}

/**
 * Notifies the frontend of the core's available options.
 *
 * The core may check these options later using \c RETRO_ENVIRONMENT_GET_VARIABLE.
 * The frontend may also present these options to the user
 * in its own configuration UI.
 *
 * This should be called the first time as early as possible,
 * ideally in \c retro_set_environment.
 * The core may later call this function again
 * to communicate updated options to the frontend,
 * but the number of core options must not change.
 *
 * Here's an example that sets two options.
 *
 * @code
 * void set_variables_example(void)
 * {
 *    struct retro_variable options[] = {
 *        { "foo_speedhack", "Speed hack; false|true" }, // false by default
 *        { "foo_displayscale", "Display scale factor; 1|2|3|4" }, // 1 by default
 *        { NULL, NULL },
 *    };
 *
 *    environ_cb(RETRO_ENVIRONMENT_SET_VARIABLES, &options);
 * }
 * @endcode
 *
 * The possible values will generally be displayed and stored as-is by the frontend.
 *
 * @deprecated Prefer using \c RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2 for new code,
 * as it offers more features such as categories and translation.
 * Only use this environment call to maintain compatibility
 * with older frontends or cores.
 * @note Keep the available options (and their possible values) as low as possible;
 * it should be feasible to cycle through them without a keyboard.
 * @param[in] data <tt>const struct retro_variable *</tt>.
 * Pointer to an array of \c retro_variable structs that define available core options,
 * terminated by a <tt>{ NULL, NULL }</tt> element.
 * The frontend must maintain its own copy of this array.
 *
 * @returns \c true if the environment call is available,
 * even if \c data is <tt>NULL</tt>.
 * @see retro_variable
 * @see RETRO_ENVIRONMENT_GET_VARIABLE
 * @see RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2
 */
env_callback_set_variables :: proc (data: rawptr) -> bool { // DONE
    if data == nil {
        emulator_clear_options()
    } else {
        opt := core_options_parse_set_variables(auto_cast data)
        emulator_set_options(opt)
    }

    return true
}

/**
 * Queries whether at least one core option was updated by the frontend
 * since the last call to \ref RETRO_ENVIRONMENT_GET_VARIABLE.
 * This typically means that the user opened the core options menu and made some changes.
 *
 * Cores usually call this each frame before the core's main emulation logic.
 * Specific options can then be queried with \ref RETRO_ENVIRONMENT_GET_VARIABLE.
 *
 * @param[out] data <tt>bool *</tt>.
 * Set to \c true if at least one core option was updated
 * since the last call to \ref RETRO_ENVIRONMENT_GET_VARIABLE.
 * Behavior is undefined if this pointer is \c NULL.
 * @returns \c true if the environment call is available.
 * @see RETRO_ENVIRONMENT_GET_VARIABLE
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2
 */
env_callback_get_variable_update :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    opt := emulator_get_options()
    (^bool)(data)^ = opt.dirty
    return true
}

/**
 * Notifies the frontend that this core can run without loading any content,
 * such as when emulating a console that has built-in software.
 * When a core is loaded without content,
 * \c retro_load_game receives an argument of <tt>NULL</tt>.
 * This should be called within \c retro_set_environment() only.
 *
 * @param[in] data <tt>const bool *</tt>.
 * Pointer to a single \c bool that indicates whether this frontend can run without content.
 * Can point to a value of \c false but this isn't necessary,
 * as contentless support is opt-in.
 * The behavior is undefined if \c data is <tt>NULL</tt>.
 * @returns \c true if the environment call is available.
 * @see retro_load_game
 */
env_callback_set_support_no_game :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    emulator_set_support_no_game((^bool)(data)^)
    return true
}

/**
 * Retrieves the absolute path from which this core was loaded.
 * Useful when loading assets from paths relative to the core,
 * as is sometimes the case when using <tt>RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME</tt>.
 *
 * @param[out] data <tt>const char **</tt>.
 * Pointer to a string in which the core's path will be saved.
 * The string is managed by the frontend and must not be modified or freed by the core.
 * May be \c NULL if the core is statically linked to the frontend
 * or if the core's path otherwise cannot be determined.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * @returns \c true if the environment call is available.
 */
env_callback_get_libretro_path :: proc (data: rawptr) -> bool { // TODO: check what the lifetime of the string should be
    if data == nil { return false }

    core_dir := fp.dir(emulator_get_current_game_entry().core, context.temp_allocator)
    path, _ := dir_path_with_trailing_slash_cstr(core_dir)
    defer delete(path)
    (^cstring)(data)^ = path

    return true
}

/* Environment call 20 was an obsolete version of SET_AUDIO_CALLBACK.
 * It was not used by any known core at the time, and was removed from the API.
 * The number 20 is reserved to prevent ABI clashes.
 */

/**
 * Sets a callback that notifies the core of how much time has passed
 * since the last iteration of <tt>retro_run</tt>.
 * If the frontend is not running the core in real time
 * (e.g. it's frame-stepping or running in slow motion),
 * then the reference value will be provided to the callback instead.
 *
 * @param[in] data <tt>const struct retro_frame_time_callback *</tt>.
 * Pointer to a single \c retro_frame_time_callback struct.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * @returns \c true if the environment call is available.
 * @note Frontends may disable this environment call in certain situations.
 * It will return \c false in those cases.
 * @see retro_frame_time_callback
 */
env_callback_set_frame_time_callback :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Registers a set of functions that the frontend can use
 * to tell the core it's ready for audio output.
 *
 * It is intended for games that feature asynchronous audio.
 * It should not be used for emulators unless their audio is asynchronous.
 *
 *
 * The callback only notifies about writability; the libretro core still
 * has to call the normal audio callbacks
 * to write audio. The audio callbacks must be called from within the
 * notification callback.
 * The amount of audio data to write is up to the core.
 * Generally, the audio callback will be called continuously in a loop.
 *
 * A frontend may disable this callback in certain situations.
 * The core must be able to render audio with the "normal" interface.
 *
 * @param[in] data <tt>const struct retro_audio_callback *</tt>.
 * Pointer to a set of functions that the frontend will call to notify the core
 * when it's ready to receive audio data.
 * May be \c NULL, in which case the frontend will return
 * whether this environment callback is available.
 * @return \c true if this environment call is available,
 * even if \c data is \c NULL.
 * @warning The provided callbacks can be invoked from any thread,
 * so their implementations \em must be thread-safe.
 * @note If a core uses this callback,
 * it should also use <tt>RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK</tt>.
 * @see retro_audio_callback
 * @see retro_audio_sample_t
 * @see retro_audio_sample_batch_t
 * @see RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK
 */
env_callback_set_audio_callback :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Gets an interface that a core can use to access a controller's rumble motors.
 *
 * The interface supports two independently-controlled motors,
 * one strong and one weak.
 *
 * Should be called from either \c retro_init() or \c retro_load_game(),
 * but not from \c retro_set_environment().
 *
 * @param[out] data <tt>struct retro_rumble_interface *</tt>.
 * Pointer to the interface struct.
 * Behavior is undefined if \c NULL.
 * @returns \c true if the environment call is available,
 * even if the current device doesn't support vibration.
 * @see retro_rumble_interface
 * @defgroup GET_RUMBLE_INTERFACE Rumble Interface
 */
env_callback_get_rumble_interface :: proc (data: rawptr) -> bool { // TODO
    if data == nil { return false }

    (^lr.RetroRumbleInterface)(data).set_rumble_state = input_set_rumble
    return true
}

/**
 * Returns the frontend's supported input device types.
 *
 * The supported device types are returned as a bitmask,
 * with each value of \ref RETRO_DEVICE corresponding to a bit.
 *
 * Should only be called in \c retro_run().
 *
 * @code
 * #define REQUIRED_DEVICES ((1 << RETRO_DEVICE_JOYPAD) | (1 << RETRO_DEVICE_ANALOG))
 * void get_input_device_capabilities_example(void)
 * {
 *    uint64_t capabilities;
 *    environ_cb(RETRO_ENVIRONMENT_GET_INPUT_DEVICE_CAPABILITIES, &capabilities);
 *    if ((capabilities & REQUIRED_DEVICES) == REQUIRED_DEVICES)
 *      printf("Joypad and analog device types are supported");
 * }
 * @endcode
 *
 * @param[out] data <tt>uint64_t *</tt>.
 * Pointer to a bitmask of supported input device types.
 * If the frontend supports a particular \c RETRO_DEVICE_* type,
 * then the bit <tt>(1 << RETRO_DEVICE_*)</tt> will be set.
 *
 * Each bit represents a \c RETRO_DEVICE constant,
 * e.g. bit 1 represents \c RETRO_DEVICE_JOYPAD,
 * bit 2 represents \c RETRO_DEVICE_MOUSE, and so on.
 *
 * Bits that do not correspond to known device types will be set to zero
 * and are reserved for future use.
 *
 * Behavior is undefined if \c NULL.
 * @returns \c true if the environment call is available.
 * @note If the frontend supports multiple input drivers,
 * availability of this environment call (and the reported capabilities)
 * may depend on the active driver.
 * @see RETRO_DEVICE
 */
env_callback_get_input_device_capabilities :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns an interface that the core can use to access and configure available sensors,
 * such as an accelerometer or gyroscope.
 *
 * @param[out] data <tt>struct retro_sensor_interface *</tt>.
 * Pointer to the sensor interface that the frontend will populate.
 * Behavior is undefined if is \c NULL.
 * @returns \c true if the environment call is available,
 * even if the device doesn't have any supported sensors.
 * @see retro_sensor_interface
 * @see retro_sensor_action
 * @see RETRO_SENSOR
 * @addtogroup RETRO_SENSOR
 */
env_callback_get_sensor_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Gets an interface to the device's video camera.
 *
 * The frontend delivers new video frames via a user-defined callback
 * that runs in the same thread as \c retro_run().
 * Should be called in \c retro_load_game().
 *
 * @param[in,out] data <tt>struct retro_camera_callback *</tt>.
 * Pointer to the camera driver interface.
 * Some fields in the struct must be filled in by the core,
 * others are provided by the frontend.
 * Behavior is undefined if \c NULL.
 * @returns \c true if this environment call is available,
 * even if an actual camera isn't.
 * @note This API only supports one video camera at a time.
 * If the device provides multiple cameras (e.g. inner/outer cameras on a phone),
 * the frontend will choose one to use.
 * @see retro_camera_callback
 * @see RETRO_ENVIRONMENT_SET_HW_RENDER
 */
env_callback_get_camera_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Gets an interface that the core can use for cross-platform logging.
 * Certain platforms don't have a console or <tt>stderr</tt>,
 * or they have their own preferred logging methods.
 * The frontend itself may also display log output.
 *
 * @attention This should not be used for information that the player must immediately see,
 * such as major errors or warnings.
 * In most cases, this is best for information that will help you (the developer)
 * identify problems when debugging or providing support.
 * Unless a core or frontend is intended for advanced users,
 * the player might not check (or even know about) their logs.
 *
 * @param[out] data <tt>struct retro_log_callback *</tt>.
 * Pointer to the callback where the function pointer will be saved.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * @returns \c true if the environment call is available.
 * @see retro_log_callback
 * @note Cores can fall back to \c stderr if this interface is not available.
 */
env_callback_get_log_interface :: proc(data: rawptr) -> bool { // DONE
    if data == nil { return false }

    ((^lr.RetroLogCallback)(data)^).log = c_log_callback
    return true
}

/**
 * Returns an interface that the core can use for profiling code
 * and to access performance-related information.
 *
 * This callback supports performance counters, a high-resolution timer,
 * and listing available CPU features (mostly SIMD instructions).
 *
 * @param[out] data <tt>struct retro_perf_callback *</tt>.
 * Pointer to the callback interface.
 * Behavior is undefined if \c NULL.
 * @returns \c true if the environment call is available.
 * @see retro_perf_callback
 */
env_callback_get_perf_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns an interface that the core can use to retrieve the device's location,
 * including its current latitude and longitude.
 *
 * @param[out] data <tt>struct retro_location_callback *</tt>.
 * Pointer to the callback interface.
 * Behavior is undefined if \c NULL.
 * @return \c true if the environment call is available,
 * even if there's no location information available.
 * @see retro_location_callback
 */
env_callback_get_location_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * @deprecated An obsolete alias to \c RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY kept for compatibility.
 * @see RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY
 **/
env_callback_get_content_directory :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns the frontend's "core assets" directory,
 * which can be used to store assets that the core needs
 * such as art assets or level data.
 *
 * @param[out] data <tt>const char **</tt>.
 * Pointer to a string in which the core assets directory will be saved.
 * This string is managed by the frontend and must not be modified or freed by the core.
 * May be \c NULL if no core assets directory is defined,
 * in which case the core should find an alternative directory.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * @returns \c true if the environment call is available,
 * even if the value returned in \c data is <tt>NULL</tt>.
 */
env_callback_get_core_assets_directory :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns the frontend's save data directory, if available.
 * This directory should be used to store game-specific save data,
 * including memory card images.
 *
 * Although libretro provides an interface for cores to expose SRAM to the frontend,
 * not all cores can support it correctly.
 * In this case, cores should use this environment callback
 * to save their game data to disk manually.
 *
 * Cores that use this environment callback
 * should flush their save data to disk periodically and when unloading.
 *
 * @param[out] data <tt>const char **</tt>.
 * Pointer to the string in which the save data directory will be saved.
 * This string is managed by the frontend and must not be modified or freed by the core.
 * May return \c NULL if no save data directory is defined.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * @returns \c true if the environment call is available,
 * even if the value returned in \c data is <tt>NULL</tt>.
 * @note Early libretro cores used \c RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY for save data.
 * This is still supported for backwards compatibility,
 * but new cores should use this environment call instead.
 * \c RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY should be used for game-agnostic data
 * such as BIOS files or core-specific configuration.
 * @note The returned directory may or may not be the same
 * as the one used for \c retro_get_memory_data.
 *
 * @see retro_get_memory_data
 * @see RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY
 */
env_callback_get_save_directory :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    saves_dir, err := dir_path_with_trailing_slash_cstr(config_get_saves_dir_path())
    if err != nil {
        return false
    }
    defer delete(saves_dir)

    (^cstring)(data)^ = saves_dir
    return true
}

/**
 * Sets new video and audio parameters for the core.
 * This can only be called from within <tt>retro_run</tt>.
 *
 * This environment call may entail a full reinitialization of the frontend's audio/video drivers,
 * hence it should \em only be used if the core needs to make drastic changes
 * to audio/video parameters.
 *
 * This environment call should \em not be used when:
 * <ul>
 * <li>Changing the emulated system's internal resolution,
 * within the limits defined by the existing values of \c max_width and \c max_height.
 * Use \c RETRO_ENVIRONMENT_SET_GEOMETRY instead,
 * and adjust \c retro_get_system_av_info to account for
 * supported scale factors and screen layouts
 * when computing \c max_width and \c max_height.
 * Only use this environment call if \c max_width or \c max_height needs to increase.
 * <li>Adjusting the screen's aspect ratio,
 * e.g. when changing the layout of the screen(s).
 * Use \c RETRO_ENVIRONMENT_SET_GEOMETRY or \c RETRO_ENVIRONMENT_SET_ROTATION instead.
 * </ul>
 *
 * The frontend will reinitialize its audio and video drivers within this callback;
 * after that happens, audio and video callbacks will target the newly-initialized driver,
 * even within the same \c retro_run call.
 *
 * This callback makes it possible to support configurable resolutions
 * while avoiding the need to compute the "worst case" values of \c max_width and \c max_height.
 *
 * @param[in] data <tt>const struct retro_system_av_info *</tt>.
 * Pointer to the new video and audio parameters that the frontend should adopt.
 * @returns \c true if the environment call is available
 * and the new av_info struct was accepted.
 * \c false if the environment call is unavailable or \c data is <tt>NULL</tt>.
 * @see retro_system_av_info
 * @see RETRO_ENVIRONMENT_SET_GEOMETRY
 */
env_callback_set_system_av_info :: proc (data: rawptr) -> bool { // TODO: revise when more video backends are supported
    if data == nil { return false }

    av_info := (^lr.SystemAvInfo)(data)
    emulator_update_av_info(av_info)

    return true
}

/**
 * Provides an interface that a frontend can use
 * to get function pointers from the core.
 *
 * This allows cores to define their own extensions to the libretro API,
 * or to expose implementations of a frontend's libretro extensions.
 *
 * @param[in] data <tt>const struct retro_get_proc_address_interface *</tt>.
 * Pointer to the interface that the frontend can use to get function pointers from the core.
 * The frontend must maintain its own copy of this interface.
 * @returns \c true if the environment call is available
 * and the returned interface was accepted.
 * @note The provided interface may be called at any time,
 * even before this environment call returns.
 * @note Extensions should be prefixed with the name of the frontend or core that defines them.
 * For example, a frontend named "foo" that defines a debugging extension
 * should expect the core to define functions prefixed with "foo_debug_".
 * @warning If a core wants to use this environment call,
 * it \em must do so from within \c retro_set_environment().
 * @see retro_get_proc_address_interface
 */
env_callback_set_proc_address_callback :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Registers a core's ability to handle "subsystems",
 * which are secondary platforms that augment a core's primary emulated hardware.
 *
 * A core doesn't need to emulate a secondary platform
 * in order to use it as a subsystem;
 * as long as it can load a secondary file for some practical use,
 * then this environment call is most likely suitable.
 *
 * Possible use cases of a subsystem include:
 *
 * \li Installing software onto an emulated console's internal storage,
 * such as the Nintendo DSi.
 * \li Emulating accessories that are used to support another console's games,
 * such as the Super Game Boy or the N64 Transfer Pak.
 * \li Inserting a secondary ROM into a console
 * that features multiple cartridge ports,
 * such as the Nintendo DS's Slot-2.
 * \li Loading a save data file created and used by another core.
 *
 * Cores should \em not use subsystems for:
 *
 * \li Emulators that support multiple "primary" platforms,
 * such as a Game Boy/Game Boy Advance core
 * or a Sega Genesis/Sega CD/32X core.
 * Use \c retro_system_content_info_override, \c retro_system_info,
 * and/or runtime detection instead.
 * \li Selecting different memory card images.
 * Use dynamically-populated core options instead.
 * \li Different variants of a single console,
 * such the Game Boy vs. the Game Boy Color.
 * Use core options or runtime detection instead.
 * \li Games that span multiple disks.
 * Use \c RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE
 * and m3u-formatted playlists instead.
 * \li Console system files (BIOS, firmware, etc.).
 * Use \c RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY
 * and a common naming convention instead.
 *
 * When the frontend loads a game via a subsystem,
 * it must call \c retro_load_game_special() instead of \c retro_load_game().
 *
 * @param[in] data <tt>const struct retro_subsystem_info *</tt>.
 * Pointer to an array of subsystem descriptors,
 * terminated by a zeroed-out \c retro_subsystem_info struct.
 * The frontend should maintain its own copy
 * of this array and the strings within it.
 * Behavior is undefined if \c NULL.
 * @returns \c true if this environment call is available.
 * @note This environment call \em must be called from within \c retro_set_environment(),
 * as frontends may need the registered information before loading a game.
 * @see retro_subsystem_info
 * @see retro_load_game_special
 */
env_callback_set_subsystem_info :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Declares one or more types of controllers supported by this core.
 * The frontend may then allow the player to select one of these controllers in its menu.
 *
 * Many consoles had controllers that came in different versions,
 * were extensible with peripherals,
 * or could be held in multiple ways;
 * this environment call can be used to represent these differences
 * and adjust the core's behavior to match.
 *
 * Possible use cases include:
 *
 * \li Supporting different classes of a single controller that supported their own sets of games.
 *     For example, the SNES had two different lightguns (the Super Scope and the Justifier)
 *     whose games were incompatible with each other.
 * \li Representing a platform's alternative controllers.
 *     For example, several platforms had music/rhythm games that included controllers
 *     shaped like musical instruments.
 * \li Representing variants of a standard controller with additional inputs.
 *     For example, numerous consoles in the 90's introduced 6-button controllers for fighting games,
 *     steering wheels for racing games,
 *     or analog sticks for 3D platformers.
 * \li Representing add-ons for consoles or standard controllers.
 *     For example, the 3DS had a Circle Pad Pro attachment that added a second analog stick.
 * \li Selecting different configurations for a single controller.
 *     For example, the Wii Remote could be held sideways like a traditional game pad
 *     or in one hand like a wand.
 * \li Providing multiple ways to simulate the experience of using a particular controller.
 *     For example, the Game Boy Advance featured several games
 *     with motion or light sensors in their cartridges;
 *     a core could provide controller configurations
 *     that allow emulating the sensors with either analog axes
 *     or with their host device's sensors.
 *
 * Should be called in retro_load_game.
 * The frontend must maintain its own copy of the provided array,
 * including all strings and subobjects.
 * A core may exclude certain controllers for known incompatible games.
 *
 * When the frontend changes the active device for a particular port,
 * it must call \c retro_set_controller_port_device() with that port's index
 * and one of the IDs defined in its retro_controller_info::types field.
 *
 * Input ports are generally associated with different players
 * (and the frontend's UI may reflect this with "Player 1" labels),
 * but this is not required.
 * Some games use multiple controllers for a single player,
 * or some cores may use port indexes to represent an emulated console's
 * alternative input peripherals.
 *
 * @param[in] data <tt>const struct retro_controller_info *</tt>.
 * Pointer to an array of controller types defined by this core,
 * terminated by a zeroed-out \c retro_controller_info.
 * Each element of this array represents a controller port on the emulated device.
 * Behavior is undefined if \c NULL.
 * @returns \c true if this environment call is available.
 * @see retro_controller_info
 * @see retro_set_controller_port_device
 * @see RETRO_DEVICE_SUBCLASS
 */
env_callback_set_controller_info :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Notifies the frontend of the address spaces used by the core's emulated hardware,
 * and of the memory maps within these spaces.
 * This can be used by the frontend to provide cheats, achievements, or debugging capabilities.
 * Should only be used by emulators, as it makes little sense for game engines.
 *
 * @note Cores should also expose these address spaces
 * through retro_get_memory_data and \c retro_get_memory_size if applicable;
 * this environment call is not intended to replace those two functions,
 * as the emulated hardware may feature memory regions outside of its own address space
 * that are nevertheless useful for the frontend.
 *
 * @param[in] data <tt>const struct retro_memory_map *</tt>.
 * Pointer to a single memory-map listing.
 * The frontend must maintain its own copy of this object and its contents,
 * including strings and nested objects.
 * Behavior is undefined if \c NULL.
 * @returns \c true if this environment call is available.
 * @see retro_memory_map
 * @see retro_get_memory_data
 * @see retro_memory_descriptor
 */
env_callback_set_memory_maps :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Resizes the viewport without reinitializing the video driver.
 *
 * Similar to \c RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO,
 * but any changes that would require video reinitialization will not be performed.
 * Can only be called from within \c retro_run().
 *
 * This environment call allows a core to revise the size of the viewport at will,
 * which can be useful for emulated platforms that support dynamic resolution changes
 * or for cores that support multiple screen layouts.
 *
 * A frontend must guarantee that this environment call completes in
 * constant time.
 *
 * @param[in] data <tt>const struct retro_game_geometry *</tt>.
 * Pointer to the new video parameters that the frontend should adopt.
 * \c retro_game_geometry::max_width and \c retro_game_geometry::max_height
 * will be ignored.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * @return \c true if the environment call is available.
 * @see RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO
 */
env_callback_set_geometry :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    geo := (^lr.GameGeometry)(data)
    // ignore max_width and max_height
    emulator_update_geometry(geo)
    return true
}

/**
 * Returns the name of the user, if possible.
 * This callback is suitable for cores that offer personalization,
 * such as online facilities or user profiles on the emulated system.
 * @param[out] data <tt>const char **</tt>.
 * Pointer to the user name string.
 * May be \c NULL, in which case the core should use a default name.
 * The returned pointer is owned by the frontend and must not be modified or freed by the core.
 * Behavior is undefined if \c NULL.
 * @returns \c true if the environment call is available,
 * even if the frontend couldn't provide a name.
 */
env_callback_get_username :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns the frontend's configured language.
 * It can be used to localize the core's UI,
 * or to customize the emulated firmware if applicable.
 *
 * @param[out] data <tt>retro_language *</tt>.
 * Pointer to the language identifier.
 * Behavior is undefined if \c NULL.
 * @returns \c true if the environment call is available.
 * @note The returned language may not be the same as the operating system's language.
 * Cores should fall back to the operating system's language (or to English)
 * if the environment call is unavailable or the returned language is unsupported.
 * @see retro_language
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL
 */
env_callback_get_language :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns a frontend-managed framebuffer
 * that the core may render directly into
 *
 * This environment call is provided as an optimization
 * for cores that use software rendering
 * (i.e. that don't use \refitem RETRO_ENVIRONMENT_SET_HW_RENDER "a graphics hardware API");
 * specifically, the intended use case is to allow a core
 * to render directly into frontend-managed video memory,
 * avoiding the bandwidth use that copying a whole framebuffer from core to video memory entails.
 *
 * Must be called every frame if used,
 * as this may return a different framebuffer each frame
 * (e.g. for swap chains).
 * However, a core may render to a different buffer even if this call succeeds.
 *
 * @param[in,out] data <tt>struct retro_framebuffer *</tt>.
 * Pointer to a frontend's frame buffer and accompanying data.
 * Some fields are set by the core, others are set by the frontend.
 * Only guaranteed to be valid for the duration of the current \c retro_run call,
 * and must not be used afterwards.
 * Behavior is undefined if \c NULL.
 * @return \c true if the environment call was recognized
 * and the framebuffer was successfully returned.
 * @see retro_framebuffer
 */
env_callback_get_current_software_framebuffer :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns an interface for accessing the data of specific rendering APIs.
 * Not all hardware rendering APIs support or need this.
 *
 * The details of these interfaces are specific to each rendering API.
 *
 * @note \c retro_hw_render_callback::context_reset must be called by the frontend
 * before this environment call can be used.
 * Additionally, the contents of the returned interface are invalidated
 * after \c retro_hw_render_callback::context_destroyed has been called.
 * @param[out] data <tt>const struct retro_hw_render_interface **</tt>.
 * The render interface for the currently-enabled hardware rendering API, if any.
 * The frontend will store a pointer to the interface at the address provided here.
 * The returned interface is owned by the frontend and must not be modified or freed by the core.
 * Behavior is undefined if \c NULL.
 * @return \c true if this environment call is available,
 * the active graphics API has a libretro rendering interface,
 * and the frontend is able to return said interface.
 * \c false otherwise.
 * @see RETRO_ENVIRONMENT_SET_HW_RENDER
 * @see retro_hw_render_interface
 * @note Since not every libretro-supported hardware rendering API
 * has a \c retro_hw_render_interface implementation,
 * a result of \c false is not necessarily an error.
 */
env_callback_get_hw_render_interface :: proc (data: rawptr) -> bool { // TODO
    if data == nil { return false }

    interface := cast(^lr.RetroHwRenderInterface)data
    #partial switch interface.interface_type {
    case .VULKAN:
        vk_interface := cast(^lr.RetroHwRenderInterfaceVulkan)data
        vk_interface.interface_version = lr.RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION
        return true
    }

    return false
}

/**
 * Explicitly notifies the frontend of whether this core supports achievements.
 * The core must expose its emulated address space via
 * \c retro_get_memory_data or \c RETRO_ENVIRONMENT_GET_MEMORY_MAPS.
 * Must be called before the first call to <tt>retro_run</tt>.
 *
 * If \ref retro_get_memory_data returns a valid address
 * but this environment call is not used,
 * the frontend (at its discretion) may or may not opt in the core to its achievements support.
 * whether this core is opted in to the frontend's achievement support
 * is left to the frontend's discretion.
 * @param[in] data <tt>const bool *</tt>.
 * Pointer to a single \c bool that indicates whether this core supports achievements.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * @returns \c true if the environment call is available.
 * @see RETRO_ENVIRONMENT_SET_MEMORY_MAPS
 * @see retro_get_memory_data
 */
env_callback_set_support_achievements :: proc (data: rawptr) -> bool { // DONE
    value := cast(^bool)data
    emulator_set_supports_achievements(value^)

    return true
}

/**
 * Defines an interface that the frontend can use
 * to ask the core for the parameters it needs for a hardware rendering context.
 * The exact semantics depend on \ref RETRO_ENVIRONMENT_SET_HW_RENDER "the active rendering API".
 * Will be used some time after \c RETRO_ENVIRONMENT_SET_HW_RENDER is called,
 * but before \c retro_hw_render_callback::context_reset is called.
 *
 * @param[in] data <tt>const struct retro_hw_render_context_negotiation_interface *</tt>.
 * Pointer to the context negotiation interface.
 * Will be populated by the frontend.
 * Behavior is undefined if \c NULL.
 * @return \c true if this environment call is supported,
 * even if the current graphics API doesn't use
 * a context negotiation interface (in which case the argument is ignored).
 * @see retro_hw_render_context_negotiation_interface
 * @see RETRO_ENVIRONMENT_GET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_SUPPORT
 * @see RETRO_ENVIRONMENT_SET_HW_RENDER
 */
env_callback_set_hw_render_context_negotiation_interface :: proc (data: rawptr) -> bool { // TODO
    if data == nil { return false }

    interface := (^lr.RetroHwRenderContextNegotiationInterface)(data)
    switch interface.interface_type {
    case .VULKAN:
        vk_interface := (^lr.RetroHwRenderContextNegotiationInterfaceVulkan)(data)
        assert(vk_interface.interface_type == .VULKAN)
        assert(vk_interface.interface_version <= lr.RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION)
        log.info(vk_interface)
        log.info(vk_interface.get_application_info())
    }

    return true
}

/**
 * Notifies the frontend of any quirks associated with serialization.
 *
 * Should be set in either \c retro_init or \c retro_load_game, but not both.
 * @param[in, out] data <tt>uint64_t *</tt>.
 * Pointer to the core's serialization quirks.
 * The frontend will set the flags of the quirks it supports
 * and clear the flags of those it doesn't.
 * Behavior is undefined if \c NULL.
 * @return \c true if this environment call is supported.
 * @see retro_serialize
 * @see retro_unserialize
 * @see RETRO_SERIALIZATION_QUIRK
 */
env_callback_set_serialization_quirks :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * The frontend will try to use a "shared" context when setting up a hardware context.
 * Mostly applicable to OpenGL.
 *
 * In order for this to have any effect,
 * the core must call \c RETRO_ENVIRONMENT_SET_HW_RENDER at some point
 * if it hasn't already.
 *
 * @param data Ignored.
 * @returns \c true if the environment call is available
 * and the frontend supports shared hardware contexts.
 */
env_callback_set_hw_shared_context :: proc (data: rawptr) -> bool { // DONE: This is just ignored. I want nothing to do with shared context.
    return true
}

/**
 * Returns an interface that the core can use to access the file system.
 * Should be called as early as possible.
 *
 * @param[in,out] data <tt>struct retro_vfs_interface_info *</tt>.
 * Information about the desired VFS interface,
 * as well as the interface itself.
 * Behavior is undefined if \c NULL.
 * @return \c true if this environment call is available
 * and the frontend can provide a VFS interface of the requested version or newer.
 * @see retro_vfs_interface_info
 * @see file_path
 * @see retro_dirent
 * @see file_stream
 */
env_callback_get_vfs_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns an interface that the core can use
 * to set the state of any accessible device LEDs.
 *
 * @param[out] data <tt>struct retro_led_interface *</tt>.
 * Pointer to the LED interface that the frontend will populate.
 * May be \c NULL, in which case the frontend will only return
 * whether this environment callback is available.
 * @returns \c true if the environment call is available,
 * even if \c data is \c NULL
 * or no LEDs are accessible.
 * @see retro_led_interface
 */
env_callback_get_led_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns hints about certain steps that the core may skip for this frame.
 *
 * A frontend may not need a core to generate audio or video in certain situations;
 * this environment call sets a bitmask that indicates
 * which steps the core may skip for this frame.
 *
 * This can be used to increase performance for some frontend features.
 *
 * @note Emulation accuracy should not be compromised;
 * for example, if a core emulates a platform that supports display capture
 * (i.e. looking at its own VRAM), then it should perform its rendering as normal
 * unless it can prove that the emulated game is not using display capture.
 *
 * @param[out] data <tt>retro_av_enable_flags *</tt>.
 * Pointer to the bitmask of steps that the frontend will skip.
 * Other bits are set to zero and are reserved for future use.
 * If \c NULL, the frontend will only return whether this environment callback is available.
 * @returns \c true if the environment call is available,
 * regardless of the value output to \c data.
 * If \c false, the core should assume that the frontend will not skip any steps.
 * @see retro_av_enable_flags
 */
env_callback_get_audio_video_enable :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Gets an interface that the core can use for raw MIDI I/O.
 *
 * @param[out] data <tt>struct retro_midi_interface *</tt>.
 * Pointer to the MIDI interface.
 * May be \c NULL.
 * @return \c true if the environment call is available,
 * even if \c data is \c NULL.
 * @see retro_midi_interface
 */
env_callback_get_midi_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Asks the frontend if it's currently in fast-forward mode.
 * @param[out] data <tt>bool *</tt>.
 * Set to \c true if the frontend is currently fast-forwarding its main loop.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * @returns \c true if this environment call is available,
 * regardless of the value returned in \c data.
 *
 * @see RETRO_ENVIRONMENT_SET_FASTFORWARDING_OVERRIDE
 */
env_callback_get_fastforwarding :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    (^bool)(data)^ = emulator_is_fast_forwarding()
    return true
}

/**
 * Returns the refresh rate the frontend is targeting, in Hz.
 * The intended use case is for the core to use the result to select an ideal refresh rate.
 *
 * @param[out] data <tt>float *</tt>.
 * Pointer to the \c float in which the frontend will store its target refresh rate.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * @return \c true if this environment call is available,
 * regardless of the value returned in \c data.
*/
env_callback_get_target_refresh_rate :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns whether the frontend can return the state of all buttons at once as a bitmask,
 * rather than requiring a series of individual calls to \c retro_input_state_t.
 *
 * If this callback returns \c true,
 * you can get the state of all buttons by passing \c RETRO_DEVICE_ID_JOYPAD_MASK
 * as the \c id parameter to \c retro_input_state_t.
 * Bit #N represents the RETRO_DEVICE_ID_JOYPAD constant of value N,
 * e.g. <tt>(1 << RETRO_DEVICE_ID_JOYPAD_A)</tt> represents the A button.
 *
 * @param data Ignored.
 * @returns \c true if the frontend can report the complete digital joypad state as a bitmask.
 * @see retro_input_state_t
 * @see RETRO_DEVICE_JOYPAD
 * @see RETRO_DEVICE_ID_JOYPAD_MASK
 */
env_callback_get_input_bitmasks :: proc (data: rawptr) -> bool { // DONE
    return true
}

/**
 * Returns the version of the core options API supported by the frontend.
 *
 * Over the years, libretro has used several interfaces
 * for allowing cores to define customizable options.
 * \ref SET_CORE_OPTIONS_V2 "Version 2 of the interface"
 * is currently preferred due to its extra features,
 * but cores and frontends should strive to support
 * versions \ref RETRO_ENVIRONMENT_SET_CORE_OPTIONS "1"
 * and \ref RETRO_ENVIRONMENT_SET_VARIABLES "0" as well.
 * This environment call provides the information that cores need for that purpose.
 *
 * If this environment call returns \c false,
 * then the core should assume version 0 of the core options API.
 *
 * @param[out] data <tt>unsigned *</tt>.
 * Pointer to the integer that will store the frontend's
 * supported core options API version.
 * Behavior is undefined if \c NULL.
 * @returns \c true if the environment call is available,
 * \c false otherwise.
 * @see RETRO_ENVIRONMENT_SET_VARIABLES
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2
 */
env_callback_get_core_options_version :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return false }

    (^c.int)(data)^ = 2
    return true
}

/**
 * @copybrief RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2
 *
 * @deprecated This environment call has been superseded
 * by RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2,
 * which supports categorizing options into groups.
 * This environment call should only be used to maintain compatibility
 * with older cores and frontends.
 *
 * This environment call is intended to replace \c RETRO_ENVIRONMENT_SET_VARIABLES,
 * and should only be called if \c RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION
 * returns an API version of at least 1.
 *
 * This should be called the first time as early as possible,
 * ideally in \c retro_set_environment (but \c retro_load_game is acceptable).
 * It may then be called again later to update
 * the core's options and their associated values,
 * as long as the number of options doesn't change
 * from the number given in the first call.
 *
 * The core can retrieve option values at any time with \c RETRO_ENVIRONMENT_GET_VARIABLE.
 * If a saved value for a core option doesn't match the option definition's values,
 * the frontend may treat it as incorrect and revert to the default.
 *
 * Core options and their values are usually defined in a large static array,
 * but they may be generated at runtime based on the loaded game or system state.
 * Here are some use cases for that:
 *
 * @li Selecting a particular file from one of the
 *     \ref RETRO_ENVIRONMENT_GET_ASSET_DIRECTORY "frontend's"
 *     \ref RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY "content"
 *     \ref RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY "directories",
 *     such as a memory card image or figurine data file.
 * @li Excluding options that are not relevant to the current game,
 *     for cores that define a large number of possible options.
 * @li Choosing a default value at runtime for a specific game,
 *     such as a BIOS file whose region matches that of the loaded content.
 *
 * @note A guiding principle of libretro's API design is that
 * all common interactions (gameplay, menu navigation, etc.)
 * should be possible without a keyboard.
 * This implies that cores should keep the number of options and values
 * as low as possible.
 *
 * Example entry:
 * @code
 * {
 *     "foo_option",
 *     "Speed hack coprocessor X",
 *     "Provides increased performance at the expense of reduced accuracy",
 *     {
 *         { "false",    NULL },
 *         { "true",     NULL },
 *         { "unstable", "Turbo (Unstable)" },
 *         { NULL, NULL },
 *     },
 *     "false"
 * }
 * @endcode
 *
 * @param[in] data <tt>const struct retro_core_option_definition *</tt>.
 * Pointer to one or more core option definitions,
 * terminated by a \ref retro_core_option_definition whose values are all zero.
 * May be \c NULL, in which case the frontend will remove all existing core options.
 * The frontend must maintain its own copy of this object,
 * including all strings and subobjects.
 * @return \c true if this environment call is available.
 *
 * @see retro_core_option_definition
 * @see RETRO_ENVIRONMENT_GET_VARIABLE
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL
 */
env_callback_set_core_options :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * A variant of \ref RETRO_ENVIRONMENT_SET_CORE_OPTIONS
 * that supports internationalization.
 *
 * @deprecated This environment call has been superseded
 * by \ref RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL,
 * which supports categorizing options into groups
 * (plus translating the groups themselves).
 * Only use this environment call to maintain compatibility
 * with older cores and frontends.
 *
 * This should be called instead of \c RETRO_ENVIRONMENT_SET_CORE_OPTIONS
 * if the core provides translations for its options.
 * General use is largely the same,
 * but see \ref retro_core_options_intl for some important details.
 *
 * @param[in] data <tt>const struct retro_core_options_intl *</tt>.
 * Pointer to a core's option values and their translations.
 * @see retro_core_options_intl
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS
 */
env_callback_set_core_options_intl :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Notifies the frontend that it should show or hide the named core option.
 *
 * Some core options aren't relevant in all scenarios,
 * such as a submenu for hardware rendering flags
 * when the software renderer is configured.
 * This environment call asks the frontend to stop (or start)
 * showing the named core option to the player.
 * This is only a hint, not a requirement;
 * the frontend may ignore this environment call.
 * By default, all core options are visible.
 *
 * @note This environment call must \em only affect a core option's visibility,
 * not its functionality or availability.
 * \ref RETRO_ENVIRONMENT_GET_VARIABLE "Getting an invisible core option"
 * must behave normally.
 *
 * @param[in] data <tt>const struct retro_core_option_display *</tt>.
 * Pointer to a descriptor for the option that the frontend should show or hide.
 * May be \c NULL, in which case the frontend will only return
 * whether this environment callback is available.
 * @return \c true if this environment call is available,
 * even if \c data is \c NULL
 * or the specified option doesn't exist.
 * @see retro_core_option_display
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_UPDATE_DISPLAY_CALLBACK
 */
env_callback_set_core_options_display :: proc (data: rawptr) -> bool { // DONE
    if data == nil { return true }

    opt_display := (^lr.RetroCoreOptionDisplay)(data)
    opt := emulator_get_options()
    core_option_set_visibility(opt, opt_display.key, opt_display.visible)
    return true
}

/**
 * Returns the frontend's preferred hardware rendering API.
 * Cores should use this information to decide which API to use with \c RETRO_ENVIRONMENT_SET_HW_RENDER.
 * @param[out] data <tt>retro_hw_context_type *</tt>.
 * Pointer to the hardware context type.
 * Behavior is undefined if \c data is <tt>NULL</tt>.
 * This value will be set even if the environment call returns <tt>false</tt>,
 * unless the frontend doesn't implement it.
 * @returns \c true if the environment call is available
 * and the frontend is able to use a hardware rendering API besides the one returned.
 * If \c false is returned and the core cannot use the preferred rendering API,
 * then it should exit or fall back to software rendering.
 * @note The returned value does not indicate which API is currently in use.
 * For example, the frontend may return \c RETRO_HW_CONTEXT_OPENGL
 * while a Direct3D context from a previous session is active;
 * this would signal that the frontend's current preference is for OpenGL,
 * possibly because the user changed their frontend's video driver while a game is running.
 * @see retro_hw_context_type
 * @see RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE
 * @see RETRO_ENVIRONMENT_SET_HW_RENDER
 */
env_callback_get_preferred_hw_render :: proc (data: rawptr) -> bool { // TODO: set preference according to user config
    if data == nil { return false }

    (^lr.RetroHwContextType)(data)^ = .OPENGL_CORE
    return true
}

/**
 * Returns the minimum version of the disk control interface supported by the frontend.
 *
 * If this environment call returns \c false or \c data is 0 or greater,
 * then cores may use disk control callbacks
 * with \c RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE.
 * If the reported version is 1 or greater,
 * then cores should use \c RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE instead.
 *
 * @param[out] data <tt>unsigned *</tt>.
 * Pointer to the unsigned integer that the frontend's supported disk control interface version will be stored in.
 * Behavior is undefined if \c NULL.
 * @return \c true if this environment call is available.
 * @see RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE
 */
env_callback_get_disk_control_interface_version :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * @copybrief RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE
 *
 * This is intended for multi-disk games that expect the player
 * to manually swap disks at certain points in the game.
 * This version of the disk control interface provides
 * more information about disk images.
 * Should be called in \c retro_init.
 *
 * @param[in] data <tt>const struct retro_disk_control_ext_callback *</tt>.
 * Pointer to the callback functions to use.
 * May be \c NULL, in which case the existing disk callback is deregistered.
 * @return \c true if this environment call is available,
 * even if \c data is \c NULL.
 * @see retro_disk_control_ext_callback
 */
env_callback_set_disk_control_ext_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns the version of the message interface supported by the frontend.
 *
 * A version of 0 indicates that the frontend
 * only supports the legacy \c RETRO_ENVIRONMENT_SET_MESSAGE interface.
 * A version of 1 indicates that the frontend
 * supports \c RETRO_ENVIRONMENT_SET_MESSAGE_EXT as well.
 * If this environment call returns \c false,
 * the core should behave as if it had returned 0.
 *
 * @param[out] data <tt>unsigned *</tt>.
 * Pointer to the result returned by the frontend.
 * Behavior is undefined if \c NULL.
 * @return \c true if this environment call is available.
 * @see RETRO_ENVIRONMENT_SET_MESSAGE_EXT
 * @see RETRO_ENVIRONMENT_SET_MESSAGE
 */
env_callback_get_message_interface_version :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Displays a user-facing message for a short time.
 *
 * Use this callback to convey important status messages,
 * such as errors or the result of long-running operations.
 * For trivial messages or logging, use \c RETRO_ENVIRONMENT_GET_LOG_INTERFACE or \c stderr.
 *
 * This environment call supersedes \c RETRO_ENVIRONMENT_SET_MESSAGE,
 * as it provides many more ways to customize
 * how a message is presented to the player.
 * However, a frontend that supports this environment call
 * must still support \c RETRO_ENVIRONMENT_SET_MESSAGE.
 *
 * @param[in] data <tt>const struct retro_message_ext *</tt>.
 * Pointer to the message to display to the player.
 * Behavior is undefined if \c NULL.
 * @returns \c true if this environment call is available.
 * @see retro_message_ext
 * @see RETRO_ENVIRONMENT_GET_MESSAGE_INTERFACE_VERSION
 */
env_callback_set_message_ext :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns the number of active input devices currently provided by the frontend.
 *
 * This may change between frames,
 * but will remain constant for the duration of each frame.
 *
 * If this callback returns \c true,
 * a core need not poll any input device
 * with an index greater than or equal to the returned value.
 *
 * If callback returns \c false,
 * the number of active input devices is unknown.
 * In this case, all input devices should be considered active.
 *
 * @param[out] data <tt>unsigned *</tt>.
 * Pointer to the result returned by the frontend.
 * Behavior is undefined if \c NULL.
 * @return \c true if this environment call is available.
 */
env_callback_get_input_max_users :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Registers a callback that the frontend can use to notify the core
 * of the audio output buffer's occupancy.
 * Can be used by a core to attempt frame-skipping to avoid buffer under-runs
 * (i.e. "crackling" sounds).
 *
 * @param[in] data <tt>const struct retro_audio_buffer_status_callback *</tt>.
 * Pointer to the the buffer status callback,
 * or \c NULL to unregister any existing callback.
 * @return \c true if this environment call is available,
 * even if \c data is \c NULL.
 *
 * @see retro_audio_buffer_status_callback
 */
env_callback_set_audio_buffer_status_callback :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Requests a minimum frontend audio latency in milliseconds.
 *
 * This is a hint; the frontend may assign a different audio latency
 * to accommodate hardware limits,
 * although it should try to honor requests up to 512ms.
 *
 * This callback has no effect if the requested latency
 * is less than the frontend's current audio latency.
 * If value is zero or \c data is \c NULL,
 * the frontend should set its default audio latency.
 *
 * May be used by a core to increase audio latency and
 * reduce the risk of buffer under-runs (crackling)
 * when performing 'intensive' operations.
 *
 * A core using RETRO_ENVIRONMENT_SET_AUDIO_BUFFER_STATUS_CALLBACK
 * to implement audio-buffer-based frame skipping can get good results
 * by setting the audio latency to a high (typically 6x or 8x)
 * integer multiple of the expected frame time.
 *
 * This can only be called from within \c retro_run().
 *
 * @warning This environment call may require the frontend to reinitialize its audio system.
 * This environment call should be used sparingly.
 * If the driver is reinitialized,
 * \ref retro_audio_callback_t "all audio callbacks" will be updated
 * to target the newly-initialized driver.
 *
 * @param[in] data <tt>const unsigned *</tt>.
 * Minimum audio latency, in milliseconds.
 * @return \c true if this environment call is available,
 * even if \c data is \c NULL.
 *
 * @see RETRO_ENVIRONMENT_SET_AUDIO_BUFFER_STATUS_CALLBACK
 */
env_callback_set_minimum_audio_latency :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Allows the core to tell the frontend when it should enable fast-forwarding,
 * rather than relying solely on the frontend and user interaction.
 *
 * Possible use cases include:
 *
 * \li Temporarily disabling a core's fastforward support
 *     while investigating a related bug.
 * \li Disabling fastforward during netplay sessions,
 *     or when using an emulated console's network features.
 * \li Automatically speeding up the game when in a loading screen
 *     that cannot be shortened with high-level emulation.
 *
 * @param[in] data <tt>const struct retro_fastforwarding_override *</tt>.
 * Pointer to the parameters that decide when and how
 * the frontend is allowed to enable fast-forward mode.
 * May be \c NULL, in which case the frontend will return \c true
 * without updating the fastforward state,
 * which can be used to detect support for this environment call.
 * @return \c true if this environment call is available,
 * even if \c data is \c NULL.
 *
 * @see retro_fastforwarding_override
 * @see RETRO_ENVIRONMENT_GET_FASTFORWARDING
 */
env_callback_set_fastforwarding_override :: proc (data: rawptr) -> bool { // TODO
    return false
}

/* const struct retro_system_content_info_override * --
 * Allows an implementation to override 'global' content
 * info parameters reported by retro_get_system_info().
 * Overrides also affect subsystem content info parameters
 * set via RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO.
 * This function must be called inside retro_set_environment().
 * If callback returns false, content info overrides
 * are unsupported by the frontend, and will be ignored.
 * If callback returns true, extended game info may be
 * retrieved by calling RETRO_ENVIRONMENT_GET_GAME_INFO_EXT
 * in retro_load_game() or retro_load_game_special().
 *
 * 'data' points to an array of retro_system_content_info_override
 * structs terminated by a { NULL, false, false } element.
 * If 'data' is NULL, no changes will be made to the frontend;
 * a core may therefore pass NULL in order to test whether
 * the RETRO_ENVIRONMENT_SET_CONTENT_INFO_OVERRIDE and
 * RETRO_ENVIRONMENT_GET_GAME_INFO_EXT callbacks are supported
 * by the frontend.
 *
 * For struct member descriptions, see the definition of
 * struct retro_system_content_info_override.
 *
 * Example:
 *
 * - struct retro_system_info:
 * {
 *    "My Core",                      // library_name
 *    "v1.0",                         // library_version
 *    "m3u|md|cue|iso|chd|sms|gg|sg", // valid_extensions
 *    true,                           // need_fullpath
 *    false                           // block_extract
 * }
 *
 * - Array of struct retro_system_content_info_override:
 * {
 *    {
 *       "md|sms|gg", // extensions
 *       false,       // need_fullpath
 *       true         // persistent_data
 *    },
 *    {
 *       "sg",        // extensions
 *       false,       // need_fullpath
 *       false        // persistent_data
 *    },
 *    { NULL, false, false }
 * }
 *
 * Result:
 * - Files of type m3u, cue, iso, chd will not be
 *   loaded by the frontend. Frontend will pass a
 *   valid path to the core, and core will handle
 *   loading internally
 * - Files of type md, sms, gg will be loaded by
 *   the frontend. A valid memory buffer will be
 *   passed to the core. This memory buffer will
 *   remain valid until retro_deinit() returns
 * - Files of type sg will be loaded by the frontend.
 *   A valid memory buffer will be passed to the core.
 *   This memory buffer will remain valid until
 *   retro_load_game() (or retro_load_game_special())
 *   returns
 *
 * NOTE: If an extension is listed multiple times in
 * an array of retro_system_content_info_override
 * structs, only the first instance will be registered
 */
env_callback_set_content_info_override :: proc (data: rawptr) -> bool { // TODO
    return false
}

/* const struct retro_game_info_ext ** --
 * Allows an implementation to fetch extended game
 * information, providing additional content path
 * and memory buffer status details.
 * This function may only be called inside
 * retro_load_game() or retro_load_game_special().
 * If callback returns false, extended game information
 * is unsupported by the frontend. In this case, only
 * regular retro_game_info will be available.
 * RETRO_ENVIRONMENT_GET_GAME_INFO_EXT is guaranteed
 * to return true if RETRO_ENVIRONMENT_SET_CONTENT_INFO_OVERRIDE
 * returns true.
 *
 * 'data' points to an array of retro_game_info_ext structs.
 *
 * For struct member descriptions, see the definition of
 * struct retro_game_info_ext.
 *
 * - If function is called inside retro_load_game(),
 *   the retro_game_info_ext array is guaranteed to
 *   have a size of 1 - i.e. the returned pointer may
 *   be used to access directly the members of the
 *   first retro_game_info_ext struct, for example:
 *
 *      struct retro_game_info_ext *game_info_ext;
 *      if (environ_cb(RETRO_ENVIRONMENT_GET_GAME_INFO_EXT, &game_info_ext))
 *         printf("Content Directory: %s\n", game_info_ext->dir);
 *
 * - If the function is called inside retro_load_game_special(),
 *   the retro_game_info_ext array is guaranteed to have a
 *   size equal to the num_info argument passed to
 *   retro_load_game_special()
 */
env_callback_get_game_info_ext :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Defines a set of core options that can be shown and configured by the frontend,
 * so that the player may customize their gameplay experience to their liking.
 *
 * @note This environment call is intended to replace
 * \c RETRO_ENVIRONMENT_SET_VARIABLES and \c RETRO_ENVIRONMENT_SET_CORE_OPTIONS,
 * and should only be called if \c RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION
 * returns an API version of at least 2.
 *
 * This should be called the first time as early as possible,
 * ideally in \c retro_set_environment (but \c retro_load_game is acceptable).
 * It may then be called again later to update
 * the core's options and their associated values,
 * as long as the number of options doesn't change
 * from the number given in the first call.
 *
 * The core can retrieve option values at any time with \c RETRO_ENVIRONMENT_GET_VARIABLE.
 * If a saved value for a core option doesn't match the option definition's values,
 * the frontend may treat it as incorrect and revert to the default.
 *
 * Core options and their values are usually defined in a large static array,
 * but they may be generated at runtime based on the loaded game or system state.
 * Here are some use cases for that:
 *
 * @li Selecting a particular file from one of the
 *     \ref RETRO_ENVIRONMENT_GET_ASSET_DIRECTORY "frontend's"
 *     \ref RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY "content"
 *     \ref RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY "directories",
 *     such as a memory card image or figurine data file.
 * @li Excluding options that are not relevant to the current game,
 *     for cores that define a large number of possible options.
 * @li Choosing a default value at runtime for a specific game,
 *     such as a BIOS file whose region matches that of the loaded content.
 *
 * @note A guiding principle of libretro's API design is that
 * all common interactions (gameplay, menu navigation, etc.)
 * should be possible without a keyboard.
 * This implies that cores should keep the number of options and values
 * as low as possible.
 *
 * @param[in] data <tt>const struct retro_core_options_v2 *</tt>.
 * Pointer to a core's options and their associated categories.
 * May be \c NULL, in which case the frontend will remove all existing core options.
 * The frontend must maintain its own copy of this object,
 * including all strings and subobjects.
 * @return \c true if this environment call is available
 * and the frontend supports categories.
 * Note that this environment call is guaranteed to successfully register
 * the provided core options,
 * so the return value does not indicate success or failure.
 *
 * @see retro_core_options_v2
 * @see retro_core_option_v2_category
 * @see retro_core_option_v2_definition
 * @see RETRO_ENVIRONMENT_GET_VARIABLE
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL
 */
env_callback_set_core_options_v2 :: proc (data: rawptr) -> bool { // TODO: Support categories
    if data == nil {
        emulator_clear_options()
    } else {
        opt := core_options_parse_v2((^lr.RetroCoreOptionsV2)(data))
        emulator_set_options(opt)
    }

    return true
}

/**
 * A variant of \ref RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2
 * that supports internationalization.
 *
 * This should be called instead of \c RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2
 * if the core provides translations for its options.
 * General use is largely the same,
 * but see \ref retro_core_options_v2_intl for some important details.
 *
 * @param[in] data <tt>const struct retro_core_options_v2_intl *</tt>.
 * Pointer to a core's option values and categories,
 * plus a translation for each option and category.
 * @see retro_core_options_v2_intl
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2
 */
env_callback_set_core_options_v2_intl :: proc (data: rawptr) -> bool { // TODO: use local language when appropriate
    if data == nil {
        emulator_clear_options()
    } else {
        opt := core_options_parse_v2_intl((^lr.RetroCoreOptionsV2Intl)(data))
        emulator_set_options(opt)
    }

    return true
}

/**
 * Registers a callback that the frontend can use
 * to notify the core that at least one core option
 * should be made hidden or visible.
 * Allows a frontend to signal that a core must update
 * the visibility of any dynamically hidden core options,
 * and enables the frontend to detect visibility changes.
 * Used by the frontend to update the menu display status
 * of core options without requiring a call of retro_run().
 * Must be called in retro_set_environment().
 *
 * @param[in] data <tt>const struct retro_core_options_update_display_callback *</tt>.
 * The callback that the frontend should use.
 * May be \c NULL, in which case the frontend will unset any existing callback.
 * Can be used to query visibility support.
 * @return \c true if this environment call is available,
 * even if \c data is \c NULL.
 * @see retro_core_options_update_display_callback
 */
env_callback_set_core_options_update_display_callback :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Forcibly sets a core option's value.
 *
 * After changing a core option value with this callback,
 * it will be reflected in the frontend
 * and \ref RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE will return \c true.
 * \ref retro_variable::key must match
 * a \ref RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2 "previously-set core option",
 * and \ref retro_variable::value must match one of its defined values.
 *
 * Possible use cases include:
 *
 * @li Allowing the player to set certain core options
 *     without entering the frontend's option menu,
 *     using an in-core hotkey.
 * @li Adjusting invalid combinations of settings.
 * @li Migrating settings from older releases of a core.
 *
 * @param[in] data <tt>const struct retro_variable *</tt>.
 * Pointer to a single option that the core is changing.
 * May be \c NULL, in which case the frontend will return \c true
 * to indicate that this environment call is available.
 * @return \c true if this environment call is available
 * and the option named by \c key was successfully
 * set to the given \c value.
 * \c false if the \c key or \c value fields are \c NULL, empty,
 * or don't match a previously set option.
 *
 * @see RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2
 * @see RETRO_ENVIRONMENT_GET_VARIABLE
 * @see RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE
 */
env_callback_set_variable :: proc (data: rawptr) -> bool { // TODO
    return false
}

/* struct retro_throttle_state * --
 * Allows an implementation to get details on the actual rate
 * the frontend is attempting to call retro_run().
 */
env_callback_get_throttle_state :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns information about how the frontend will use savestates.
 *
 * @param[out] data <tt>retro_savestate_context *</tt>.
 * Pointer to the current savestate context.
 * May be \c NULL, in which case the environment call
 * will return \c true to indicate its availability.
 * @returns \c true if the environment call is available,
 * even if \c data is \c NULL.
 * @see retro_savestate_context
 */
env_callback_get_savestate_context :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Before calling \c SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE, will query which interface is supported.
 *
 * Frontend looks at \c retro_hw_render_interface_type and returns the maximum supported
 * context negotiation interface version. If the \c retro_hw_render_interface_type is not
 * supported or recognized by the frontend, a version of 0 must be returned in
 * \c retro_hw_render_interface's \c interface_version and \c true is returned by frontend.
 *
 * If this environment call returns true with a \c interface_version greater than 0,
 * a core can always use a negotiation interface version larger than what the frontend returns,
 * but only earlier versions of the interface will be used by the frontend.
 *
 * A frontend must not reject a negotiation interface version that is larger than what the
 * frontend supports. Instead, the frontend will use the older entry points that it recognizes.
 * If this is incompatible with a particular core's requirements, it can error out early.
 *
 * @note Regarding backwards compatibility, this environment call was introduced after Vulkan v1
 * context negotiation. If this environment call is not supported by frontend, i.e. the environment
 * call returns \c false , only Vulkan v1 context negotiation is supported (if Vulkan HW rendering
 * is supported at all). If a core uses Vulkan negotiation interface with version > 1, negotiation
 * may fail unexpectedly. All future updates to the context negotiation interface implies that
 * frontend must support this environment call to query support.
 *
 * @param[out] data <tt>struct retro_hw_render_context_negotiation_interface *</tt>.
 * @return \c true if the environment call is available.
 * @see SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE
 * @see retro_hw_render_interface_type
 * @see retro_hw_render_context_negotiation_interface
 */
env_callback_get_hw_render_context_negotiation_interface_support :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Asks the frontend whether JIT compilation can be used.
 * Primarily used by iOS and tvOS.
 * @param[out] data <tt>bool *</tt>.
 * Set to \c true if the frontend has verified that JIT compilation is possible.
 * @return \c true if the environment call is available.
 */
env_callback_get_jit_capable :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns an interface that the core can use to receive microphone input.
 *
 * @param[out] data <tt>retro_microphone_interface *</tt>.
 * Pointer to the microphone interface.
 * @return \true if microphone support is available,
 * even if no microphones are plugged in.
 * \c false if microphone support is disabled unavailable,
 * or if \c data is \c NULL.
 * @see retro_microphone_interface
 */
env_callback_get_microphone_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns the device's current power state as reported by the frontend.
 *
 * This is useful for emulating the battery level in handheld consoles,
 * or for reducing power consumption when on battery power.
 *
 * @note This environment call describes the power state for the entire device,
 * not for individual peripherals like controllers.
 *
 * @param[out] data <struct retro_device_power *>.
 * Indicates whether the frontend can provide this information, even if the parameter
 * is \c NULL. If the frontend does not support this functionality, then the provided
 * argument will remain unchanged.
 * @return \c true if the environment call is available.
 * @see retro_device_power
 */
env_callback_get_device_power :: proc (data: rawptr) -> bool { // TODO
    return false
}

/* const struct retro_netpacket_callback * --
 * When set, a core gains control over network packets sent and
 * received during a multiplayer session. This can be used to
 * emulate multiplayer games that were originally played on two
 * or more separate consoles or computers connected together.
 *
 * The frontend will take care of connecting players together,
 * and the core only needs to send the actual data as needed for
 * the emulation, while handshake and connection management happen
 * in the background.
 *
 * When two or more players are connected and this interface has
 * been set, time manipulation features (such as pausing, slow motion,
 * fast forward, rewinding, save state loading, etc.) are disabled to
 * avoid interrupting communication.
 *
 * Should be set in either retro_init or retro_load_game, but not both.
 *
 * When not set, a frontend may use state serialization-based
 * multiplayer, where a deterministic core supporting multiple
 * input devices does not need to take any action on its own.
 */
env_callback_set_netpacket_interface :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns the "playlist" directory of the frontend.
 *
 * This directory can be used to store core generated playlists, in case
 * this internal functionality is available (e.g. internal core game detection
 * engine).
 *
 * @param[out] data <tt>const char **</tt>.
 * May be \c NULL. If so, no such directory is defined, and it's up to the
 * implementation to find a suitable directory.
 * @return \c true if the environment call is available.
 */
env_callback_get_playlist_directory :: proc (data: rawptr) -> bool { // TODO
    return false
}

/**
 * Returns the "file browser" start directory of the frontend.
 *
 * This directory can serve as a start directory for the core in case it
 * provides an internal way of loading content.
 *
 * @param[out] data <tt>const char **</tt>.
 * May be \c NULL. If so, no such directory is defined, and it's up to the
 * implementation to find a suitable directory.
 * @return \c true if the environment call is available.
 */
env_callback_get_file_browser_start_directory :: proc (data: rawptr) -> bool { // TODO
    return false
}
