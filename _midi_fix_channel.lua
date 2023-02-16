ardour {
	["type"]    = "dsp",
	name        = "MIDI fix channel",
	category    = "MIDI", -- "Utility"
	license     = "MIT",
	author      = "Robert Schneider",
	description = [[A MIDI filter that nails all data to one channel.]]
}

function dsp_ioconfig ()
	return { { midi_in = 1, midi_out = 1, audio_in = 0, audio_out = 0}, }
end

function dsp_params ()
	return
	{
		{ ["type"] = "input",
			name = "Channel",
			doc = "Channel to be used for all data",
			min = 1, max = 16, default = 1, enum = true, scalepoints =
			{
				["01"] = 1,
				["02"] = 2,
				["03"] = 3,
				["04"] = 4,
				["05"] = 5,
				["06"] = 6,
				["07"] = 7,
				["08"] = 8,
				["09"] = 9,
				["10"] = 10,
				["11"] = 11,
				["12"] = 12,
				["13"] = 13,
				["14"] = 14,
				["15"] = 15,
				["16"] = 16
			}
		}
	}
end

function dsp_run (_, _, n_samples)
	assert (type(midiin) == "table")
	assert (type(midiout) == "table")
	local cnt = 1
	local ctrl = CtrlPorts:array ()
	local channel = ctrl[1];

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

		if (bit32.band (d[1], 240) ~= 240) then -- not a SYSEX
			d[1] = bit32.band (d[1], 240) + channel - 1
		end
		tx_midi (t, d)
	end
end
