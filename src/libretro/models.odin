package libretro

import "core:c"
import sdl "vendor:sdl3"
import vk "vendor:vulkan"

RETRO_NUM_CORE_OPTION_VALUES_MAX :: 128

RETRO_DEVICE_TYPE_SHIFT: u32 : 8
RETRO_DEVICE_MASK: u32 : ((1 << RETRO_DEVICE_TYPE_SHIFT) - 1)
RETRO_DEVICE_ID_JOYPAD_MASK :: 256

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
    GetSensorInterface                            = 25,
    GetCameraInterface                            = 26,
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
    SetMemoryMaps                                 = 36,
    SetGeometry                                   = 37,
    GetUsername                                   = 38,
    GetLanguage                                   = 39,
    GetCurrentSoftwareFramebuffer                 = 40,
    GetHwRenderInterface                          = 41,
    SetSupportAchievements                        = 42,
    SetHwRenderContextNegotiationInterface        = 43,
    SetSerializationQuirks                        = 44,
    SetHwSharedContext                            = 44,
    GetVfsInterface                               = 45,
    GetLedInterface                               = 46,
    GetAudioVideoEnable                           = 47,
    GetMidiInterface                              = 48,
    GetFastforwarding                             = 49,
    GetTargetRefreshRate                          = 50,
    GetInputBitmasks                              = 51,
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
    GetThrottleState                              = 71,
    GetSavestateContext                           = 72,
    GetHwRenderContextNegotiationInterfaceSupport = 73,
    GetJitCapable                                 = 74,
    GetMicrophoneInterface                        = 75,
    GetDevicePower                                = 77,
    SetNetpacketInterface                         = 78,
    GetPlaylistDirectory                          = 79,
    GetFileBrowserStartDirectory                  = 80,
}

RetroDeviceIdJoypad :: enum c.int {
    B      =  0,
    Y      =  1,
    Select =  2,
    Start  =  3,
    Up     =  4,
    Down   =  5,
    Left   =  6,
    Right  =  7,
    A      =  8,
    X      =  9,
    L      = 10,
    R      = 11,
    L2     = 12,
    R2     = 13,
    L3     = 14,
    R3     = 15,
}

RetroDeviceIdAnalog :: enum c.int {
    X = 0,
    Y = 1,
}

