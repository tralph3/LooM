package main

import "core:strings"
import "core:slice"
import sdl "vendor:sdl3"
import cl "clay"

MAX_NOTIFICATIONS :: 32

@(private="file")
NOTIFICATIONS := struct {
    arr: [MAX_NOTIFICATIONS]Notification,
    count: u32,
} {}

Notification :: struct {
    message: string,
    created_at: u64,
    duration_ms: u64,
}

notifications_add :: proc (message: string, duration_ms: u64) {
    count: ^u32 = &NOTIFICATIONS.count
    if count^ == MAX_NOTIFICATIONS {
        idx := notifications_get_earliest_index()
        notifications_remove(idx)
    }

    NOTIFICATIONS.arr[count^] = {
        message=strings.clone(message),
        duration_ms=duration_ms,
        created_at=sdl.GetTicks(),
    }
    count^ += 1
}

notifications_evict :: proc () {
    current_time := sdl.GetTicks()
    for i in 0..<NOTIFICATIONS.count {
        notification := NOTIFICATIONS.arr[i]
        elapsed := current_time - notification.created_at
        if elapsed < notification.duration_ms { continue }
        notifications_remove(i)
    }
}

notifications_remove :: proc (index: u32) {
    notification := NOTIFICATIONS.arr[index]
    delete(notification.message)
    NOTIFICATIONS.count -= 1
    NOTIFICATIONS.arr[index] = NOTIFICATIONS.arr[NOTIFICATIONS.count]
}

notifications_get_earliest_index :: proc () -> u32 {
    earliest_creation_time := max(u64)
    earliest_creation_index: u32 = 0
    for i in 0..<NOTIFICATIONS.count {
        if NOTIFICATIONS.arr[i].created_at >= earliest_creation_time { continue }
        earliest_creation_time = NOTIFICATIONS.arr[i].created_at
        earliest_creation_index = i
    }

    return earliest_creation_index
}

notifications_layout :: proc () {
    if cl.UI()({
        layout = {
            sizing = {
                width = cl.SizingFit({}),
                height = cl.SizingGrow({}),
            },
            childAlignment = {
                y = .Bottom,
            },
            layoutDirection = .TopToBottom,
            padding = cl.Padding {
                left = UI_SPACING_48,
                bottom = UI_SPACING_48,
            },
        },
        floating = {
	        attachment = {
                element = .LeftTop,
                parent = .LeftTop,
            },
            attachTo = .Root,
            pointerCaptureMode = .Passthrough,
        },
        backgroundColor = {},
    }) {
        for i in 0..<NOTIFICATIONS.count {
            notification := NOTIFICATIONS.arr[i]

            if cl.UI()({
                id = cl.ID("Notification", i),
                layout = {
                    sizing = {
                        width = cl.SizingFixed(630),
                        height = cl.SizingFit({ min = 120}),
                    },
                    childAlignment = {
                        y = .Center,
                    },
                    padding = cl.PaddingAll(UI_SPACING_24),
                },
                backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
            }) {
                cl.TextDynamic(notification.message, cl.TextConfig({
                    textColor = UI_COLOR_MAIN_TEXT,
                    fontSize = 32,
                }))
            }
        }
    }
}

notifications_evict_and_layout :: proc () {
    notifications_evict()
    notifications_layout()
}
