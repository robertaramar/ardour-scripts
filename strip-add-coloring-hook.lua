ardour {
    ["type"]    = "EditorHook",
    name        = "Coloring Strip When Added Hook",
    description = "Color the strip when it is added.",
  }
  
  function signals ()
    s = LuaSignal.Set()
    s:add (
      {
        [LuaSignal.RouteAdded] = true,
      }
    )
    return s
  end
  
  function factory (params)

    ---------------------------
    -- define some functions --
    ---------------------------

    -- check if the config file exists
    function FileExists(path)
        local f=io.open(path,"r")
        if f~=nil then io.close(f) return true else return false end
    end

    -- read the configuration file
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
    end -- ReadConfig

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

    -------------------
    -- end functions --
    -------------------

    -----------------
    -- signal hook --
    -----------------
    return function (signal, ref, ...)

        if (signal == LuaSignal.RouteAdded ) then

            local user_cfg = ARDOUR.user_config_directory(-1)
            local settings_path = ARDOUR.LuaAPI.build_filename(user_cfg, 'strip_config')
            if not FileExists( settings_path ) then
                print( "Settings file " .. settings_path .. " not found")
                goto function_end
            end

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
                       
            local added_routes  = ...

            -- iterate over all new strips
            for t in added_routes:iter() do
                local name = t:name()

                local colorName = GetColorByNameMatch( name, track_color_config )
                local colr = colors[colorName]
                -- the opacity is added to the color
                if colr and not( colr == "" ) and t:presentation_info_ptr():color() ~= tonumber( colr .. "ff")  then
                    local colnr = tonumber( colr .. "ff")
                    t:presentation_info_ptr():set_color(colnr)
                end
            end
            ::function_end::
        end
    end
end