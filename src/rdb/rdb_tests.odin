package rdb

import "core:testing"
import "core:mem"
import "core:os/os2"
import "core:math/rand"
import "core:strings"
import "core:fmt"
import "core:slice"

FOOTER_ARR :: []byte {
    u8(DataType.FixMap) + 1,
    u8(DataType.FixStr) + 5, 'c', 'o', 'u', 'n', 't',
    u8(DataType.Uint8),
    0x01,
}

append_footer :: proc (arr: []byte) -> []byte {
    footer := slice.clone(FOOTER_ARR, context.temp_allocator)
    return slice.concatenate([][]byte{ arr, footer }, context.temp_allocator)
}

make_rdb_test_data :: proc(entries: [][]byte) -> []byte {
    header := make([]byte, 16, context.temp_allocator)
    header[0] = 'R'; header[1] = 'A'; header[2] = 'R'; header[3] = 'C';
    header[4] = 'H'; header[5] = 'D'; header[6] = 'B'; header[7] = 0x00;

    entries_bytes := slice.concatenate(entries, context.temp_allocator)
    metadata_offset := len(header) + len(entries_bytes)

    footer := []byte{
        u8(DataType.FixMap) + 1,
        u8(DataType.FixStr) + 5, 'c', 'o', 'u', 'n', 't',
        u8(DataType.Uint8), u8(len(entries)), // u8 is enough in the context of the tests
    }

    off := metadata_offset
    for i in 0..<8 {
        header[8+7-i] = u8(off & 0xFF)
        off >>= 8
    }

    return slice.concatenate([][]byte{header, entries_bytes, footer}, context.temp_allocator)
}

@(test)
rdb_parse_simple_string_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 5, 'v', 'a', 'l', 'u', 'e',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x01,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1)

    entry, exists := db[1]
    testing.expect_value(t, exists, true)
    testing.expect_value(t, len(entry), 1)

    value, has_key := entry["key"]
    testing.expect_value(t, has_key, true)

    str_value, str_ok := value.(string)
    testing.expect_value(t, str_ok, true)
    testing.expect_value(t, str_value, "value")
}

@(test)
rdb_parse_multiple_data_types_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 6,
            u8(DataType.FixStr) + 3, 's', 't', 'r',
            u8(DataType.FixStr) + 3, 'f', 'o', 'o',
            u8(DataType.FixStr) + 3, 'i', 'n', 't',
            u8(DataType.Uint32), 0x00, 0x00, 0x00, 0x42, // u32: 66
            u8(DataType.FixStr) + 3, 'b', 'i', 'n',
            u8(DataType.Bin8), 0x03, 0x01, 0x02, 0x03, // bin8: 3 bytes
            u8(DataType.FixStr) + 3, 'u', '6', '4',
            u8(DataType.Uint64), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x64, // u64: 100
            u8(DataType.FixStr) + 3, 'i', '1', '6',
            u8(DataType.Int16), 0x12, 0x34, // i16: 4660
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x02, // 2
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1)

    entry, exists := db[2]
    testing.expect_value(t, exists, true)
    testing.expect_value(t, len(entry), 5)

    // Check string
    str_val, has_str := entry["str"]
    testing.expect_value(t, has_str, true)
    str, str_ok := str_val.(string)
    testing.expect_value(t, str_ok, true)
    testing.expect_value(t, str, "foo")

    // Check u32
    int_val, has_int := entry["int"]
    testing.expect_value(t, has_int, true)
    u32_val, u32_ok := int_val.(u32)
    testing.expect_value(t, u32_ok, true)
    testing.expect_value(t, u32_val, 66)

    // Check binary
    bin_val, has_bin := entry["bin"]
    testing.expect_value(t, has_bin, true)
    bin, bin_ok := bin_val.([]byte)
    testing.expect_value(t, bin_ok, true)
    testing.expect_value(t, len(bin), 3)
    testing.expect_value(t, bin[0], 1)
    testing.expect_value(t, bin[1], 2)
    testing.expect_value(t, bin[2], 3)

    // Check u64
    u64_val, has_u64 := entry["u64"]
    testing.expect_value(t, has_u64, true)
    u64, u64_ok := u64_val.(u64)
    testing.expect_value(t, u64_ok, true)
    testing.expect_value(t, u64, 100)

    // Check i16
    i16_val, has_i16 := entry["i16"]
    testing.expect_value(t, has_i16, true)
    i16, i16_ok := i16_val.(i16)
    testing.expect_value(t, i16_ok, true)
    testing.expect_value(t, i16, 4660)
}

