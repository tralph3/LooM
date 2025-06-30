package main

import lr "libretro"
import cl "clay"
import "base:runtime"

GLOBAL_STATE := struct #no_copy {
    current_user: string,
    gui_state: GuiState,
    gui_renderer_state: GuiRendererState,
    video_state: VideoState,
    audio_state: AudioState,
    input_state: InputState,
    emulator_state: EmulatorState,
    user_state: UserState,

    game_entries: [dynamic]GameEntry,

    config: Config,

    current_scene_id: SceneID,

    frame_counter: u64,

    event_offset: u32,

    ctx: runtime.Context,
} {
    current_scene_id = .LOGIN,
}
