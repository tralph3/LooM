package main

import cb "circular_buffer"
import sdl "vendor:sdl3"
import "core:c"
import "core:log"
import "core:mem"
import "core:slice"

@(private="file")
AUDIO_STATE := struct #no_copy {
    buffer: cb.CircularBuffer(AUDIO_BUFFER_SIZE_BYTES),
    stream: ^sdl.AudioStream,
    effects_streams: [10]^sdl.AudioStream,
    stream_index: int,
} {}

BYTES_PER_FRAME :: 4

AUDIO_BUFFER_SIZE_BYTES :: 1024 * 64
AUDIO_BUFFER_UNDERRUN_LIMIT :: 1024 * 12
AUDIO_BUFFER_OVERFLOW_LIMIT :: 1024 * 54

audio_buffer_push_batch :: proc "c" (src: [^]i16, frames: i32) -> i32 {
    context = state_get_context()
    bytes_pushed := cb.push(&AUDIO_STATE.buffer, src, u64(frames * BYTES_PER_FRAME))

    return i32(bytes_pushed / BYTES_PER_FRAME)
}

audio_buffer_pop_batch :: proc "c" (userdata: rawptr, stream: ^sdl.AudioStream, additional_amount, total_amount: c.int) {
    context = state_get_context()

    buffered_bytes := int(AUDIO_STATE.buffer.size)
    if buffered_bytes < AUDIO_BUFFER_UNDERRUN_LIMIT {
        return
    }

    cb.pop_to_audio_stream(&AUDIO_STATE.buffer, AUDIO_STATE.stream, u64(additional_amount))
}

audio_init :: proc () -> (ok: bool) {
    context = state_get_context()

    AUDIO_STATE.stream = sdl.OpenAudioDeviceStream(
        sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK,
        &{
            format = .S16LE,
            channels = 2,
            freq = 48000,
        },
        audio_buffer_pop_batch,
        nil,
    )
    if AUDIO_STATE.stream == nil {
        log.errorf("Failed creating audio device: {}", sdl.GetError())
        return false
    }

    for &stream in AUDIO_STATE.effects_streams {
        stream = sdl.OpenAudioDeviceStream(
            sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK,
                &{
                    format = .S16LE,
                    channels = 2,
                    freq = 48000,
                },
            nil,
            nil,
        )
        if stream == nil {
            log.errorf("Failed creating audio stream: {}", sdl.GetError())
            return false
        }
        sdl.ResumeAudioStreamDevice(stream)
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

    for stream in AUDIO_STATE.effects_streams {
        sdl.DestroyAudioStream(stream)
    }


}

audio_clear_buffer :: proc () {
    cb.clear(&AUDIO_STATE.buffer)
}

// Return the amount of nanoseconds the emulator should sleep for to
// avoid filling the audio buffer.
audio_should_sleep_for :: proc () -> (res: u64) {
    if GLOBAL_STATE.current_scene_id != .RUNNING {
        return 0
    }

    buffered_bytes := AUDIO_STATE.buffer.size
    if buffered_bytes <= AUDIO_BUFFER_OVERFLOW_LIMIT {
        return 0
    }

    // we want to get back to the underrun limit so we don't sleep
    // frequently
    overflow_bytes := buffered_bytes - AUDIO_BUFFER_OVERFLOW_LIMIT

    // 48000 samples/sec * 2 channels * 2 bytes = 192000 bytes/sec
    // 192000 bytes/sec = 1_000_000_000 ns / 192000 = 5208.333... ns/byte
    return overflow_bytes * 5208
}

audio_get_buffer_fill_rate :: proc () -> f32 {
    buffered_bytes := AUDIO_STATE.buffer.size
    return f32(buffered_bytes) / AUDIO_BUFFER_SIZE_BYTES
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

audio_play_sound :: proc (id: SoundID) {
    if AUDIO_STATE.stream_index >= len(AUDIO_STATE.effects_streams) {
        AUDIO_STATE.stream_index = 0
    }

    sound := assets_get_sound(id)
    sdl.PutAudioStreamData(
        AUDIO_STATE.effects_streams[AUDIO_STATE.stream_index],
        raw_data(sound),
        i32(len(sound)))

    AUDIO_STATE.stream_index += 1
}
