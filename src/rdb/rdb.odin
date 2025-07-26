package rdb

import "core:os/os2"
import "core:encoding/endian"
import "core:slice"
import "core:strings"
import "core:io"
import "core:bytes"

RDB_HEADER : u64 : 0x52_41_52_43_48_44_42_00

// unless reading strings, we'll at most read 8 bytes at once. for
// those operations, this buffer will be reused.
@(thread_local)
BUFFER: [8]byte

ParseError :: enum {
    None,
    InvalidHeader,
    ByteUnpackingError,
    UnexpectedType,
    UnknownTypeError,
    UnsupportedItemType,
    MissingEntryCount,
    NoCRCHash,
}

Error :: union #shared_nil {
    os2.Error,
    io.Error,
    ParseError,
}

Item :: union {
    []byte,
    string,
    u8,
    u16,
    u32,
    u64,
    i8,
    i16,
    i32,
    i64,
}

Entry :: map[string]Item
Database :: map[u32]Entry

FIX_MAP_END   :: DataType(0x8F)
FIX_ARRAY_END :: DataType(0x9F)
FIX_STR_END   :: DataType(0xBF)
DataType :: enum u8 {
    FixMap    = 0x80,
    FixArray  = 0x90,
    FixStr    = 0xA0,

    Nil       = 0xC0,
    False     = 0xC2,
    True      = 0xC3,

    Bin8      = 0xC4,
    Bin16     = 0xC5,
    Bin32     = 0xC6,

    Uint8     = 0xCC,
    Uint16    = 0xCD,
    Uint32    = 0xCE,
    Uint64    = 0xCF,

    Int8      = 0xD0,
    Int16     = 0xD1,
    Int32     = 0xD2,
    Int64     = 0xD3,

    Str8      = 0xD9,
    Str16     = 0xDA,
    Str32     = 0xDB,

    Array16   = 0xDC,
    Array32   = 0xDD,

    Map16     = 0xDE,
    Map32     = 0xDF,
}

parse :: proc {
    parse_database_from_file,
    parse_database_from_path,
}

read_byte :: proc (stream: io.Stream) -> (res: byte, err: Error) #no_bounds_check {
    io.read(stream, BUFFER[:1]) or_return
    return BUFFER[0], nil
}

read_binary :: proc (stream: io.Stream, count: u32, allocator:=context.allocator, loc:=#caller_location) -> (res: []byte, err: Error) {
    buf := make([]byte, count, allocator, loc)
    defer if err != nil { delete(buf) }
    io.read(stream, buf) or_return
    return buf, nil
}

read_uint8 :: proc (stream: io.Stream) -> (res: u8, err: Error) {
    return read_byte(stream)
}

read_uint16 :: proc (stream: io.Stream) -> (res: u16, err: Error) #no_bounds_check {
    io.read(stream, BUFFER[:2]) or_return
    val, ok := endian.get_u16(BUFFER[:2], .Big)
    if !ok { return 0, .ByteUnpackingError }

    return val, nil
}

read_uint32 :: proc (stream: io.Stream) -> (res: u32, err: Error) #no_bounds_check {
    io.read(stream, BUFFER[:4]) or_return
    val, ok := endian.get_u32(BUFFER[:4], .Big)
    if !ok { return 0, .ByteUnpackingError }

    return val, nil
}

read_uint64 :: proc (stream: io.Stream) -> (res: u64, err: Error) #no_bounds_check {
    io.read(stream, BUFFER[:8]) or_return
    val, ok := endian.get_u64(BUFFER[:8], .Big)
    if !ok { return 0, .ByteUnpackingError }

    return val, nil
}

read_int8 :: proc (stream: io.Stream) -> (res: i8, err: Error) {
    r := read_byte(stream) or_return
    return i8(r), nil
}

read_int16 :: proc (stream: io.Stream) -> (res: i16, err: Error) {
    r := read_uint16(stream) or_return
    return i16(r), nil
}

read_int32 :: proc (stream: io.Stream) -> (res: i32, err: Error) {
    r := read_uint32(stream) or_return
    return i32(r), nil
}

read_int64 :: proc (stream: io.Stream) -> (res: i64, err: Error) {
    r := read_uint64(stream) or_return
    return i64(r), nil
}