@(test)
rdb_parse_entry_without_crc_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 1, // fixmap with 1 entry (no CRC)
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 5, 'v', 'a', 'l', 'u', 'e',
        },
        {
            u8(DataType.FixMap) + 2, // fixmap with 2 entries (with CRC)
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 5, 'v', 'a', 'l', 'u', 'e',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x03,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1) // Only the entry with CRC should be included

    entry, exists := db[3]
    testing.expect_value(t, exists, true)
    testing.expect_value(t, len(entry), 1)
}

@(test)
rdb_parse_duplicate_crc_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 5, 'v', 'a', 'l', 'u', 'e',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x04, // 4
        },
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 5, 'o', 't', 'h', 'e', 'r',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x04, // 4 (same CRC)
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1) // only first entry should be kept

    entry, exists := db[4]
    testing.expect_value(t, exists, true)

    value, has_key := entry["key"]
    testing.expect_value(t, has_key, true)

    str_value, str_ok := value.(string)
    testing.expect_value(t, str_ok, true)
    testing.expect_value(t, str_value, "value") // should be first value, not "other"
}

@(test)
rdb_parse_crc_larger_than_4_bytes_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 5, 'v', 'a', 'l', 'u', 'e',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05, // 8 bytes (too large)
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1)

    entry, exists := db[5] // the crc should still be read, only the bottom bytes taken into account
    testing.expect_value(t, exists, true)

    value, has_key := entry["key"]
    testing.expect_value(t, has_key, true)

    str_value, str_ok := value.(string)
    testing.expect_value(t, str_ok, true)
    testing.expect_value(t, str_value, "value")
}

@(test)
rdb_parse_all_integer_types_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 9,
            u8(DataType.FixStr) + 2, 'u', '8',
            u8(DataType.Uint8), 0x42,                                            // u8: 66
            u8(DataType.FixStr) + 3, 'u', '1', '6',
            u8(DataType.Uint16), 0x12, 0x34,                                     // u16: 4660
            u8(DataType.FixStr) + 3, 'u', '3', '2',
            u8(DataType.Uint32), 0x00, 0x00, 0x12, 0x34,                         // u32: 4660
            u8(DataType.FixStr) + 3, 'u', '6', '4',
            u8(DataType.Uint64), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x34, // u64: 4660
            u8(DataType.FixStr) + 2, 'i', '8',
            u8(DataType.Int8), 0x42,                                             // i8: 66
            u8(DataType.FixStr) + 3, 'i', '1', '6',
            u8(DataType.Int16), 0x12, 0x34,                                      // i16: 4660
            u8(DataType.FixStr) + 3, 'i', '3', '2',
            u8(DataType.Int32), 0x00, 0x00, 0x12, 0x34,                          // i32: 4660
            u8(DataType.FixStr) + 3, 'i', '6', '4',
            u8(DataType.Int64), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x34,  // i64: 4660
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x06,                     // 6
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)

    entry, exists := db[6]
    testing.expect_value(t, exists, true)
    testing.expect_value(t, len(entry), 8)

    // Check u8
    u8_val, has_u8 := entry["u8"]
    testing.expect_value(t, has_u8, true)
    u8, u8_ok := u8_val.(u8)
    testing.expect_value(t, u8_ok, true)
    testing.expect_value(t, u8, 66)

    // Check u16
    u16_val, has_u16 := entry["u16"]
    testing.expect_value(t, has_u16, true)
    u16, u16_ok := u16_val.(u16)
    testing.expect_value(t, u16_ok, true)
    testing.expect_value(t, u16, 4660)

    // Check u32
    u32_val, has_u32 := entry["u32"]
    testing.expect_value(t, has_u32, true)
    u32, u32_ok := u32_val.(u32)
    testing.expect_value(t, u32_ok, true)
    testing.expect_value(t, u32, 4660)

    // Check u64
    u64_val, has_u64 := entry["u64"]
    testing.expect_value(t, has_u64, true)
    u64, u64_ok := u64_val.(u64)
    testing.expect_value(t, u64_ok, true)
    testing.expect_value(t, u64, 4660)

    // Check i8
    i8_val, has_i8 := entry["i8"]
    testing.expect_value(t, has_i8, true)
    i8, i8_ok := i8_val.(i8)
    testing.expect_value(t, i8_ok, true)
    testing.expect_value(t, i8, 66)

    // Check i16
    i16_val, has_i16 := entry["i16"]
    testing.expect_value(t, has_i16, true)
    i16, i16_ok := i16_val.(i16)
    testing.expect_value(t, i16_ok, true)
    testing.expect_value(t, i16, 4660)

    // Check i32
    i32_val, has_i32 := entry["i32"]
    testing.expect_value(t, has_u32, true)
    i32, i32_ok := i32_val.(i32)
    testing.expect_value(t, i32_ok, true)
    testing.expect_value(t, i32, 4660)

    // Check i64
    i64_val, has_i64 := entry["i64"]
    testing.expect_value(t, has_i64, true)
    i64, i64_ok := i64_val.(i64)
    testing.expect_value(t, i64_ok, true)
    testing.expect_value(t, i64, 4660)
}

