package main

import lr "libretro"
import cl "clay"
import "base:runtime"

GLOBAL_STATE := struct #no_copy {
    current_user: string,
    gui_state: GuiState,
    video_state: VideoState,
    audio_state: AudioState,
    input_state: InputState,
    emulator_state: EmulatorState,

    current_scene_id: SceneID,

    should_exit: bool,

    ctx: runtime.Context,
} {
    current_scene_id = .RUNNING,
}