RetroDeviceIndexAnalog :: enum c.int {
    Left   = 0,
    Right  = 1,
    Button = 2,
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
    Debug = 0,
    Info  = 1,
    Warn  = 2,
    Error = 3,
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

RetroRumbleEffect :: enum c.int {
    Strong = 0,
    Weak   = 1,
}

RetroRumbleInterface :: struct {
    set_rumble_state: proc "c" (port: uint, effect: RetroRumbleEffect, strength: u16) -> bool
}

RetroKey :: enum c.int {
    Unknown          = 0,
    Backspace        = 8,
    Tab              = 9,
    Clear            = 12,
    Return           = 13,
    Pause            = 19,
    Escape           = 27,
    Space            = 32,
    Exclaim          = 33,
    QuoteDouble      = 34,
    Hash             = 35,
    Dollar           = 36,
    Ampersand        = 38,
    Quote            = 39,
    LeftParen        = 40,
    RightParen       = 41,
    Asterisk         = 42,
    Plus             = 43,
    Comma            = 44,
    Minus            = 45,
    Period           = 46,
    Slash            = 47,
    _0               = 48,
    _1               = 49,
    _2               = 50,
    _3               = 51,
    _4               = 52,
    _5               = 53,
    _6               = 54,
    _7               = 55,
    _8               = 56,
    _9               = 57,
    Colon            = 58,
    Semicolon        = 59,
    Less             = 60,
    Equals           = 61,
    Greater          = 62,
    Question         = 63,
    At               = 64,
    LeftBracket      = 91,
    Backslash        = 92,
    RightBracket     = 93,
    Caret            = 94,
    Underscore       = 95,
    Backquote        = 96,
    A                = 97,
    B                = 98,
    C                = 99,
    D                = 100,
    E                = 101,
    F                = 102,
    G                = 103,
    H                = 104,
    I                = 105,
    J                = 106,
    K                = 107,
    L                = 108,
    M                = 109,
    N                = 110,
    O                = 111,
    P                = 112,
    Q                = 113,
    R                = 114,
    S                = 115,
    T                = 116,
    U                = 117,
    V                = 118,
    W                = 119,
    X                = 120,
    Y                = 121,
    Z                = 122,
    LeftBrace        = 123,
    Bar              = 124,
    RightBrace       = 125,
    Tilde            = 126,
    Delete           = 127,

    KP0              = 256,
    KP1              = 257,
    KP2              = 258,
    KP3              = 259,
    KP4              = 260,
    KP5              = 261,
    KP6              = 262,
    KP7              = 263,
    KP8              = 264,
    KP9              = 265,
    KPPeriod         = 266,
    KPDivide         = 267,
    KPMultiply       = 268,
    KPMinus          = 269,
    KPPlus           = 270,
    KPEnter          = 271,
    KPEquals         = 272,

    Up               = 273,
    Down             = 274,
    Right            = 275,
    Left             = 276,
    Insert           = 277,
    Home             = 278,
    End              = 279,
    PageUp           = 280,
    PageDown         = 281,

    F1               = 282,
    F2               = 283,
    F3               = 284,
    F4               = 285,
    F5               = 286,
    F6               = 287,
    F7               = 288,
    F8               = 289,
    F9               = 290,
    F10              = 291,
    F11              = 292,
    F12              = 293,
    F13              = 294,
    F14              = 295,
    F15              = 296,

    NumLock          = 300,
    CapsLock         = 301,
    ScrolLock        = 302,
    RShift           = 303,
    LShift           = 304,
    RCtrl            = 305,
    LCtrl            = 306,
    RAlt             = 307,
    LAlt             = 308,
    RMeta            = 309,
    LMeta            = 310,
    LSuper           = 311,
    RSuper           = 312,
    Mode             = 313,
    Compose          = 314,

    Help             = 315,
    Print            = 316,
    Sysreq           = 317,
    Break            = 318,
    Menu             = 319,
    Power            = 320,
    Euro             = 321,
    Undo             = 322,
    OEM_102          = 323,

    BrowserBack      = 324,
    BrowserForward   = 325,
    BrowserRefresh   = 326,
    BrowserStop      = 327,
    BrowserSearch    = 328,
    BrowserFavorites = 329,
    BrowserHome      = 330,
    VolumeMute       = 331,
    VolumeDown       = 332,
    VolumeUp         = 333,
    MediaNext        = 334,
    MediaPrev        = 335,
    MediaStop        = 336,
    MediaPlayPause   = 337,
    LaunchMail       = 338,
    LaunchMedia      = 339,
    LaunchApp1       = 340,
    LaunchApp2       = 341,
}

RetroMod :: enum c.int {
    None       = 0x00,

    Shift      = 0x01,
    Ctrl       = 0x02,
    Alt        = 0x04,
    Meta       = 0x08,

    NumLock    = 0x10,
    CapsLock   = 0x20,
    ScrolLock  = 0x40,
}

KeyboardCallbackFunc :: proc "c" (down: bool, keycode: RetroKey, utf32_char: c.uint32_t, modifiers: c.uint16_t)

RetroKeyboardCallback :: struct {
    callback: KeyboardCallbackFunc,
}

RETRO_MEMORY_MASK :: 0xFF

RetroMemory :: enum c.uint {
    SaveRam   = 0,
    RTC       = 1,
    SystemRam = 2,
    VideoRam  = 3,
}

RetroRegion :: enum c.uint {
    NTSC = 0,
    PAL  = 1,
}

RetroHwRenderInterfaceType :: enum c.int {
   VULKAN     = 0,
   D3D9       = 1,
   D3D10      = 2,
   D3D11      = 3,
   D3D12      = 4,
   GSKIT_PS2  = 5,
}

RetroHwRenderContextNegotiationInterfaceType :: enum c.int {
   VULKAN = 0,
}

RetroHwRenderInterface :: struct {
    interface_type: RetroHwRenderInterfaceType,
    interface_version: c.uint,
}

RetroHwRenderContextNegotiationInterface :: struct {
    interface_type: RetroHwRenderContextNegotiationInterfaceType,
    interface_version: c.uint,
}

RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION :: 5

RetroVulkanSetImage :: proc "c" (
    handle: vk.Handle,
    image: ^RetroVulkanImage,
    num_semaphores: c.uint32_t,
    semaphores: [^]vk.Semaphore,
    src_queue_family: c.uint32_t)

RetroVulkanGetSyncIndex :: proc "c" (handle: vk.Handle) -> c.uint32_t

RetroVulkanGetSyncIndexMask :: proc "c" (handle: vk.Handle) -> c.uint32_t

RetroVulkanSetCommandBuffers :: proc "c" (
    handle: vk.Handle,
    num_cmd: c.uint32_t,
    cmd: [^]vk.CommandBuffer)

RetroVulkanWaitSyncIndex :: proc "c" (handle: vk.Handle)

RetroVulkanLockQueue :: proc "c" (handle: vk.Handle)

RetroVulkanUnlockQueue :: proc "c" (handle: vk.Handle)

RetroVulkanSetSignalSemaphore :: proc "c" (handle: vk.Handle, semaphore: vk.Semaphore)

RetroVulkanGetApplicationInfo :: proc "c" () -> ^vk.ApplicationInfo

RetroVulkanCreateDevice :: proc "c" (
    ctx: ^RetroVulkanContext,
    instance: vk.Instance,
    gpu: vk.PhysicalDevice,
    surface: vk.SurfaceKHR,
    get_instance_proc_addr: vk.ProcGetInstanceProcAddr,
    required_device_extensions: [^]cstring,
    num_required_device_extensions: c.uint,
    required_device_layers: [^]cstring,
    num_required_device_layers: c.uint,
    required_features: ^vk.PhysicalDeviceFeatures,
) -> bool

RetroVulkanDestroyDevice :: proc "c" ()

RetroVulkanCreateInstance :: proc "c" (
    get_instance_proc_addr: vk.ProcGetInstanceProcAddr,
    app: ^vk.ApplicationInfo,
    create_instance_wrapper: RetroVulkanCreateInstanceWrapper,
    opaque: rawptr,
) -> vk.Instance

RetroVulkanCreateInstanceWrapper :: proc "c" (
    opaque: rawptr,
    create_info: ^vk.InstanceCreateInfo,
) -> vk.Instance

RetroVulkanCreateDevice2 :: proc "c" (
    ctx: ^RetroVulkanContext,
    instance: vk.Instance,
    gpu: vk.PhysicalDevice,
    surface: vk.SurfaceKHR,
    get_instance_proc_addr: vk.ProcGetInstanceProcAddr,
    create_device_wrapper: RetroVulkanCreateDeviceWrapper,
    opaque: rawptr,
) -> bool

RetroVulkanCreateDeviceWrapper :: proc "c" (
    gpu: vk.PhysicalDevice,
    opaque: rawptr,
    create_info: ^vk.DeviceCreateInfo,
) -> vk.Device

RetroVulkanContext :: struct {
    gpu: vk.PhysicalDevice,
    device: vk.Device,
    queue: vk.Queue,
    queue_family_index: c.uint32_t,
    presentation_queue: vk.Queue,
    presentation_queue_family_index: c.uint32_t,
}

RetroVulkanImage :: struct {
    image_view: vk.ImageView,
    image_layout: vk.ImageLayout,
    create_info: vk.ImageViewCreateInfo,
}

RetroHwRenderInterfaceVulkan :: struct {
    interface_type: RetroHwRenderInterfaceType,
    interface_version: c.uint,
    handle: vk.Handle,
    instance: vk.Instance,
    gpu: vk.PhysicalDevice,
    device: vk.Device,

    get_device_proc_addr: vk.ProcGetDeviceProcAddr,
    get_instance_proc_addr: vk.ProcGetInstanceProcAddr,

    queue: vk.Queue,
    queue_index: c.uint,

    set_image: RetroVulkanSetImage,
    get_sync_index: RetroVulkanGetSyncIndex,
    get_sync_index_mask: RetroVulkanGetSyncIndexMask,
    set_command_buffers: RetroVulkanSetCommandBuffers,
    wait_sync_index: RetroVulkanWaitSyncIndex,
    lock_queue: RetroVulkanLockQueue,
    unlock_queue: RetroVulkanUnlockQueue,
    set_signal_semaphore: RetroVulkanSetSignalSemaphore,
}

RetroHwRenderContextNegotiationInterfaceVulkan :: struct {
    interface_type: RetroHwRenderContextNegotiationInterfaceType,
    interface_version: c.uint,
    get_application_info: RetroVulkanGetApplicationInfo,
    create_device: RetroVulkanCreateDevice,
    destroy_device: RetroVulkanDestroyDevice,
    create_instance: RetroVulkanCreateInstance,
    create_device2: RetroVulkanCreateDevice2,
}

RetroAvEnableFlags :: bit_field c.int {
    EnableVideo: bool | 1,
    EnableAudio: bool | 1,
    EnableFastSavestates: bool | 1,
    EnableHardDisableAudio: bool | 1,
}
