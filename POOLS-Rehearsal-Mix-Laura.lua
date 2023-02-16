ardour {
	["type"] = "EditorAction",
	name = "POOLS Rehearsal Mix (Laura)",
	author = "Robert Schneider (robert.schneider@aramar.de)",
	description = [[
	v1.0.1
This template helps create the tracks for POOLS rehearsal recording.

This script is developed in Lua, and can be duplicated and/or modified to meet your needs.

Now with normalization.
]]
}

function factory(params)
	function session_setup()
		return true
	end

	function route_setup()
		return {
			["Insert_at"] = ARDOUR.PresentationInfo.max_order
		}
	end

	-----------------------------------------------------------------
	function basic_serialize(o)
		if type(o) == "number" then
			return tostring(o)
		else
			return string.format("%q", o)
		end
	end

	function serialize(name, value)
		local rv = name .. " = "
		collectgarbage()
		if type(value) == "number" or type(value) == "string" or type(value) == "nil" or type(value) == "boolean" then
			return rv .. basic_serialize(value) .. " "
		elseif type(value) == "table" then
			rv = rv .. "{} "
			for k, v in pairs(value) do
				local fieldname = string.format("%s[%s]", name, basic_serialize(k))
				rv = rv .. serialize(fieldname, v) .. " "
			end
			return rv
		elseif type(value) == "function" then
			--return rv .. string.format("%q", string.dump(value, true))
			return rv .. "(function)"
		else
			error("cannot serialize a " .. type(value))
		end
	end

	function normalize_regions_in_selected_track()
		-- get Editor GUI Selection
		-- http://manual.ardour.org/lua-scripting/class_reference/#ArdourUI:Selection
		local sel = Editor:get_selection()

		-- prepare undo operation
		Session:begin_reversible_command("Lua Normalize")
		local add_undo = false -- keep track if something has changed

		for route in sel.tracks:routelist():iter() do
			-- consider only tracks
			local track = route:to_track()
			if track:isnil() then
				goto continue
			end

			-- iterate over all regions of the given track
			for region in track:playlist():region_list():iter() do
				-- test if it's an audio region
				local ar = region:to_audioregion()
				if ar:isnil() then
					goto next
				end

				local peak = ar:maximum_amplitude(nil)
				local rms = ar:rms(nil)

				if (peak > 0) then
					print("Region:", region:name(), "peak:", 20 * math.log(peak) / math.log(10), "dBFS")
					print("Region:", region:name(), "rms :", 20 * math.log(rms) / math.log(10), "dBFS")
				else
					print("Region:", region:name(), " is silent")
				end

				-- normalize region
				if (peak > 0) then
					-- prepare for undo
					region:to_stateful():clear_changes()
					-- calculate gain.
					local f_rms = rms / 10 ^ (.05 * -9) -- -9dBFS/RMS
					local f_peak = peak -- 0dbFS/peak
					-- apply gain
					if (f_rms > f_peak) then
						print("Region:", region:name(), "RMS  normalized by:", -20 * math.log(f_rms) / math.log(10), "dB")
						ar:set_scale_amplitude(1 / f_rms)
					else
						print("Region:", region:name(), "peak normalized by:", -20 * math.log(f_peak) / math.log(10), "dB")
						ar:set_scale_amplitude(1 / f_peak)
					end
					-- save changes (if any) to undo command
					if not Session:add_stateful_diff_command(region:to_statefuldestructible()):empty() then
						add_undo = true
					end
				end
				::next::
			end
			::continue::
		end

		-- all done. now commit the combined undo operation
		if add_undo then
			-- the 'nil' command here means to use all collected diffs
			Session:commit_reversible_command(nil)
		else
			Session:abort_reversible_command()
		end
	end
	-----------------------------------------------------------------

	return function()
		--at session load, params will be empty.  in this case we can do things that we -only- want to do if this is a new session
		if (not params) then
			Editor:set_toggleaction("Rulers", "toggle-tempo-ruler", true)
			Editor:set_toggleaction("Rulers", "toggle-meter-ruler", true)

			Editor:access_action("Transport", "primary-clock-bbt")
			Editor:access_action("Transport", "secondary-clock-minsec")

			Editor:set_toggleaction("Rulers", "toggle-minsec-ruler", false)
			Editor:set_toggleaction("Rulers", "toggle-timecode-ruler", false)
			Editor:set_toggleaction("Rulers", "toggle-samples-ruler", false)

			Editor:set_toggleaction("Rulers", "toggle-bbt-ruler", true)
		end

		local p = params or route_setup()
		local insert_at = p["insert_at"] or ARDOUR.PresentationInfo.max_order

		--prompt the user for the tracks they'd like to instantiate
		local dialog_options = {
			{
				type = "folder",
				key = "folder",
				title = "Select a Folder",
				path = "/media/rschneid/disk/AHQU/USBMTK"
			},
			{type = "hseparator", title = "", col = 0, colspan = 3},
			{
				type = "radio",
				key = "voxLaura",
				title = "Laura",
				values = {
					["Lead"] = 1,
					["Background"] = 2,
					["Off"] = 3
				},
				default = "Lead"
			},
			{
				type = "radio",
				key = "voxBasti",
				title = "Basti",
				values = {
					["Lead"] = 1,
					["Background"] = 2,
					["Off"] = 3
				},
				default = "Background"
			},
			{
				type = "radio",
				key = "voxRobert",
				title = "Robert",
				values = {
					["Lead"] = 1,
					["Background"] = 2,
					["Off"] = 3
				},
				default = "Background"
			},
		--	{
		--		type = "radio",
		--		key = "voxPeter",
		--		title = "Peter",
		--		values = {
		--			["Lead"] = 1,
		--			["Background"] = 2,
		--			["Off"] = 3
		--		},
		--		default = "Off"
		--	},
		--	{
		--		type = "radio",
		--		key = "voxMartina",
		--		title = "Martina",
		--		values = {
		--			["Lead"] = 1,
		--			["Background"] = 2,
		--			["Off"] = 3
		--		},
		--		default = "Off"
		--	},
		--	{
		--		type = "radio",
		--		key = "voxRike",
		--		title = "Rike",
		--		values = {
		--			["Lead"] = 1,
		--			["Background"] = 2,
		--			["Off"] = 3
		--		},
		--		default = "Off"
		--	},
			{type = "hseparator", title = "", col = 0, colspan = 3},
			{type = "checkbox", key = "group", default = true, title = "Group Track(s)?", col = 0},
			{type = "checkbox", key = "normalize", default = true, title = "Normalize Track(s)?", col = 0},
			{type = "checkbox", key = "click", default = false, title = "Import Click)?", col = 0}
		}

		local pools_tracks = {
			-- 		track name      is a vox?			waves 1 mono, 2 stereo,						empty on vox
			{name = "Vox Laura", vox = "voxLaura", wave_files = {"TRK01.WAV"}, template = "", group = "vox"},
			{name = "Vox Basti", vox = "voxBasti", wave_files = {"TRK02.WAV"}, template = "", group = "vox"},
			{name = "Vox Robert", vox = "voxRobert", wave_files = {"TRK03.WAV"}, template = "", group = "vox"},
		--	{name = "Vox Peter", vox = "voxPeter", wave_files = {"TRK04.WAV"}, template = "", group = "vox"},
		--	{name = "Vox Martina", vox = "voxMartina", wave_files = {"TRK05.WAV"}, template = "", group = "vox"},
		--	{name = "Vox Rike", vox = "voxRike", wave_files = {"TRK06.WAV"}, template = "", group = "vox"},
			{name = "Bass", vox = "", wave_files = {"TRK07.WAV"}, template = "POOLS Bass", group = "instruments"},
			{name = "Guitar", vox = "", wave_files = {"TRK08.WAV"}, template = "POOLS Guitar", group = "instruments"},
			{name = "Keyboard-L", vox = "", wave_files = {"TRK13.WAV"}, template = "POOLS Keyboard-L", group = "keyboards"},
			{name = "Keyboard-R", vox = "", wave_files = {"TRK14.WAV"}, template = "POOLS Keyboard-R", group = "keyboards"},
		--	{name = "Bass Drum", vox = "", wave_files = {"TRK09.WAV"}, template = "POOLS Bass Drum", group = "drums"},
		--	{name = "Snare", vox = "", wave_files = {"TRK10.WAV"}, template = "POOLS Snare", group = "drums"},
		--	{name = "e-Drums", vox = "", wave_files = {"TRK15.WAV"}, template = "POOLS e-Drums", group = "drums"},
			{name = "Drums Left", vox = "", wave_files = {"TRK05.WAV"}, template = "POOLS Drum Overheads-L", group = "drums"},
			{name = "Drums Right", vox = "", wave_files = {"TRK06.WAV"}, template = "POOLS Drum Overheads-R", group = "drums"},
			{name = "Click", vox = "", wave_files = {"TRK16.WAV"}, template = "POOLS Bass", group = "drums"}
		}

		local dlg = LuaDialog.Dialog("POOLS Rehearsal Mix Setup", dialog_options)
		local rv = dlg:run()
		if (not rv) then
			return
		end

		-- helper function to reference processors
		function processor(t, s) --takes a track (t) and a string (s) as arguments
			local i = 0
			local proc = t:nth_processor(i)
			repeat
				if (proc:display_name() == s) then
					return proc
				else
					i = i + 1
				end
				proc = t:nth_processor(i)
			until proc:isnil()
		end

		function add_lv2_plugin(track, pluginname, position)
			local p = ARDOUR.LuaAPI.new_plugin(Session, pluginname, ARDOUR.PluginType.LV2, "")
			if not p:isnil() then
				track:add_processor_by_index(p, position, nil, true)
			end
		end

		local drum_group, instrument_group, vox_group

		if rv["group"] then
			vox_group = Session:new_route_group("Vox")
			vox_group:set_rgba(0x88CC88ff)
			instrument_group = Session:new_route_group("Instruments")
			instrument_group:set_rgba(0x8080FFff)
			keyboard_group = Session:new_route_group("Keyboards")
			keyboard_group:set_rgba(0x80FF80ff)
			drum_group = Session:new_route_group("Drums")
			drum_group:set_rgba(0x801515ff)
		end

		local channel_count = 0

		for i = 1, #pools_tracks do -- #pools_tracks
			local template_name = pools_tracks[i]["template"]
			if (template_name == "") then
				local voxmode = rv[pools_tracks[i]["vox"]]
				print(string.format("voxmode = %d", voxmode))
				if (voxmode == 1) then
					template_name = "Vox Laura"
				end
				if (voxmode == 2) then
					template_name = "POOLS Background Vocals"
				end
				if (voxmode == 3) then
					template_name = ""
				end
			end
			if pools_tracks[i]["name"] == "Click" and not rv["click"] then
				template_name = ""
			end
			print(string.format("template_name = '%s'", template_name))
			if string.len(template_name) >= 1 then
				template_name = "/home/rschneid/.config/ardour5/route_templates/" .. template_name .. ".template"
				print(string.format("template_name = '%s'", template_name))
				local rl =
					Session:new_route_from_template(
					1,
					insert_at,
					template_name,
					pools_tracks[i]["name"],
					ARDOUR.PlaylistDisposition.NewPlaylist
				)
				-- fill the track
				local files = C.StringVector()
				for f = 1, #pools_tracks[i]["wave_files"] do
					files:push_back(rv["folder"] .. "/" .. pools_tracks[i]["wave_files"][f])
				end
				for route in rl:iter() do
					Editor:do_import(
						files,
						Editing.ImportDistinctFiles,
						Editing.ImportToTrack,
						ARDOUR.SrcQuality.SrcBest,
						ARDOUR.MidiTrackNameSource.SMFTrackName,
						ARDOUR.MidiTempoMapDisposition.SMFTempoIgnore,
						-1,
						ARDOUR.PluginInfo()
					)
					if rv["normalize"] then
						normalize_regions_in_selected_track()
					end
					if rv["group"] then
						if (pools_tracks[i]["group"] == "vox") then
							vox_group:add(route)
						end
						if (pools_tracks[i]["group"] == "instruments") then
							instrument_group:add(route)
						end
						if (pools_tracks[i]["group"] == "keyboards") then
							keyboard_group:add(route)
						end
						if (pools_tracks[i]["group"] == "drums") then
							drum_group:add(route)
						end
					end
				end
			end
		end

		--fit all tracks on the screen
		Editor:access_action("Editor", "fit_all_tracks")

		Session:save_state("")

		-- determine the number of channels we can record
		local e = Session:engine()
		local _, t =
			e:get_backend_ports(
			"",
			ARDOUR.DataType("audio"),
			ARDOUR.PortFlags.IsOutput | ARDOUR.PortFlags.IsPhysical,
			C.StringVector()
		) -- from the engine's POV readable/capture ports are "outputs"
		local num_inputs = t[4]:size() -- table 't' holds argument references. t[4] is the C.StringVector (return value)

		if num_inputs < channel_count then
			-- warn the user if there are less physical inputs than created tracks
			LuaDialog.Message(
				"Session Creation",
				"Created more tracks than there are physical inputs on the soundcard",
				LuaDialog.MessageType.Info,
				LuaDialog.ButtonType.Close
			):run()
		end
	end
end
