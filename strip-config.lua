-- lua 5.3

ardour {
    ["type"] = "EditorAction",
    name = "Mixer Strip Configuration",
    author = "Holger Dehnhardt",
    description = [[Easily modifiable session overview and track property editor with automatic color assignement]]
}

function factory () return function ()

    ---------------------------
    -- define some functions --
    ---------------------------

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
                token[i] = t
                i=i+1
            end
            cfg[token[1]]= {token[2], token[3], token[4] }
        end
        io.close( file )
        return cfg
    end
	
	-- function to get colors for predefined tags
	function GetColorByNameMatch( name, track_color_config )
		local color
		local last_match
		
		local nl = name:lower()
		
		for k, v in pairs(track_color_config) do 
			if v[3] then 
			
			for token in string.gmatch( v[3], "[^,]+") do
				local t = string.gsub(token, '^%s*(.-)%s*$', '%1' )
				local tl = t:lower()
				local match = nl:match( tl )
				if( not match ) then 
					match = t:match( nl )
				end
				if match and ( not last_match or match:len() > last_match:len() ) then
					last_match = match
					color = v[1]
				end
			end
			end
		end
		if last_match then
			return color
		end
		return -1
	end -- GetColorByNameMatch

	--helper function to find default group option
	function QueryGroup(t)
        local v = "----"
        for g in Session:route_groups():iter() do
            for r in g:route_list():iter() do
                if r:name() == t:name() then v = g:name() end
            end
        end return v
    end -- QueryGroup

    function FindGroupColor(g, m, colors, track_color_config)
        local c = "----"
        for k, v in pairs(colors) do
            if g:rgba() == tonumber( v .. "ff")  then c = k end
        end 
        if c == "----" and m then
            c = GetColorByNameMatch( g:name(), track_color_config )
        end
        return c
    end -- FindGroupColor

    function FindColor(t, m, colors, track_color_config )
        local c = "----"
        for k, v in pairs(colors) do
            if t:presentation_info_ptr():color() == tonumber( v .. "ff") then c = k end
        end 
        if c == "----" and m then
            c = GetColorByNameMatch( t:name(), track_color_config)
        end
        return c
    end -- FindColor

    -------------------
    -- End functions --
    -------------------

    -- create the file path
    local user_cfg = ARDOUR.user_config_directory(-1)
    local settings_path = ARDOUR.LuaAPI.build_filename(user_cfg, 'strip_config')
    print( "Settings-Path:" .. settings_path )

    -- and check for existance
    if not FileExists( settings_path ) then
        print( "Settings file " .. settings_path .. " not found")
        LuaDialog.Message( "Config-File missing",
        "The config file is missing. Install and call the 'Settings for Mixer Strip Configuration' script before using this scipt", 
        LuaDialog.MessageType.Warning, LuaDialog.ButtonType.Close):run ()
        goto script_end
    end

    -- read the settings
    local track_color_config = ReadConfig( settings_path )


   	-- extract the default colors from the track_color_config
	local colors = {}
	for k, v in pairs( track_color_config ) do
        if v[1] == "----" then
            colors[v[1]] = ""
        else
            colors[v[1]] = v[2]
        end
	end

	-- setup some default groups
    local groups = {
		["----"]   = "", 
		["Drums"] = "Drums", 
		["Bass"] = "Bass", 
		["Guitars"] = "Guitars",
		["Keys"] = "Keys", 
		["Strings"] = "Strings", 
		["Vox"] = "Vox"
	}

    -- add existing groups
	for g in Session:route_groups():iter() do
		groups[g:name()] = g
	end

    --------------------------------------
    -- ask for automatic strip coloring --
    --------------------------------------
    local automaticColoring = false;
    local ok = LuaDialog.Message ("Automatic coloring ", "Should the Mixer Strip colours be assigned automatically?", LuaDialog.MessageType.Question, LuaDialog.ButtonType.Yes_No):run ()
    if ok == LuaDialog.Response.Yes then
            automaticColoring = true
    end

    ----------------------------------
    -- starting to build our dialog --
    ----------------------------------
    -- dalog options
    local dialog_options = {
		{ type = "label", colspan=6, title = "Change your strip settings here:" },
		{ type = "heading", title = "Type",    col = 0, colspan = 1 },
		{ type = "heading", title = "Name",    col = 1, colspan = 1 },
		{ type = "heading", title = "Group",   col = 2, colspan = 1 },
		{ type = "heading", title = "Comment", col = 3, colspan = 1 },
		{ type = "heading", title = "Color",   col = 4, colspan = 1 },
	}

	-- add groups to table
	for g in Session:route_groups():iter() do
        local groupid = g:to_stateful():id():to_s()
        table.insert(dialog_options, {
            type = "label", col = 0, colspan = 1, title = "Group"
        }) --type
        table.insert(dialog_options, {
            type = "label", col = 1, colspan = 1, title = g:name(), align = "left"
        }) --name
        table.insert(dialog_options, {
            type = "label", col = 2, colspan = 1, title = ""
        }) --name
        table.insert(dialog_options, {
            type = "label", col = 3, colspan = 1, title = ""
        }) --type
        table.insert(dialog_options, {
            type = "dropdown", key = "g_" .. groupid .. ' c',  col = 4, colspan = 1, title = "", values = colors, default = FindGroupColor(g, automaticColoring, colors, track_color_config )
        }) --color
    end

    --insert an entry into our dialog_options table for each track with appropriate info
    for t in Session:get_stripables():iter() do
        if t:is_master() or t:is_monitor() or  t:is_auditioner() or t:is_hidden() then
            goto continue
        end

        local r = t:to_route()
        local type = "Track"

        if r:isnil( ) then
            type = "VCA"
        else
            local tr = r:to_track()
            if tr:isnil() then
                type = "Bus";
            end
        end
        local trackid = t:to_stateful():id():to_s()

        table.insert(dialog_options, {
            type = "label", key = "t_" .. trackid .."_o", col = 0, colspan = 1, title = type
        }) --type
        if not( r:isnil() ) then
            table.insert(dialog_options, {
                type = "entry",    key = "t_" .. trackid .. ' n',  col = 1, colspan = 1, default = t:name(), title = ""
            }) --name
                table.insert(dialog_options, {
                type = "dropdown", key = "t_" .. trackid .. ' g',  col = 2, colspan = 1, title = "", values = groups, default = QueryGroup(t)
            }) --group
                table.insert(dialog_options, {
                type = "entry",    key ="t_" ..  trackid .. ' cm', col = 3, colspan = 1, default = r:comment(), title = ""
            }) --comment
        else
            local v = t:to_vca()
            if not v:isnil() then
                print( "VCA found" )
                table.insert(dialog_options, {
                    type = "label",  key = "t_" .. trackid .. ' n', col = 1, colspan = 1, title = v:name(), align = "left"
                }) --name
            end
        end
        table.insert(dialog_options, {
            type = "dropdown", key = "t_" .. trackid .. ' c',  col = 4, colspan = 1, title = "", values = colors, default = FindColor(t, automaticColoring, colors, track_color_config )
        }) --color
        ::continue::
    end

    -----------------------------
    --run strip config dialog  --
    -----------------------------
    local rv = LuaDialog.Dialog("Strip Configuration", dialog_options):run()
    if not(rv) then goto script_end end
    assert(rv, 'Dialog box was cancelled or is ' .. type(rv))

    ------------------
    -- store values --
    ------------------

    -- begin group operation
    for g in Session:route_groups():iter() do
        local groupid = g:to_stateful():id():to_s()
        local colr = rv["g_" .. groupid .. ' c' ]
        if colr and not( colr == "" ) and  g:rgba() ~= tonumber( colr .. "ff") then
            g:set_rgba( tonumber( colr .. "ff") )
        end
    end

    --begin track operation
    for t in Session:get_stripables():iter() do
        if t:is_master() or t:is_monitor() or t:is_auditioner() or t:is_hidden() then
            goto continue
        end
        local trackid = t:to_stateful():id():to_s()
        local r = t:to_route()
        local name = rv["t_" .. trackid .. ' n' ]
        -- not VCAs
        if not( r:isnil() ) then
            local cmnt = rv["t_" .. trackid .. ' cm']
            if cmnt and r:comment() ~= cmnt then
                r:set_comment(cmnt, nil)
            end

            local cgrp = QueryGroup(t)
            local ngrp = rv["t_" .. trackid .. ' g' ]
            if type(ngrp) == "userdata" then
                if cgrp ~= ngrp:name() then
                    ngrp:add(r)
                end
            end
            if type(ngrp) == "string" and not(ngrp == "") then
                ngrp = Session:new_route_group(ngrp)
                if cgrp ~= ngrp:name() then
                    ngrp:add(r)
                end
            end
            if r:name() ~= name    then r:set_name(name)         end
        else
            -- vca
            local v = t:to_vca()
            if not( v:isnil() ) then
                -- if  v:name() ~= name then 
		        print( "VCA: ", v:name(), name )
                    --t:set_name(name)
                --end
            end
        end

        local colr = rv["t_" .. trackid .. ' c' ]
        if colr == "" and name and automaticColoring then
            local colorName = GetColorByNameMatch( name, track_color_config )
            colr = colors[colorName]
        end
        -- the opacity is added to the color
        if colr and not( colr == "" ) and t:presentation_info_ptr():color() ~= tonumber( colr .. "ff")  then
    	    local colnr = tonumber( colr .. "ff")
            t:presentation_info_ptr():set_color(colnr)
        end

        ::continue::
    end
    ::script_end::
end
end --factory