read_string :: proc (stream: io.Stream, length: u32, allocator:=context.allocator, loc:=#caller_location) -> (res: string, err: Error) {
    buf := make([]byte, length, allocator, loc)
    defer if err != nil { delete(buf) }
    io.read(stream, buf) or_return
    return string(buf), nil
}

identify_type :: proc (stream: io.Stream) -> (type: DataType, size: u32, err: Error) {
    b := read_byte(stream) or_return

    switch DataType(b) {
    // we don't care about the size for any of these types because its implicit
    case .Nil, .False, .True, .Uint8, .Uint16, .Uint32, .Uint64, .Int8, .Int16, .Int32, .Int64:
        type = DataType(b)
    case .FixMap..=FIX_MAP_END:
        type = .FixMap
        size = u32(b & 0b1111)
    case .FixStr..=FIX_STR_END:
        type = .FixStr
        size = u32(b & 0b11111)
    case .FixArray..=FIX_ARRAY_END:
        type = .FixArray
        size = u32(b & 0b1111)
    case .Str8:
        type = .Str8
        size = u32(read_uint8(stream) or_return)
    case .Str16:
        type = .Str16
        size = u32(read_uint16(stream) or_return)
    case .Str32:
        type = .Str32
        size = u32(read_uint32(stream) or_return)
    case .Bin8:
        type = .Bin8
        size = u32(read_uint8(stream) or_return)
    case .Bin16:
        type = .Bin16
        size = u32(read_uint16(stream) or_return)
    case .Bin32:
        type = .Bin32
        size = u32(read_uint32(stream) or_return)
    case .Map16:
        type = .Map16
        size = u32(read_uint16(stream) or_return)
    case .Map32:
        type = .Map32
        size = u32(read_uint32(stream) or_return)
    case .Array16:
        type = .Array16
        size = u32(read_uint16(stream) or_return)
    case .Array32:
        type = .Array32
        size = u32(read_uint32(stream) or_return)
    case:
        return nil, 0, .UnknownTypeError
    }

    return
}

read_item :: proc (stream: io.Stream, allocator:=context.allocator, loc:=#caller_location) -> (item: Item, err: Error) {
    type, size := identify_type(stream) or_return

    switch type {
    case .FixStr:
        item = read_string(stream, size, allocator, loc) or_return
    case .Bin8, .Bin16, .Bin32:
        item = read_binary(stream, size, allocator, loc) or_return
    case .Str8, .Str16, .Str32:
        item = read_string(stream, size, allocator, loc) or_return
    case .Uint8:
        item = read_uint8(stream) or_return
    case .Uint16:
        item = read_uint16(stream) or_return
    case .Uint32:
        item = read_uint32(stream) or_return
    case .Uint64:
        item = read_uint64(stream) or_return
    case .Int8:
        item = read_int8(stream) or_return
    case .Int16:
        item = read_int16(stream) or_return
    case .Int32:
        item = read_int32(stream) or_return
    case .Int64:
        item = read_int64(stream) or_return
    case .FixMap, .Map16, .Map32, .Nil:
        return nil, .UnexpectedType
    case .FixArray, .Array16, .Array32, .False, .True:
        return nil, .UnsupportedItemType
    }

    return
}

read_metadata :: proc (stream: io.Stream, offset: u64) -> (entry: Entry, err: Error) {
    prev := io.seek(stream, 0, .Current) or_return
    io.seek(stream, i64(offset), .Start) or_return

    type, size := identify_type(stream) or_return
    if type != .FixMap { return nil, .UnexpectedType }
    metadata := read_entry(stream, size) or_return

    io.seek(stream, prev, .Start) or_return
    return metadata, nil
}

read_entry :: proc (stream: io.Stream, key_count: u32, allocator:=context.allocator) -> (entry: Entry,  err: Error) {
    defer if err != nil { delete_entry(entry, allocator) }

    for _ in 0..<key_count {
        key, key_err := read_item(stream, allocator)
        val, val_err := read_item(stream, allocator)

        if key_err != nil && val_err != nil {
            delete_item(val, allocator)
            delete_item(key, allocator)
            err = val_err
            return
        } else if key_err != nil {
            delete_item(val, allocator)
            err = key_err
            return
        } else if val_err != nil {
            delete_item(key, allocator)
            err = val_err
            return
        }

        #partial switch key_str in key {
        case string:
            if key_str in entry {
                delete(key_str, allocator)
                delete_item(val, allocator)
                continue
            }
            entry[key_str] = val
        case:
            delete_item(key, allocator)
            delete_item(val, allocator)
            return nil, .UnexpectedType
        }
    }

    return
}