@(test)
rdb_parse_string_types_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 5,
            u8(DataType.FixStr) + 3, 'f', 'i', 'x',
            u8(DataType.FixStr) + 3, 'f', 'o', 'o',
            u8(DataType.FixStr) + 4, 's', 't', 'r', '8',
            u8(DataType.Str8), 0x03, 'b', 'a', 'r',
            u8(DataType.FixStr) + 5, 's', 't', 'r', '1', '6',
            u8(DataType.Str16), 0x00, 0x04, 'b', 'a', 'z', 'z',
            u8(DataType.FixStr) + 5, 's', 't', 'r', '3', '2',
            u8(DataType.Str32), 0x00, 0x00, 0x00, 0x05, 'q', 'u', 'u', 'x', 'x',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x07,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)

    entry, exists := db[7]
    testing.expect_value(t, exists, true)
    testing.expect_value(t, len(entry), 4)

    // Check fixstr
    fix_val, has_fix := entry["fix"]
    testing.expect_value(t, has_fix, true)
    fix_str, fix_ok := fix_val.(string)
    testing.expect_value(t, fix_ok, true)
    testing.expect_value(t, fix_str, "foo")

    // Check str8
    str_val, has_str := entry["str8"]
    testing.expect_value(t, has_str, true)
    str, str_ok := str_val.(string)
    testing.expect_value(t, str_ok, true)
    testing.expect_value(t, str, "bar")

    // Check str16
    str1_val, has_str1 := entry["str16"]
    testing.expect_value(t, has_str1, true)
    str1, str1_ok := str1_val.(string)
    testing.expect_value(t, str1_ok, true)
    testing.expect_value(t, str1, "bazz")

    // Check str32
    str2_val, has_str2 := entry["str32"]
    testing.expect_value(t, has_str2, true)
    str2, str2_ok := str2_val.(string)
    testing.expect_value(t, str2_ok, true)
    testing.expect_value(t, str2, "quuxx")
}

@(test)
rdb_parse_binary_types_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 4,
            u8(DataType.FixStr) + 4, 'b', 'i', 'n', '8',
            u8(DataType.Bin8), 0x03, 0x01, 0x02, 0x03,
            u8(DataType.FixStr) + 5, 'b', 'i', 'n', '1', '6',
            u8(DataType.Bin16), 0x00, 0x04, 0x04, 0x05, 0x06, 0x07,
            u8(DataType.FixStr) + 5, 'b', 'i', 'n', '3', '2',
            u8(DataType.Bin32), 0x00, 0x00, 0x00, 0x05, 0x08, 0x09, 0x0A, 0x0B, 0x0C,
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x08,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)

    entry, exists := db[8]
    testing.expect_value(t, exists, true)
    testing.expect_value(t, len(entry), 3)

    // Check bin8
    bin8_val, has_bin8 := entry["bin8"]
    testing.expect_value(t, has_bin8, true)
    bin8, bin8_ok := bin8_val.([]byte)
    testing.expect_value(t, bin8_ok, true)
    testing.expect_value(t, len(bin8), 3)
    testing.expect_value(t, bin8[0], 1)
    testing.expect_value(t, bin8[1], 2)
    testing.expect_value(t, bin8[2], 3)

    // Check bin16
    bin1_val, has_bin1 := entry["bin16"]
    testing.expect_value(t, has_bin1, true)
    bin1, bin1_ok := bin1_val.([]byte)
    testing.expect_value(t, bin1_ok, true)
    testing.expect_value(t, len(bin1), 4)
    testing.expect_value(t, bin1[0], 4)
    testing.expect_value(t, bin1[1], 5)
    testing.expect_value(t, bin1[2], 6)
    testing.expect_value(t, bin1[3], 7)

    // Check bin32
    bin2_val, has_bin2 := entry["bin32"]
    testing.expect_value(t, has_bin2, true)
    bin2, bin2_ok := bin2_val.([]byte)
    testing.expect_value(t, bin2_ok, true)
    testing.expect_value(t, len(bin2), 5)
    testing.expect_value(t, bin2[0], 8)
    testing.expect_value(t, bin2[1], 9)
    testing.expect_value(t, bin2[2], 10)
    testing.expect_value(t, bin2[3], 11)
    testing.expect_value(t, bin2[4], 12)
}

