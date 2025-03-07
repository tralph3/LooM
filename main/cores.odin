package main

import lr "libretro"
import rl "vendor:raylib"
import cb "circular_buffer"

run_game :: proc (core_path: string, rom_path: string) {
    unload_core()

    core, ok_load_core := lr.load_core(core_path)
    if !ok_load_core { return }

    callbacks := lr.Callbacks {
        environment = process_env_callback,
        video_refresh = video_refresh_callback,
        input_poll = input_poll_callback,
        input_state = input_state_callback,
        audio_sample = audio_sample_callback,
        audio_sample_batch = audio_sample_batch_callback,
    }

    lr.initialize_core(&core, &callbacks)

    ok_load_rom := lr.load_rom(&core, rom_path)
    if !ok_load_rom { return }

    STATE.core = core

    av_info := lr.SystemAvInfo{}
    core.api.get_system_av_info(&av_info)
    STATE.av_info = av_info

    render_texture_init()
    audio_buffer_init()

    STATE.state = .RUNNING
}

unload_core :: proc () {
    if STATE.core.loaded {
        lr.unload_core(STATE.core)
        rl.UnloadTexture(STATE.video.render_texture)
        rl.UnloadAudioStream(STATE.audio.stream)
        cb.circular_buffer_clear(&STATE.audio.buffer)
    }
}