parse_crc_hash :: proc "contextless" (crc: []byte) -> (hash: u32) {
    for b, i in crc {
        shift_count := (uint(len(crc)) - uint(i) - 1) * 8
        hash |= u32(b) << shift_count
    }
    return
}

extract_crc_hash :: proc (entry: ^Entry) -> (crc: u32, err: Error) {
    if "crc" not_in entry { return 0, .NoCRCHash }

    key, val := delete_key(entry, "crc")
    defer delete(key)
    defer delete_item(val)

    if val_arr, ok_val := val.([]byte); ok_val {
        crc = parse_crc_hash(val_arr)
    } else {
        return 0, .UnexpectedType
    }

    return
}

validate_header :: proc (stream: io.Stream) -> (err: Error) {
    file_header := read_uint64(stream) or_return
    if file_header != RDB_HEADER {
        return .InvalidHeader
    }

    return nil
}

parse_database_from_file :: proc (file: ^os2.File, allocator:=context.allocator) -> (res: Database, err: Error) {
    bytes := os2.read_entire_file_from_file(file, allocator) or_return
    defer delete(bytes, allocator)
    return parse_database_from_bytes(bytes, allocator)
}

parse_database_from_path :: proc (file_path: string, allocator:=context.allocator) -> (res: map[u32]Entry, err: Error) {
    f := os2.open(file_path) or_return
	defer os2.close(f)

    return parse_database_from_file(f, allocator)
}

parse_database_from_bytes :: proc (contents: []byte, allocator:=context.allocator) -> (res: map[u32]Entry, err: Error) {
    buf: bytes.Buffer
    bytes.buffer_init(&buf, contents)
    stream := bytes.buffer_to_stream(&buf)

    // sanity check: the contents's memory gets copied to the buffer,
    // and the buffer memory is then mirrored on the stream. this gets
    // rid of the buffer memory as well, don't worry
    defer io.destroy(stream)

    return parse_database_from_stream(stream, allocator)
}

merge_entries :: proc (entry1, entry2: ^Entry, allocator:=context.allocator) -> Entry {
    for k, v in entry2 {
        if k in entry1 { continue }
        entry1[k] = v
        delete_key(entry2, k)
    }
    delete_entry(entry2^)
    return entry1^
}

parse_database_from_stream :: proc (stream: io.Stream, allocator:=context.allocator) -> (res: map[u32]Entry, err: Error) {
    validate_header(stream) or_return

    metadata_offset := read_uint64(stream) or_return
    metadata := read_metadata(stream, metadata_offset) or_return
    defer delete_entry(metadata, allocator)

    count_item, has_count := metadata["count"]
    if !has_count { return nil, .MissingEntryCount }

    count: u64
    #partial switch c in count_item {
        case u8:  count = u64(c)
        case u16: count = u64(c)
        case u32: count = u64(c)
        case u64: count = u64(c)
        case i8:  count = u64(c)
        case i16: count = u64(c)
        case i32: count = u64(c)
        case i64: count = u64(c)
        case: return nil, .UnexpectedType
    }

    for _ in 0..<count {
        type, size := identify_type(stream) or_return

        #partial switch type {
        case .FixMap, .Map16, .Map32:
            entry := read_entry(stream, size, allocator) or_return
            crc, extract_err := extract_crc_hash(&entry)

            if extract_err == .NoCRCHash {
                delete_entry(entry)
                continue
            }

            if crc in res {
                res[crc] = merge_entries(&res[crc], &entry)
            } else {
                res[crc] = entry
            }
        case:
            return nil, .UnexpectedType
        }
    }

    return
}

parse_database :: proc {
    parse_database_from_path,
    parse_database_from_file,
    parse_database_from_bytes,
    parse_database_from_stream,
}

delete_item :: proc (item: Item, allocator:=context.allocator) {
    #partial switch value in item {
    case string:
        delete(value, allocator)
    case []byte:
        delete(value, allocator)
    }
}

delete_entry :: proc (entry: Entry, allocator:=context.allocator) {
    for k, v in entry {
        delete(k, allocator)
        delete_item(v, allocator)
    }

    delete(entry)
}

delete_database :: proc (database: Database, allocator:=context.allocator) {
    for _, entry in database {
        delete_entry(entry, allocator)
    }

    delete(database)
}