@(test)
rdb_parse_unsupported_types_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 1,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.False), // false (unsupported)
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, ParseError.UnsupportedItemType)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_unknown_type_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 1,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            0xFF, // unknown type
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, ParseError.UnknownTypeError)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_empty_file_test :: proc(t: ^testing.T) {
    entries := [][]byte{}

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_invalid_header_test :: proc(t: ^testing.T) {
    test_data := []byte{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Invalid header
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // metadata start
        u8(DataType.Nil),
    }

    test_data = append_footer(test_data)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, ParseError.InvalidHeader)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_multiple_entries_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 4, 'v', 'a', 'l', '1',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x09, // 9
        },
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 4, 'v', 'a', 'l', '2',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x0A, // 10
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 2)

    // Check first entry
    entry1, exists1 := db[9]
    testing.expect_value(t, exists1, true)
    value1, has_key1 := entry1["key"]
    testing.expect_value(t, has_key1, true)
    str1, str1_ok := value1.(string)
    testing.expect_value(t, str1_ok, true)
    testing.expect_value(t, str1, "val1")

    // Check second entry
    entry2, exists2 := db[10]
    testing.expect_value(t, exists2, true)
    value2, has_key2 := entry2["key"]
    testing.expect_value(t, has_key2, true)
    str2, str2_ok := value2.(string)
    testing.expect_value(t, str2_ok, true)
    testing.expect_value(t, str2, "val2")
}

@(test)
rdb_parse_crc_hash_test :: proc(t: ^testing.T) {
    test_cases := []struct{
        input: []byte,
        expected: u32,
    } {
        // Standard 4-byte cases
        { {0x12, 0x34, 0x56, 0x78}, 0x12345678},
        { {0x00, 0x00, 0x00, 0x01}, 0x00000001},
        { {0xFF, 0xFF, 0xFF, 0xFF}, 0xFFFFFFFF},
        { {0x31, 0x32, 0x33, 0x34}, 0x31323334},

        // Shorter than 4 bytes - should pad with zeros
        { {0x42}, 0x00000042},
        { {0x12, 0x34}, 0x00001234},
        { {0x12, 0x34, 0x56}, 0x00123456},
        { {}, 0x00000000},

        // Longer than 4 bytes - should only use bottom 4 bytes
        { {0xAA, 0xBB, 0xCC, 0xDD, 0x12, 0x34, 0x56, 0x78}, 0x12345678},
        { {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x01}, 0x00000001},
        { {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00}, 0xDDEEFF00},

        // Edge cases
        { {0x00, 0x00, 0x00, 0x00}, 0x00000000},
        { {0xF0, 0x00, 0x00, 0x00}, 0xF0000000},
        { {0x00, 0x00, 0x00, 0x01}, 0x00000001},
    }

    for test_case in test_cases {
        result := parse_crc_hash(test_case.input)
        testing.expect_value(t, result, test_case.expected)
    }
}

@(test)
rdb_parse_truncated_string_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.Str8), 0x05, 'h', 'e', 'l', // truncated - missing 'o'
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x0B,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect(t, err != nil)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_truncated_binary_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.Bin8), 0x04, 0x01, 0x02, // truncated - missing 2 bytes
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x0C,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect(t, err != nil)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_truncated_integer_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.Uint32), 0x00, 0x00, // truncated - missing 2 bytes
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x0D,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect(t, err != nil)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_non_string_key_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 1,
            u8(DataType.Uint8), 0x42, // key is uint8 instead of string
            u8(DataType.FixStr) + 5, 'v', 'a', 'l', 'u', 'e',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x0E,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, ParseError.UnexpectedType)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_missing_value_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 1,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.Nil), // unexpected nil instead of a value
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x0F,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, ParseError.UnexpectedType)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_empty_string_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 0, // empty string
            u8(DataType.FixStr) + 5, 'v', 'a', 'l', 'u', 'e',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x10,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1)

    entry, exists := db[0x10]
    testing.expect_value(t, exists, true)

    value, has_key := entry[""]
    testing.expect_value(t, has_key, true)

    str_value, str_ok := value.(string)
    testing.expect_value(t, str_ok, true)
    testing.expect_value(t, str_value, "value")
}

