package libretro

import "core:c"
import sdl "vendor:sdl3"

RETRO_NUM_CORE_OPTION_VALUES_MAX :: 128
RETRO_DEVICE_TYPE_SHIFT: u32 : 8
RETRO_DEVICE_MASK: u32 : ((1 << RETRO_DEVICE_TYPE_SHIFT) - 1)

Callbacks :: struct {
    environment: EnvironmentCallback,
    video_refresh: VideoRefreshCallback,
    input_poll: InputPollCallback,
    input_state: InputStateCallback,
    audio_sample: AudioSampleCallback,
    audio_sample_batch: AudioSampleBatchCallback,
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

SystemInfo :: struct {
    library_name: cstring,
    library_version: cstring,
    valid_extensions: cstring,
    need_fullpath: bool,
    block_extract: bool,
}

GameInfo :: struct {
    path: cstring,
    data: rawptr,
    size: int,
    meta: cstring,
}

RetroEnvironment :: enum c.int {
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

RetroDeviceId :: enum c.int {
    JoypadB      =  0,
    JoypadY      =  1,
    JoypadSelect =  2,
    JoypadStart  =  3,
    JoypadUp     =  4,
    JoypadDown   =  5,
    JoypadLeft   =  6,
    JoypadRight  =  7,
    JoypadA      =  8,
    JoypadX      =  9,
    JoypadL      = 10,
    JoypadR      = 11,
    JoypadL2     = 12,
    JoypadR2     = 13,
    JoypadL3     = 14,
    JoypadR3     = 15,
}

RetroDevice :: enum c.int {
    None     = 0,
    Joypad   = 1,
    Mouse    = 2,
    Keyboard = 3,
    Lightgun = 4,
    Analog   = 5,
    Pointer  = 6,
}

RetroPixelFormat :: enum c.int {
   XRGB1555 = 0,
   XRGB8888 = 1,
   RGB565   = 2,
}

RetroVariable :: struct {
    key: cstring,
    value: cstring,
}

RetroCoreOptionValue :: struct {
    value: cstring,
    label: cstring,
}

RetroCoreOptionDefinition :: struct {
    key: cstring,
    desc: cstring,
    info: cstring,
    values: [RETRO_NUM_CORE_OPTION_VALUES_MAX]RetroCoreOptionValue,
    default_value: cstring,
}

RetroCoreOptionsIntl :: struct {
    us: [^]RetroCoreOptionDefinition,
    local: [^]RetroCoreOptionDefinition,
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

RetroLanguage :: enum c.int {
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
}

RetroLogLevel :: enum c.int {
    DEBUG = 0,
    INFO  = 1,
    WARN  = 2,
    ERROR = 3,
}

RetroLogCallback :: struct {
    log: proc "c" (RetroLogLevel, cstring, #c_vararg ..any)
}

RetroHwContextType :: enum c.int {
    NONE             = 0,
    OPENGL           = 1,
    OPENGLES2        = 2,
    OPENGL_CORE      = 3,
    OPENGLES3        = 4,
    OPENGLES_VERSION = 5,
    VULKAN           = 6,
    D3D11            = 7,
    D3D10            = 8,
    D3D12            = 9,
    D3D9             = 10,
}

RetroHwContextReset :: proc "c" ()

RetroHwRenderCallback :: struct {
    context_type: RetroHwContextType,
    context_reset: RetroHwContextReset,
    get_current_framebuffer: proc "c" () -> c.uintptr_t,
    get_proc_address: proc "c" (cstring) -> sdl.FunctionPointer,
    depth: bool,
    stencil: bool,
    bottom_left_origin: bool,
    version_major: c.uint,
    version_minor: c.uint,
    cache_context: bool,
    context_destroy: RetroHwContextReset,
    debug_context: bool,
}

RetroCoreOptionDisplay :: struct {
    key: cstring,
    visible: bool,
}
