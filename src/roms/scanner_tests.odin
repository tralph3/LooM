package roms

import "core:testing"

@(test)
test_reorder_article_suffix :: proc(t: ^testing.T) {
    cases := []struct{
        input: string,
        expected: string,
    } {
        {"Legend of Zelda, The", "The Legend of Zelda"},
        {"Super Mario Bros, A", "A Super Mario Bros"},
        {"Chrono Trigger", "Chrono Trigger"},
        {"Mario, Super", "Super Mario"},
        {"Mario,Super", "Mario,Super"}, // no space after comma
        {"Mario , Super", "Super Mario "}, // space before comma
        {"Mario,  The", "Mario,  The"}, // double space after comma
        {", The", "The "},
        {" , The", "The  "},
        {"The", "The"},
        {"", ""},
        {"Rayman, L'", "L' Rayman"},
        // Not an article (contains space)
        {"Rayman, The Best", "Rayman, The Best"},
        {"Rayman, Le Grand", "Rayman, Le Grand"},
        // Comma in the middle of the title, not an article
        {"Mario, Luigi, The", "The Mario, Luigi"},
        {"Mario, Luigi, The, The", "The Mario, Luigi, The"}, // Only last is reordered
        // Edge cases
        {", A", "A "},
        {",", ","},
        {", ", " "},
        {",", ","},
        {" ,", " ,"},
        {" , ", "  "},
        {" , A", "A  "},
        {"A, The", "The A"},
        {"A,", "A,"},
        {"A, ", " A"},
        {"A,The", "A,The"},
        {"A, The Best", "A, The Best"},
        {"Compound, A - Title, The", "A Compound - Title, The"},
    }

    for c in cases {
        res := reorder_article_suffix(c.input, context.temp_allocator)
        testing.expect_value(t, res, c.expected)
    }
}

@(test)
test_rom_extract_tags_from_name :: proc(tst: ^testing.T) {
    cases := []struct{
        input: string,
        expected_clean: string,
        expected_tags: bit_set[RomTag],
    } {
        {"Super Mario Bros", "Super Mario Bros", {}},
        {"Super Mario Bros (USA)", "Super Mario Bros", { .USA }},
        {"Super Mario Bros (USA, Demo)", "Super Mario Bros", { .USA, .Demo }},
        {"Super (USA) Mario Bros", "Super", { .USA }},
        {"Game Title (Special Edition) (Japan)", "Game Title (Special Edition)", { .Japan }},
        {"Game Title (Special Edition) (Japan, Demo)", "Game Title (Special Edition)", { .Japan, .Demo }},
        {"(USA, Demo)", "", { .USA, .Demo }},
        {"Game (  usa  ,  demo  )", "Game", { .USA, .Demo }},
        {"Game (EN)", "Game", { .English }},
        {"Game (FR)", "Game", { .French }},
        {"Game (EN, JA, USA)", "Game", { .English, .Japanese, .USA }},
        {"Game (Special)", "Game (Special)", {}},
        {"Game (Unl)", "Game", { .Unlicensed }},
        {"Game (Special Edition)", "Game (Special Edition)", {}},
        {"Game (Special) (USA)", "Game (Special)", { .USA }},
        {"Game (Special) (USA) (Demo)", "Game (Special)", { .USA, .Demo }},
        {"Game (USA,  Demo,  EN)", "Game", { .USA, .Demo, .English }},
    }

    for c in cases {
        clean, tags := rom_extract_tags_from_name(c.input)
        testing.expect_value(tst, clean, c.expected_clean)
        testing.expect_value(tst, tags, c.expected_tags)
    }
}