@(test)
rdb_parse_empty_binary_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.Bin8), 0x00, // empty binary
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x11,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1)

    entry, exists := db[0x11]
    testing.expect_value(t, exists, true)

    value, has_key := entry["key"]
    testing.expect_value(t, has_key, true)

    bin_value, bin_ok := value.([]byte)
    testing.expect_value(t, bin_ok, true)
    testing.expect_value(t, len(bin_value), 0)
}

@(test)
rdb_parse_truncated_map_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 3, // map with 3 entries
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 5, 'v', 'a', 'l', 'u', 'e',
            // missing second key-value pair
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x12,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect(t, err != nil)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_completely_empty_file_test :: proc(t: ^testing.T) {
    entries := [][]byte{}

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_unsupported_nested_structure_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixMap) + 1, // nested map
            u8(DataType.FixStr) + 3, 'n', 'e', 's',
            u8(DataType.FixStr) + 5, 't', 'e', 'd', 'v', 'l',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x13,
            u8(DataType.Nil),
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, ParseError.UnexpectedType)
    testing.expect_value(t, len(db), 0)
}

@(test)
rdb_parse_with_garbage_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 5, 'v', 'a', 'l', 'u', 'e',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x21,
            u8(DataType.Nil),
            0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE, // garbage
        },
    }

    base := make_rdb_test_data(entries)
    with_garbage := slice.concatenate([][]byte{
        base,
        { 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE }, // garbage
    }, context.temp_allocator)

    db, err := parse_database(with_garbage)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1)

    entry_map, exists := db[0x21]
    testing.expect_value(t, exists, true)

    value, has_key := entry_map["key"]
    testing.expect_value(t, has_key, true)

    str_value, str_ok := value.(string)
    testing.expect_value(t, str_ok, true)
    testing.expect_value(t, str_value, "value")
}

@(test)
rdb_merge_entries_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 3,
            u8(DataType.FixStr) + 3, 'a', 'b', 'c',
            u8(DataType.FixStr) + 3, 'o', 'n', 'e',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x42,
            u8(DataType.FixStr) + 3, 'x', 'y', 'z',
            u8(DataType.FixStr) + 3, 'f', 'o', 'o',
        },
        {
            u8(DataType.FixMap) + 3,
            u8(DataType.FixStr) + 3, 'd', 'e', 'f',
            u8(DataType.FixStr) + 3, 't', 'w', 'o',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x42,
            u8(DataType.FixStr) + 3, 'x', 'y', 'z',
            u8(DataType.FixStr) + 3, 'b', 'a', 'r',
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1)

    entry, exists := db[0x42]
    testing.expect_value(t, exists, true)

    testing.expect_value(t, len(entry), 3)

    value_abc, has_abc := entry["abc"]
    value_def, has_def := entry["def"]
    value_xyz, has_xyz := entry["xyz"]

    testing.expect_value(t, has_abc, true)
    testing.expect_value(t, has_def, true)
    testing.expect_value(t, has_xyz, true)

    str_abc, ok_abc := value_abc.(string)
    str_def, ok_def := value_def.(string)
    str_xyz, ok_xyz := value_xyz.(string)

    testing.expect_value(t, ok_abc, true)
    testing.expect_value(t, ok_def, true)
    testing.expect_value(t, ok_xyz, true)

    testing.expect_value(t, str_abc, "one")
    testing.expect_value(t, str_def, "two")
    // value from the first entry
    testing.expect_value(t, str_xyz, "foo")
}

@(test)
rdb_merge_entries_conflict_test :: proc(t: ^testing.T) {
    entries := [][]byte{
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 3, 'o', 'n', 'e',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x99,
        },
        {
            u8(DataType.FixMap) + 2,
            u8(DataType.FixStr) + 3, 'k', 'e', 'y',
            u8(DataType.FixStr) + 3, 't', 'w', 'o',
            u8(DataType.FixStr) + 3, 'c', 'r', 'c',
            u8(DataType.Bin8), 0x04, 0x00, 0x00, 0x00, 0x99,
        },
    }

    test_data := make_rdb_test_data(entries)

    db, err := parse_database(test_data)
    defer delete_database(db)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, len(db), 1)

    entry, exists := db[0x99]
    testing.expect_value(t, exists, true)

    testing.expect_value(t, len(entry), 1)

    value, has_key := entry["key"]
    testing.expect_value(t, has_key, true)

    str_value, str_ok := value.(string)
    testing.expect_value(t, str_ok, true)
    // value from first entry
    testing.expect_value(t, str_value, "one")
}
