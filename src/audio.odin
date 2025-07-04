package main

import sdl "vendor:sdl3"
import "core:c"
import "core:log"
import "core:mem"

@(private="file")
AUDIO_STATE := struct #no_copy {
    stream: ^sdl.AudioStream,
} {}

BYTES_PER_FRAME :: 4

audio_buffer_push_batch :: proc "c" (src: ^i16, frames: i32) -> i32 {
    expected_frames := f32(emulator_get_audio_sample_rate()) / f32(emulator_get_fps())
    diff := f32(frames) / expected_frames
    sdl.SetAudioStreamFrequencyRatio(AUDIO_STATE.stream, diff)

    sdl.PutAudioStreamData(AUDIO_STATE.stream, src, frames * BYTES_PER_FRAME)

    return frames
}

audio_init :: proc "c" () -> (ok: bool) {
    context = state_get_context()

    AUDIO_STATE.stream = sdl.OpenAudioDeviceStream(
        sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK,
        &{
            format = .S16LE,
            channels = 2,
            freq = 48000,
        },
        nil,
        nil,
    )
    if AUDIO_STATE.stream == nil {
        log.errorf("Failed creating audio device: {}", sdl.GetError())
        return false
    }

    return true
}

audio_set_src_rample_rate :: proc (new_sample_rate: i32) {
    src_spec: sdl.AudioSpec
    sdl.GetAudioStreamFormat(AUDIO_STATE.stream, &src_spec, nil)

    src_spec.freq = new_sample_rate
    sdl.SetAudioStreamFormat(AUDIO_STATE.stream, &src_spec, nil)
}

audio_deinit :: proc () {
    // This also destroys the bound device because it was created with
    // OpenAudioDeviceStream
    sdl.DestroyAudioStream(AUDIO_STATE.stream)
}

audio_clear_buffer :: proc () {
    if !sdl.ClearAudioStream(AUDIO_STATE.stream) {
        log.errorf("Failed clearing audio stream: {}", sdl.GetError())
    }
}

audio_resume :: proc () {
    if !sdl.ResumeAudioStreamDevice(AUDIO_STATE.stream) {
        log.errorf("Failed resuming audio stream: {}", sdl.GetError())
    }
}

audio_pause :: proc () {
    if !sdl.PauseAudioStreamDevice(AUDIO_STATE.stream) {
        log.errorf("Failed pausing audio stream: {}", sdl.GetError())
    }
}
