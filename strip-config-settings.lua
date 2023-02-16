-- lua 5.3

ardour {
    ["type"] = "EditorAction",
    name = "Settings for Mixer Strip Configuration",
    author = "Holger Dehnhardt",
    description = [[Default Settings for Strip-Configuration]]
}


function factory () return function ()
    
    function DefaultConfig()
        local cfg = { 
            ["1"] = { "----", "", "" }, 
            ["2"] = { "Bass",  0x806515, "bass" },
            ["3"] = { "Bass Sum",  0x554000, "bass sum" },
            ["4"] = { "Drums",  0x87cb87, "drums, kick, bd, snare, tom, floor, hihat, hh, ride, crash, cymbal" },
            ["5"] = { "Drums Sum",  0x116611, "drums sum" },
            ["6"] = { "Guitar",  0xfafe80, "guitar, git, gtr" },
            ["7"] = { "Guitar Sum",  0xf6ff00, "guitar sum, guitar bus, git sum, git bus, gtr sum, gtr bus" },
            ["8"] = { "Piano",  0xFFAA9F, "piano, grand piano, accoustic piano" },
            ["9"] = { "Synths",  0xe1a053, "synth, arpeggio, keys" },
            ["10"] = { "Keys Sum",  0xe1a053, "keys sum, synths sum" },
            ["11"] = { "Vox",  0x6687e1, "vox, vocals, voc" },
            ["12"] = { "Vox Bg",  0x80B7F0, "vox bg, vox background, voc bg, voc background, bg" },
            ["13"] = { "Vox Sum",  0x0e0af2, "vox sum, voc sum, vocals sum" },
            ["14"] = { "Horns",  0x7ccce, "horns, sax, saxophone, trombone, tuba" },
            ["15"] = { "Horns Sum",  0x10a4a8, "horns sum" },
            ["16"] = { "Effects",  0xacacac, "effect" },
            ["17"] = { "Master Effects",  0xFFFFFF, "master verb, master ambient" }
        }
        return cfg
    end

    function FileExists(path)
        local f=io.open(path,"r")
        if f~=nil then io.close(f) return true else return false end
    end

    function ReadConfig( path )
        local cfg = {}
        local file = io.open( path, "r")
        io.input(file)
    
        for line in io.lines() do
            local token = {}
            local i = 1
            for t in string.gmatch( line, "[^;]+") do
                if not t then
                    t = ""
                end
                token[i] = t
                i=i+1
            end
            cfg[token[1]]= {token[2], token[3], token[4] }
        end
        io.close( file )
        return cfg
    end

    function CheckColor( instrument, color )
        if color == "" then
            return true
        end
        local match = color:match("%x%x%x%x%x%x?")
        if match ~= color then
            print( "Wrong color: " .. color .. " for instrument " .. instrument )
            LuaDialog.Message( "Data Error",
                "Wrong color: " .. color .. " for instrument " .. instrument, 
                LuaDialog.MessageType.Warning, LuaDialog.ButtonType.Close):run ()
            return false
        end
        return true
    end

    function UpdateConfig( rv, max )
        local conf = {}
        local n = 1
        local success = true
        
        for i = 1, max do
            if rv[i.."Instrument"] ~= "" then
                local instrument = rv[i.."Instrument"]
                local color
                local tags
                if rv[i.."Color"] ~= "" then
                    if not CheckColor( rv[i.."Instrument"], rv[i.."Color"] ) then
                        success = false
                        color = ""
                    else
                        color = "0x"..rv[i.."Color"]
                    end
                else
                    color = ""
                end
                if rv[i.."Match-Tags"] ~= "" then
                    tags = rv[i.."Match-Tags"]
                else
                    tags = ""
                end
                conf[""..n] = { instrument, color, tags }
                n = n + 1
            end
        end
        return success, conf
    end

    function WriteConfig( conf, path )
        print( path )
        local file = io.open( path, "w")
        io.output(file)
		for k, v in pairs( conf ) do
            io.write( k )
            io.write( ";" )
            io.write( v[1] )
            io.write( ";" )
            if v[2] ~= "" then
                io.write( string.format( "0x%x", v[2] ) )
            else
                io.write( v[2] )
            end
            io.write( ";" )
            io.write( v[3] )
            io.write( "\n" )
        end
        io.close( file )
    end

    function DisplayDialog( track_color_config, settings_path )
        --starting to build our dialog
        local dialog_options = {
            { type = "label", colspan=6, title = "Change your color settings here:" },
            { type = "label", colspan=6, title = "If there are values (separated by a comma) in the 'Match-Tags' row, colors will be set automatically if a tag matches any substring in the strip name." },
            { type = "label", colspan=6, title = "To delete an entry, simply remove the instrument name, the row will disappear after saving." },
            { type = "label", colspan=6, title = "If you need mor entries, save your setting and open again. Five new rows will appear." },
            { type = "heading", title = "ID",    col = 0, colspan = 1 },
            { type = "heading", title = "Instrument",    col = 1, colspan = 1 },
            { type = "heading", title = "Color",    col = 2, colspan = 1 },
            { type = "heading", title = "Match-Tags",   col = 3, colspan = 3 },
        }

        local rowcount = 1
        while (true) do
            v = track_color_config[""..rowcount]
            if not v then
		        print ("no config settings found")
                break
            end
            local color
            print( v[2] )
            if not v[2] or v[2] == ""  then
                color = ""
            else
                color = string.format( "%x", v[2] )
            end
            table.insert( dialog_options, {type = "label", col = 0, colspan = 1, title = ""..rowcount })
            table.insert( dialog_options, {type = "entry", key= rowcount .. "Instrument", col = 1, colspan = 1, default = v[1], title = "" })
            table.insert( dialog_options, {type = "entry", key= rowcount .. "Color", col = 2, colspan = 1, default = color, title = "" })
            table.insert( dialog_options, {type = "entry", key= rowcount .. "Match-Tags", col = 3, colspan = 3, default = v[3], title = "" })
            rowcount = rowcount + 1
        end
        local max = rowcount + 5
        for i = rowcount, max do
            table.insert( dialog_options, {type = "label", col = 0, colspan = 1, title = ""..i })
            table.insert( dialog_options, {type = "entry", key= i .. "Instrument", col = 1, colspan = 1, default = "", title = "" })
            table.insert( dialog_options, {type = "entry", key= i .. "Color", col = 2, colspan = 1, default = "", title = "" })
            table.insert( dialog_options, {type = "entry", key= i .. "Match-Tags", col = 3, colspan = 3, default = "", title = "" })        
        end

        local success = false
        local config = {}
        local rv = LuaDialog.Dialog("Strip Color Configuration", dialog_options):run()
        if not(rv) then 
            goto function_end 
        end
        success, config = UpdateConfig( rv, max )
        if success then 
            WriteConfig( config, settings_path )
            return 0, config 
        else 
            return 1, config
        end
        assert(rv, 'Dialog box was cancelled or is ' .. type(rv))
        ::function_end::
        return 2, config
    end

    local user_cfg = ARDOUR.user_config_directory(-1)
    local settings_path = ARDOUR.LuaAPI.build_filename(user_cfg, 'strip_config')
    print( "File-Path:" .. settings_path)

    local track_color_config
    if FileExists( settings_path ) then
        track_color_config = ReadConfig( settings_path )
    else
        track_color_config = DefaultConfig()
    end

    while true do
        local ret, conf = DisplayDialog( track_color_config, settings_path )
        print( "Return: "..ret )
        if ret ~= 1 then
            break
        end
        track_color_config = conf
    end
end
end --factory
