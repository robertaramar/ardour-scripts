ardour {
	["type"] = "SessionInit",
	-- ["type"] = "EditorAction",
	name = "ESM Rehearsal Mix",
	author = "Robert Schneider (robert.schneider@aramar.de)",
	description = [[
	v1.0.1
This template helps create the tracks for an Eastside Men rehearsal recording.

This script is developed in Lua, and can be duplicated and/or modified to meet your needs.

Now with normalization.
]]
}

function factory(params)
	-- Names for busses where we route the instrument tracks to
	local bus_bass_name = "ESM Bass Bus"
	local bus_guitar_name = "ESM Guitar Bus"
	local bus_keyboard_name = "ESM Keyboard Bus"
	local bus_drums_name = "ESM Drums Bus"

	-- Names for busses that are configured with reverb types to support mix depth
	local bus_front_reverb_name = "ESM Front Reverb Bus"
	local bus_middle_reverb_name = "ESM Middle Reverb Bus"
	local bus_back_reverb_name = "ESM Back Reverb Bus"

	-- Names for tracks to allow my KRONOS to be heard and recorded
	local track_kronos_name = "ESM KRONOS Track"
	local track_kronos_aux_name = "ESM KRONOS Aux Track"

	-- Variables that hold routes for various busses and tracks
	local bass_bus = nil -- the bus for the bass ;-)
	local guitar_bus = nil -- the bus for guitar L+R
	local keyboard_bus = nil -- the bus for keyboard L+R
	local drums_bus = nil -- the bus for drums L+R
	local front_reverb_bus = nil -- the bus for the front reverb (main vocals)
	local middle_reverb_bus = nil -- the bus for middle reverb (instruments)
	local back_reverb_bus = nil -- the bus for back reverb (drums, bass, backing vocals)
	local kronos_track = nil -- the KRONOS track
	local kronos_aux_track = nil -- the KRONOS Aux track

	local function get_template_name(template)
		local home = "/home/rschneid" -- os.getenv("HOME")
		return home .. "/.config/ardour7/route_templates/" .. template .. ".template"
	end

	local function session_setup()
		return true
	end

	local function route_setup()
		return {
			["Insert_at"] = ARDOUR.PresentationInfo.max_order
		}
	end

	-----------------------------------------------------------------

	local function basic_serialize(o)
		if type(o) == "number" then
			return tostring(o)
		else
			return string.format("%q", o)
		end
	end

	local function serialize(name, value)
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

	local function normalize_regions_in_selected_track()
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

	local function create_instrument_route(name, template)
		print(string.format("Creating instrument route '%s' with template '%s'", name, template))
		local template_name = get_template_name(template)
		local rl = Session:new_route_from_template(1,
			ARDOUR.PresentationInfo.max_order,
			template_name,
			name,
			ARDOUR.PlaylistDisposition.NewPlaylist);
		for r in rl:iter() do
			return r;
		end
	end

	local function add_reverb_send(target, source, level)
		Session:add_internal_send (target, source:main_outs (), source)
		local processor = source:nth_send(0)
		local internal_send = processor:to_internalsend()
		internal_send:gain_control():set_value(level, PBD.GroupControlDisposition.NoGroup)
	end

	local function create_instrument_busses()
		local reverb_send_level = 0.25

		bass_bus = create_instrument_route("Bass Bus", bus_bass_name);
		add_reverb_send(back_reverb_bus, bass_bus, reverb_send_level)

		guitar_bus = create_instrument_route("Guitar Bus", bus_guitar_name);
		add_reverb_send(middle_reverb_bus, guitar_bus, reverb_send_level)

		keyboard_bus = create_instrument_route("Keyboard Bus", bus_keyboard_name);
		add_reverb_send(middle_reverb_bus, keyboard_bus, reverb_send_level)

		drums_bus = create_instrument_route("Drums Bus", bus_drums_name);
		add_reverb_send(back_reverb_bus, drums_bus, reverb_send_level)
		
		local group = Session:new_route_group("Instrument Busses")
		group:set_rgba(0xD16868FF)
		group:add(bass_bus)
		group:add(guitar_bus)
		group:add(keyboard_bus)
		group:add(drums_bus)
	end

	local function create_mix_depth_busses()
		front_reverb_bus = create_instrument_route("Front Reverb", bus_front_reverb_name);
		middle_reverb_bus = create_instrument_route("Middle Reverb", bus_middle_reverb_name);
		back_reverb_bus = create_instrument_route("Back Reverb", bus_back_reverb_name);
		local group = Session:new_route_group("Reverb Busses")
		group:set_rgba(0x806515FF)
		group:add(front_reverb_bus)
		group:add(middle_reverb_bus)
		group:add(back_reverb_bus)
	end

	local function create_kronos_tracks()
		kronos_track = create_instrument_route("KRONOS", track_kronos_name);
		kronos_aux_track = create_instrument_route("KRONOS Aux", track_kronos_aux_name);
	end

	local function route_instrument(instrument, bus)
		instrument:output():disconnect_all(nil);
		instrument:output():audio(0):connect(bus:input():audio(0):name());
		if instrument:n_outputs():n_audio() == 2 then
			instrument:output():audio(1):connect(bus:input():audio(1):name());
		end
	end

	local function route_instruments()
		route_instrument(Session:route_by_name("Bass"), bass_bus);
		route_instrument(Session:route_by_name("Guitar"), guitar_bus);
		route_instrument(Session:route_by_name("Keyboard"), keyboard_bus);
		route_instrument(Session:route_by_name("Drums"), drums_bus);
	end

	local function file_exists(name)
    	local f=io.open(name,"r")
		if f~=nil then io.close(f) return true else return false end
    end

	-----------------------------------------------------------------

	return function()
		--at session load, params will be empty.  in this case we can do things that we -only- want to do if this is a new session
		if (not params) then
			print("This is a new session")
			Editor:set_toggleaction("Rulers", "toggle-tempo-ruler", true)
			Editor:set_toggleaction("Rulers", "toggle-meter-ruler", true)

			Editor:access_action("Transport", "primary-clock-bbt")
			Editor:access_action("Transport", "secondary-clock-minsec")

			Editor:set_toggleaction("Rulers", "toggle-minsec-ruler", false)
			Editor:set_toggleaction("Rulers", "toggle-timecode-ruler", false)
			Editor:set_toggleaction("Rulers", "toggle-samples-ruler", false)

			Editor:set_toggleaction("Rulers", "toggle-bbt-ruler", true)
		else
			print("This is an existing session")
		end

		local p = params or route_setup()
		local insert_at = p["insert_at"] or ARDOUR.PresentationInfo.max_order

		--prompt the user for the tracks they'd like to instantiate
		local dialog_options = {
			{
				type = "folder",
				key = "folder",
				title = "Select a Folder",
				path = "/run/media/rschneid/ESM-REHEARS/Multitrack/"
			},
			{ type = "hseparator", title = "", col = 0, colspan = 3 },
			{
				type = "radio",
				key = "voxMarkus",
				title = "Markus",
				values = {
					["Lead"] = 1,
					["Background"] = 2,
					["Off"] = 3
				},
				default = "Lead"
			},
			{
				type = "radio",
				key = "voxMarkus2",
				title = "Markus2",
				values = {
					["Lead"] = 1,
					["Background"] = 2,
					["Off"] = 3
				},
				default = "Off"
			},
			{
				type = "radio",
				key = "voxRalf",
				title = "Ralf",
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
			{
				type = "radio",
				key = "voxMarkusG",
				title = "MarkusG",
				values = {
					["Lead"] = 1,
					["Background"] = 2,
					["Off"] = 3
				},
				default = "Off"
			},
			{
				type = "radio",
				key = "voxReinhard",
				title = "Reinhard",
				values = {
					["Lead"] = 1,
					["Background"] = 2,
					["Off"] = 3
				},
				default = "Off"
			},
			{
				type = "radio",
				key = "voxRalf2",
				title = "Ralf 2",
				values = {
					["Lead"] = 1,
					["Background"] = 2,
					["Off"] = 3
				},
				default = "Off"
			},
			{ type = "hseparator", title = "", col = 0, colspan = 3 },
			{ type = "checkbox", key = "group", default = true, title = "Group Track(s)?", col = 0 },
			{ type = "checkbox", key = "normalize", default = false, title = "Normalize Track(s)?", col = 0 },
			{ type = "checkbox", key = "aux", default = false, title = "Import Aux?", col = 0 }
		}

		local esm_tracks = {
			-- 		track name      is a vox?			waves 1 mono, 2 stereo,						empty on vox
			{ name = "Vox Markus", vox = "voxMarkus", wave_files = { "03 Markus.flac" }, template = "ESM Vox Markus Track", group = "vox" },
			{ name = "Vox Markus 2", vox = "voxMarkus2", wave_files = { "20 Markus 2.flac" }, template = "ESM Vox Markus Track", group = "vox" },
			{ name = "Vox Ralf", vox = "voxRalf", wave_files = { "04 Ralf.flac" }, template = "ESM Vox Ralf Track", group = "vox" },
			{ name = "Vox Robert", vox = "voxRobert", wave_files = { "07 Robert.flac" }, template = "ESM Vox Robert Track", group = "vox" },
			{ name = "Vox MarkusG", vox = "voxMarkusG", wave_files = { "05 Markus (G).flac" }, template = "ESM Vox Ralf Track ", group = "vox" },
			{ name = "Vox Reinhard", vox = "voxReinhard", wave_files = { "06 Reinhard.flac" }, template = "ESM Vox Robert Track", group = "vox" },
			{ name = "Vox Ralf 2", vox = "voxRalf2", wave_files = { "16 RALF VOC2.flac" }, template = "ESM Vox Ralf Track", group = "vox" },
			{ name = "Bass", vox = "", wave_files = { "08 Bass.flac" }, template = "ESM Bass Track", group = "instruments" },
			{ name = "Guitar", vox = "", wave_files = { "11 Guitar L.flac", "12 Guitar R.flac" }, template = "ESM Guitar Track", group = "instruments" },
			{ name = "Keyboard", vox = "", wave_files = { "13 Keys L.flac", "14 Keys R.flac" }, template = "ESM Keyboard Track", group = "instruments" },
			{ name = "Drums", vox = "", wave_files = { "18 Drums L.flac", "19 Drums R.flac" }, template = "ESM Drums Track", group = "instruments" },
			{ name = "Keys-Aux", vox = "", wave_files = { "09 Keys Aux L.flac", "10 Keys Aux R.flac" }, template = "ESM Keyboard Track", group = "instruments" }
		}

		local dlg = LuaDialog.Dialog("ESM Rehearsal Mix Setup", dialog_options)
		local foundDirectory = false
		local rv
		while (not foundDirectory) do
			rv = dlg:run()
			if (not rv) then
					return
			end
			if file_exists(rv["folder"] .. "/" .. "03 Markus.flac") then
				foundDirectory = true
			else
				local ok = LuaDialog.Message ("Warning", "Invalid folder for import specified.\n\nDo you want to retry?", 
				LuaDialog.MessageType.Warning, LuaDialog.ButtonType.Yes_No):run()
				if ok ~= LuaDialog.Response.Yes then
					return
				end
			end
		end

		create_mix_depth_busses();
		create_instrument_busses();

		local drum_group, instrument_group, vox_group

		if rv["group"] then
			vox_group = Session:new_route_group("Vox")
			vox_group:set_rgba(0x88CC88ff)
			instrument_group = Session:new_route_group("Instruments")
			instrument_group:set_rgba(0x8080FFff)
		end

		local channel_count = 0;

		for i = 1, #esm_tracks do -- #esm_tracks
			local template_name = esm_tracks[i]["template"]
			local vox_mode = rv[esm_tracks[i]["vox"]] -- #is this vox to be imported?
			if string.find(esm_tracks[i]["name"], "Aux") and not rv["aux"] then
				vox_mode = 3;
			end
			print(string.format("template_name = '%s'", template_name))
			if vox_mode ~= 3 then
				template_name = "/home/rschneid/.config/ardour7/route_templates/" .. template_name .. ".template"
				print(string.format("template_name = '%s'", template_name))
				local rl = Session:new_route_from_template(
					1,
					insert_at,
					template_name,
					esm_tracks[i]["name"],
					ARDOUR.PlaylistDisposition.NewPlaylist
				)
				-- fill the track
				local files = C.StringVector()
				for f = 1, #esm_tracks[i]["wave_files"] do
					files:push_back(rv["folder"] .. "/" .. esm_tracks[i]["wave_files"][f])
				end
				for route in rl:iter() do
					Editor:do_import(
						files,
						Editing.ImportMergeFiles,
						Editing.ImportToTrack,
						ARDOUR.SrcQuality.SrcBest,
						ARDOUR.MidiTrackNameSource.SMFTrackName,
						ARDOUR.MidiTempoMapDisposition.SMFTempoIgnore,
						Temporal.timepos_t(0),
						ARDOUR.PluginInfo(),
						ARDOUR.Track(),
						false
					)
					if rv["normalize"] then
						normalize_regions_in_selected_track()
					end
					if rv["group"] then
						if (esm_tracks[i]["group"] == "vox") then
							vox_group:add(route)
						end
						if (esm_tracks[i]["group"] == "instruments") then
							instrument_group:add(route)
						end
					end
					if vox_mode == 1 then
						add_reverb_send(front_reverb_bus, route, 0.125)
					elseif vox_mode == 2 then
						add_reverb_send(back_reverb_bus, route, 0.25)
					end
				end
			else
				print(string.format("vox_mode = '%d', rv[click] = '%s'", vox_mode, rv["click"]))
			end
		end

		create_kronos_tracks();
		route_instruments();

		Session:save_state("", false, false, false, false, false);

		-- determine the number of channels we can record
		local e = Session:engine();
		local _, t = e:get_backend_ports(
			"",
			ARDOUR.DataType("audio"),
			ARDOUR.PortFlags.IsOutput | ARDOUR.PortFlags.IsPhysical,
			C.StringVector()
		);  -- from the engine's POV readable/capture ports are "outputs"
		local num_inputs = t[4]:size();  -- table 't' holds argument references. t[4] is the C.StringVector (return value)

		if num_inputs < channel_count then
			-- warn the user if there are less physical inputs than created tracks
			LuaDialog.Message(
				"Session Creation",
				"Created more tracks than there are physical inputs on the soundcard",
				LuaDialog.MessageType.Info,
				LuaDialog.ButtonType.Close
			):run();
		end
	end
end
