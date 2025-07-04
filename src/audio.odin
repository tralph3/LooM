package main

import cb "circular_buffer"
import sdl "vendor:sdl3"
import "core:c"
import "core:log"
import "core:mem"

@(private="file")
AUDIO_STATE := struct #no_copy {
    buffer: cb.CircularBuffer(AUDIO_BUFFER_SIZE_BYTES),
    stream: ^sdl.AudioStream,
} {}

BYTES_PER_FRAME :: 4

AUDIO_BUFFER_SIZE_BYTES :: 1024 * 8
AUDIO_BUFFER_UNDERRUN_LIMIT :: 1024 * 1
AUDIO_BUFFER_OVERFLOW_LIMIT :: 1024 * 7

audio_buffer_push_batch :: proc "c" (src: ^i16, frames: i32) -> i32 {
    context = state_get_context()

    expected_frames := f64(emulator_get_audio_sample_rate()) / emulator_get_fps()
    diff := f64(frames) / expected_frames
    sdl.SetAudioStreamFrequencyRatio(AUDIO_STATE.stream, f32(diff - 1))

    sdl.PutAudioStreamData(AUDIO_STATE.stream, src, frames * BYTES_PER_FRAME)

    return frames
}

audio_buffer_pop_batch :: proc "c" (userdata: rawptr, stream: ^sdl.AudioStream, additional_amount, total_amount: c.int) {
    context = state_get_context()

    buffered_bytes := int(AUDIO_STATE.buffer.size)
    if buffered_bytes < AUDIO_BUFFER_UNDERRUN_LIMIT {
        return
    }

    cb.pop_to_audio_stream(&AUDIO_STATE.buffer, AUDIO_STATE.stream, u64(additional_amount))
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

audio_is_under_overrun_limit :: proc () -> bool {
    buffered_bytes := (AUDIO_STATE.buffer.size)
    return buffered_bytes < AUDIO_BUFFER_OVERFLOW_LIMIT
}

audio_deinit :: proc () {
    // This also destroys the bound device because it was created with
    // OpenAudioDeviceStream
    sdl.DestroyAudioStream(AUDIO_STATE.stream)
}

audio_clear_buffer :: proc () {
    cb.clear(&AUDIO_STATE.buffer)
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
