ardour {
	["type"] = "EditorAction",
	name = "Create DrumGizmo tracks & busses",
	author = "Robert Schneider",
	description = [[Creates required tracks and busses to mix a DrumGizmo drum.]]
}

function action_params ()
	return
	{
		["unique"]   = { title = "Only add if no DrumGizmo already present (yes/no)",      default = "yes"},
		["drumkit"]  = { title = "Drumkit to add (d=DRSKit, m=MuldjordKit, a=Aasimonster", default = "d"},
	}
end

AM_channels = {
"Overhead left",
"Overhead right",
"Snare top",
"Snare bottom",
"Snare trigger",
"Alesis DM5",
"Kick right",
"Kick left",
"Hihat",
"Rise cymbal",
"Tom 1",
"Tom 2",
"Tom 3",
"Tom 4 / floor tom",
"Ambience left",
"Ambience right"
}

DRS_channels = {
"Ambience left",
"Ambience right",
"Kickdrum back",
"Kickdrum front",
"Hihat",
"Overhead left",
"Overhead right",
"Ride cymbal",
"Snaredrum bottom",
"Snaredrum top",
"Tom1",
"Tom2 (Floor tom)",
"Tom3 (Floor tom)"
}

MK_channels = {
"Ambience left",
"Ambience right",
"Hihat",
"Kickdrum left",
"Kickdrum right",
"Overhead left",
"Overhead right",
"Ride left",
"Ride right",
"Snare bottom",
"Snare top",
"Rack tom 1",
"Rack tom 2",
"Rack tom 3",
"Floor tom",
"Kick drum trigger signals"
}

busses = {
"Drums",
"Overhead",
"Snare",
"Kick",
"Toms",
"Ambience"
}

color = 0xff8800ff  --orange
    
function factory (params)
	return function ()

		function create_drumgizmo()
		end

		function create_channels(channels)
		end
		
		function create_busses()
		end

		local i = 1
		while names[i] do
			Session:new_audio_track(1,2,RouteGroup,1,names[i],i,ARDOUR.TrackMode.Normal)

			track = Session:route_by_name(names[i])
			if (not track:isnil()) then
				trkinfo = track:presentation_info_ptr ()	
				trkinfo:set_color (color)
			end

			i = i + 1
		end --foreach track

	end  --function

end --factory
