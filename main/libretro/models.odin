package libretro

import "core:c"

RETRO_NUM_CORE_OPTION_VALUES_MAX :: 128

Callbacks :: struct {
    environment: proc "c" (RetroEnvironment, rawptr) -> bool,
    video_refresh: proc "c" (rawptr, u32, u32, u32),
    input_poll: proc "c" (),
    input_state: proc "c" (u32, u32, u32, u32) -> i16,
    audio_sample: proc "c" (i16, i16),
    audio_sample_batch: proc "c" (^i16, i32) -> i32,
}

GameGeometry :: struct {
    base_width: c.uint,
    base_height: c.uint,
    max_width: c.uint,
    max_height: c.uint,
    aspect_ratio: c.float,
}

SystemTiming :: struct {
    fps: c.double,
    sample_rate: c.double,
}

SystemAvInfo :: struct {
    geometry: GameGeometry,
    timing: SystemTiming,
}

GameInfo :: struct {
    path: cstring,
    data: rawptr,
    size: int,
    meta: cstring,
}

RetroEnvironment :: enum {
    Experimental                                  = 0x10000,
    Private                                       = 0x20000,
    SetRotation                                   = 1,
    GetOverscan                                   = 2,
    GetCanDupe                                    = 3,
    SetMessage                                    = 6,
    Shutdown                                      = 7,
    SetPerformanceLevel                           = 8,
    GetSystemDirectory                            = 9,
    SetPixelFormat                                = 10,
    SetInputDescriptors                           = 11,
    SetKeyboardCallback                           = 12,
    SetDiskControlInterface                       = 13,
    SetHwRender                                   = 14,
    GetVariable                                   = 15,
    SetVariables                                  = 16,
    GetVariableUpdate                             = 17,
    SetSupportNoGame                              = 18,
    GetLibretroPath                               = 19,
    SetFrameTimeCallback                          = 21,
    SetAudioCallback                              = 22,
    GetRumbleInterface                            = 23,
    GetInputDeviceCapabilities                    = 24,
    GetSensorInterface                            = (25 | Experimental),
    GetCameraInterface                            = (26 | Experimental),
    GetLogInterface                               = 27,
    GetPerfInterface                              = 28,
    GetLocationInterface                          = 29,
    GetContentDirectory                           = 30,
    GetCoreAssetsDirectory                        = 30,
    GetSaveDirectory                              = 31,
    SetSystemAvInfo                               = 32,
    SetProcAddressCallback                        = 33,
    SetSubsystemInfo                              = 34,
    SetControllerInfo                             = 35,
    SetMemoryMaps                                 = (36 | Experimental),
    SetGeometry                                   = 37,
    GetUsername                                   = 38,
    GetLanguage                                   = 39,
    GetCurrentSoftwareFramebuffer                 = (40 | Experimental),
    GetHwRenderInterface                          = (41 | Experimental),
    SetSupportAchievements                        = (42 | Experimental),
    SetHwRenderContextNegotiationInterface        = (43 | Experimental),
    SetSerializationQuirks                        = 44,
    SetHwSharedContext                            = (44 | Experimental),
    GetVfsInterface                               = (45 | Experimental),
    GetLedInterface                               = (46 | Experimental),
    GetAudioVideoEnable                           = (47 | Experimental),
    GetMidiInterface                              = (48 | Experimental),
    GetFastforwarding                             = (49 | Experimental),
    GetTargetRefreshRate                          = (50 | Experimental),
    GetInputBitmasks                              = (51 | Experimental),
    GetCoreOptionsVersion                         = 52,
    SetCoreOptions                                = 53,
    SetCoreOptionsIntl                            = 54,
    SetCoreOptionsDisplay                         = 55,
    GetPreferredHwRender                          = 56,
    GetDiskControlInterfaceVersion                = 57,
    SetDiskControlExtInterface                    = 58,
    GetMessageInterfaceVersion                    = 59,
    SetMessageExt                                 = 60,
    GetInputMaxUsers                              = 61,
    SetAudioBufferStatusCallback                  = 62,
    SetMinimumAudioLatency                        = 63,
    SetFastforwardingOverride                     = 64,
    SetContentInfoOverride                        = 65,
    GetGameInfoExt                                = 66,
    SetCoreOptionsV2                              = 67,
    SetCoreOptionsV2Intl                          = 68,
    SetCoreOptionsUpdateDisplayCallback           = 69,
    SetVariable                                   = 70,
    GetThrottleState                              = (71 | Experimental),
    GetSavestateContext                           = (72 | Experimental),
    GetHwRenderContextNegotiationInterfaceSupport = (73 | Experimental),
    GetJitCapable                                 = 74,
    GetMicrophoneInterface                        = (75 | Experimental),
    GetDevicePower                                = (77 | Experimental),
    SetNetpacketInterface                         = 78,
    GetPlaylistDirectory                          = 79,
    GetFileBrowserStartDirectory                  = 80,
}

RetroDevice :: enum {
    IdJoypadB      =  0,
    IdJoypadY      =  1,
    IdJoypadSelect =  2,
    IdJoypadStart  =  3,
    IdJoypadUp     =  4,
    IdJoypadDown   =  5,
    IdJoypadLeft   =  6,
    IdJoypadRight  =  7,
    IdJoypadA      =  8,
    IdJoypadX      =  9,
    IdJoypadL      = 10,
    IdJoypadR      = 11,
    IdJoypadL2     = 12,
    IdJoypadR2     = 13,
    IdJoypadL3     = 14,
    IdJoypadR3     = 15,
}

RetroPixelFormat :: enum {
   F0RGB1555 = 0,
   FXRGB8888 = 1,
   FRGB565   = 2,
}

RetroVariable :: struct {
    key: cstring,
    value: cstring,
}

RetroCoreOptionValue :: struct {
    value: cstring,
    label: cstring,
}

RetroCoreOptionV2Definition :: struct {
    key: cstring,
    display: cstring,
    display_categorized: cstring,
    info: cstring,
    info_categorized: cstring,
    category_key: cstring,
    values: [RETRO_NUM_CORE_OPTION_VALUES_MAX]RetroCoreOptionValue,
    default_value: cstring,
}

RetroCoreOptionV2Category :: struct {
    key: cstring,
    display: cstring,
    info: cstring
}

RetroCoreOptionsV2 :: struct {
    categories: [^]RetroCoreOptionV2Category,
    definitions: [^]RetroCoreOptionV2Definition,
}

RetroCoreOptionsV2Intl :: struct {
    us: ^RetroCoreOptionsV2,
    local: ^RetroCoreOptionsV2,
}

RetroLanguage :: enum {
   English            = 0,
   Japanese           = 1,
   French             = 2,
   Spanish            = 3,
   German             = 4,
   Italian            = 5,
   Dutch              = 6,
   PortugueseBrazil   = 7,
   PortuguesePortugal = 8,
   Russian            = 9,
   Korean             = 10,
   ChineseTraditional = 11,
   ChineseSimplified  = 12,
   Esperanto          = 13,
   Polish             = 14,
   Vietnamese         = 15,
   Arabic             = 16,
   Greek              = 17,
   Turkish            = 18,
   Slovak             = 19,
   Persian            = 20,
   Hebrew             = 21,
   Asturian           = 22,
   Finnish            = 23,
   Indonesian         = 24,
   Swedish            = 25,
   Ukrainian          = 26,
   Czech              = 27,
   CatalanValencia    = 28,
   Catalan            = 29,
   BritishEnglish     = 30,
   Hungarian          = 31,
   Belarusian         = 32,
   Galician           = 33,
   Norwegian          = 34,
   Last,
}
