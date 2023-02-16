ardour {
	["type"]    = "dsp",
	name        = "MIDI increase velocity",
	category    = "MIDI", -- "Utility"
	license     = "MIT",
	author      = "Robert Schneider",
	description = [[A MIDI filter to increase velocity.]]
}

function dsp_ioconfig ()
	return { { midi_in = 1, midi_out = 1, audio_in = 0, audio_out = 0}, }
end

function dsp_params ()
	return
	{
		{ ["type"] = "input",
			name = "Threshold",
			doc = "Velocities below this will be increased",
			min = 0, max = 127, default = 64, integer = true },
		{ ["type"] = "input",
			name = "Increment",
			doc = "How much should velocity be increased",
			min = 1, max = 127, default = 32, integer = true }
	}
end


function dsp_run (_, _, n_samples)
	assert (type(midiin) == "table")
	assert (type(midiout) == "table")
	local ctrl = CtrlPorts:array ()
	local threshold = ctrl[1]
	local increment = ctrl[2]
	local cnt = 1;

	function tx_midi (time, data)
		midiout[cnt] = {}
		midiout[cnt]["time"] = time;
		midiout[cnt]["data"] = data;
		cnt = cnt + 1;
	end

	-- for each incoming midi event
	for _,b in pairs (midiin) do
		local t = b["time"] -- t = [ 1 .. n_samples ]
		local d = b["data"] -- get midi-event

		if (#d == 3 and (bit32.band (d[1], 240) == 144) or bit32.band (d[1], 240) == 128) then -- note on
			if (d[3] < threshold) then
				d[3] = math.min(d[3] + increment, 127)
			end
		end
		tx_midi (t, d)
	end
end
