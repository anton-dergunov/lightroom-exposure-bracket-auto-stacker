local ExifToolCommand = require 'ExifToolCommand'

local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s:\nexpected %s\ngot      %s", what, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.run_args_list_options_extensions_and_folder()
    local text = ExifToolCommand.runArgs("/Photos/My Trip", true)
    local lines = {}
    for line in text:gmatch("[^\n]+") do lines[#lines + 1] = line end
    eq(lines[1], "-j", "first option")
    eq(lines[#lines], "/Photos/My Trip", "folder is the last argument, unquoted")
    assert(text:find("\n%-r\n"), "recursive flag")
    assert(text:find("\n%-ext\nCR3\n"), "CR3 extension")
    assert(not ExifToolCommand.runArgs("/x", false):find("\n%-r\n"), "no recursive flag")
end

function tests.mac_command_quotes_every_path()
    eq(ExifToolCommand.commandLine({
        platform = "mac",
        program = { "/usr/bin/perl", "/Users/me/Plug-in's/exiftool/mac/exiftool" },
        tagsArgs = "/p/tags.args", runArgs = "/t/run.args", output = "/t/out.json", errors = "/t/out.err",
    }), [['/usr/bin/perl' '/Users/me/Plug-in'\''s/exiftool/mac/exiftool' -@ '/p/tags.args' -@ '/t/run.args' > '/t/out.json' 2> '/t/out.err']],
    "command line")
end

function tests.windows_command_wraps_the_whole_line_in_quotes()
    eq(ExifToolCommand.commandLine({
        platform = "win",
        program = { [[C:\Program Files\Plugin\exiftool\win\exiftool.exe]] },
        tagsArgs = [[C:\p\tags.args]], runArgs = [[C:\t\run.args]], output = [[C:\t\out.json]], errors = [[C:\t\out.err]],
    }), [[""C:\Program Files\Plugin\exiftool\win\exiftool.exe" -@ "C:\p\tags.args" -@ "C:\t\run.args" > "C:\t\out.json" 2> "C:\t\out.err""]],
    "command line")
end

function tests.parse_output()
    eq(#ExifToolCommand.parse(""), 0, "empty output")
    eq(#ExifToolCommand.parse(nil), 0, "missing output")
    eq(ExifToolCommand.parse('[{"System:FileName": "A.ARW"}]')[1]["System:FileName"], "A.ARW", "frame")
    local frames, message = ExifToolCommand.parse("[{broken")
    eq(frames, nil, "broken output")
    assert(message:find("exiftool"), "message")
end

return tests
