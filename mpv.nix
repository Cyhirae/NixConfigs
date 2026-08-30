{ ... }:
{
	programs.mpv.enable = true;
	# MPV automatically loads these generated files from ~/.config/mpv/scripts/.
	xdg.configFile = {
		"mpv/scripts/autoskip.lua".text = ''
			local utils = require 'mp.utils'
			mp.commandv("set", "idle", "yes")
			-- options
			local o = {
				enabled       = true,
				op            = (mp.get_opt("skipchap-op") or "1") == "1",
				ed            = (mp.get_opt("skipchap-ed") or "1") == "1",
				prologue      = (mp.get_opt("skipchap-prologue") or "0") == "1",
				prologue_max_start = tonumber(mp.get_opt("skipchap-prologue-max-start")) or 300,
				preroll       = tonumber(mp.get_opt("skipchap-preroll")) or 0.8,
				debug         = (mp.get_opt("skipchap-debug") or "0") == "1",
				op_len_target = tonumber(mp.get_opt("skipchap-op-len-target")) or 90,
				op_len_min    = tonumber(mp.get_opt("skipchap-op-len-min")) or 55,
				op_len_max    = tonumber(mp.get_opt("skipchap-op-len-max")) or 125,
				auto_movie    = (mp.get_opt("skipchap-auto-movie") or "1") == "1",
				movie_len_min = tonumber(mp.get_opt("skipchap-movie-len-min")) or 2700,
			}
			local movie_auto_disabled = false
			local function autoskip_active()
				return o.enabled and not movie_auto_disabled
			end
			local function toggle_autoskip()
				if movie_auto_disabled then
					-- Manual toggle while a movie-length file is open overrides the auto-disable
					-- until the next file is loaded.
					movie_auto_disabled = false
					o.enabled = true
				else
					o.enabled = not o.enabled
				end
				mp.osd_message("Autoskip: " .. (autoskip_active() and "Enabled" or "Disabled"))
			end
			mp.add_key_binding("!", "toggle-autoskip", toggle_autoskip)
			mp.add_key_binding("k", "toggle-autoskip-alt", toggle_autoskip)
			mp.register_script_message("toggle-autoskip", toggle_autoskip)
			mp.osd_message("Autoskip script loaded", 3)
			local function log(m) if o.debug then mp.osd_message("[skipchap] " .. m, 2) end end
			local function lower(s) return (s or ""):lower() end
			local function matches(t, pats)
				t = lower(t or ""); for _, p in ipairs(pats) do if t:find(p, 1, true) then return true end end
				return false
			end
			local function padnum(s) return s:gsub("%d+", function(d) return ("%09d"):format(tonumber(d)) end) end
			local function urldecode(s)
				if not s then return s end
				s = s:gsub("+", " "); return s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
			end
			-- patterns (Intro included for OP selection by proximity)
			local op_pats = {}
			do
				local v = mp.get_opt("skipchap-patterns-op")
				if v and v ~= "" then
					for p in v:gmatch("([^,]+)") do table.insert(op_pats, p:lower()) end
				else
					op_pats = { "intro", "op", "opening" }
				end
			end
			local ed_pats = {}
			do
				local v = mp.get_opt("skipchap-patterns-ed")
				if v and v ~= "" then
					for p in v:gmatch("([^,]+)") do table.insert(ed_pats, p:lower()) end
				else
					ed_pats = { "ed", "ending", "credits", "outro", "closing", "preview", "next" }
				end
			end
			local prologue_pats = {}
			do
				local v = mp.get_opt("skipchap-patterns-prologue")
				if v and v ~= "" then
					for p in v:gmatch("([^,]+)") do table.insert(prologue_pats, p:lower()) end
				else
					prologue_pats = { "prologue" }
				end
			end
			-- file discovery
			local exts = { ".mkv", ".mp4", ".m4v", ".webm", ".avi", ".mov", ".ts", ".m2ts", ".m2t", ".mpg", ".mpeg", ".ogm" }
			local function has_ext(n)
				n = lower(n or ""); for _, e in ipairs(exts) do if n:sub(- #e) == e then return true end end
				return false
			end
			local CUR_FULL = nil
			local function cur_fs_path_now()
				local p = mp.get_property("path")
				if not p or p == "" then return nil, "no path" end
				if p:match("^file://") then
					p = urldecode(p:gsub("^file://", ""))
				elseif p:match("^[%a%d]+://") then
					return nil, "non-local URI"
				end
				if not p:match("^/") then
					local wd = mp.get_property("working-directory") or ""
					if wd == "" then return nil, "no working-directory" end
					p = wd .. "/" .. p
				end
				return p
			end
			local function cur_fs_path()
				local p, err = cur_fs_path_now()
				if p then
					CUR_FULL = p; return p
				end
				if CUR_FULL then return CUR_FULL end
				return nil, err
			end
			local function next_file_in_dir(full_override)
				local full, err
				if full_override then full = full_override else full, err = cur_fs_path() end
				if not full then return nil, err end
				local dir, cur = utils.split_path(full)
				if not dir or not cur then return nil, "split_path failed" end
				local ents = utils.readdir(dir, "files")
				if not ents then return nil, "readdir failed" end
				local vids = {}
				for _, f in ipairs(ents) do if has_ext(f) then table.insert(vids, f) end end
				table.sort(vids, function(a, b) return padnum(a) < padnum(b) end)
				local idx; for i, f in ipairs(vids) do if f == cur or f:lower() == cur:lower() then
						idx = i
						break
					end end
				if not idx then return nil, "current not in dir list" end
				if idx >= #vids then return nil, "current is last" end
				return dir .. vids[idx + 1]
			end
			-- chapter indexing
			local chapters = {}
			local op_idx, ed_idx = nil, nil
			local op_start, op_end = nil, nil
			local ed_start, ed_end = nil, nil
			local op_done, ed_done = false, false
			local ed_is_last = false
			local ed_segments = {}
			local ed_next = 1
			local prologue_segments = {}
			local prologue_next = 1
			local function dur() return mp.get_property_number("duration") or 1e9 end
			local function refresh_movie_autoskip_state(show_osd)
				local d = mp.get_property_number("duration")
				movie_auto_disabled = o.auto_movie and d and d >= o.movie_len_min
				if movie_auto_disabled then
					local msg = ("Autoskip: Disabled for movie-length file (%.0f min)"):format(d / 60)
					if show_osd then mp.osd_message(msg, 3) end
					log(msg)
				end
			end
			local function effectively_last(idx, end_t)
				if not idx then return false end
				if idx == #chapters then return true end
				return end_t and (end_t >= dur() - 0.3)
			end
			local function index_chapters()
				chapters = mp.get_property_native("chapter-list") or {}
				op_idx, ed_idx = nil, nil
				op_start, op_end, ed_start, ed_end = nil, nil, nil, nil
				op_done, ed_done = false, false
				ed_is_last = false
				ed_segments = {}
				ed_next = 1
				prologue_segments = {}
				prologue_next = 1
				if o.debug then
					for i, ch in ipairs(chapters) do
						log(("CH%d @ %.2f : %s"):format(i, ch.time or -1, ch.title or ""))
					end
				end
				-- OP: choose chapter whose LENGTH is closest to target; require window
				if o.op then
					local best_i, best_start, best_end, best_delta = nil, nil, nil, 1 / 0
					for i, ch in ipairs(chapters) do
						if matches(ch.title, op_pats) and ch.time then
							local s = ch.time
							local e = (chapters[i + 1] and chapters[i + 1].time) or dur()
							local L = math.max(0, e - s)
							local d = math.abs(L - o.op_len_target)
							if d < best_delta then
								best_delta = d; best_i = i; best_start = s; best_end = e
							end
						end
					end
					if best_i then
						local L = best_end - best_start
						if L >= o.op_len_min and L <= o.op_len_max then
							op_idx, op_start, op_end = best_i, best_start, best_end
							if o.debug then
								log(("OP pick CH%d len=%.2fs Δ=%.2fs @ %.2fs→%.2fs")
									:format(best_i, L, math.abs(L - o.op_len_target), op_start, op_end))
							end
						else
							-- outside allowed window → do not skip OP
							op_idx, op_start, op_end = nil, nil, nil
							if o.debug then
								log(("no OP in length window [%ds,%ds]; best was %.2fs")
									:format(o.op_len_min, o.op_len_max, L))
							end
						end
					end
				end
				-- Prologue: skip matching chapters near the start separately from OP.
				-- This keeps short prologues from being rejected by the OP length window.
				if o.prologue then
					for i, ch in ipairs(chapters) do
						if matches(ch.title, prologue_pats) and ch.time and ch.time <= o.prologue_max_start then
							local e = (chapters[i + 1] and chapters[i + 1].time) or dur()
							table.insert(prologue_segments, {
								idx = i,
								start = ch.time,
								stop = e,
								is_last = effectively_last(i, e),
							})
						end
					end
				end
				-- ED: skip every matching ED/outro-ish chapter in order. Some files have
				-- both "Ending" and "Preview" chapters; picking only the last one would
				-- leave the earlier ending unskipped.
				if o.ed then
					for i, ch in ipairs(chapters) do
						if matches(ch.title, ed_pats) then
							local s = ch.time
							local e = (chapters[i + 1] and chapters[i + 1].time) or dur()
							table.insert(ed_segments, {
								idx = i,
								start = s,
								stop = e,
								is_last = effectively_last(i, e),
							})
						end
					end
					-- Keep these legacy vars populated for debug/compat assumptions elsewhere.
					if #ed_segments > 0 then
						local last = ed_segments[#ed_segments]
						ed_idx, ed_start, ed_end = last.idx, last.start, last.stop
						ed_is_last = last.is_last
					end
				end
			end
			-- robust advance
			local advancing = false
			local function advance()
				if advancing then log("advance: already advancing"); return false end
				local pos_before = mp.get_property_number("playlist-pos", -1) or -1
				local cnt        = mp.get_property_number("playlist-count", 0) or 0
				-- snapshot path before any commands — path observer can update CUR_FULL async
				local snap_path  = cur_fs_path()
				if pos_before >= 0 and pos_before < (cnt - 1) then
					advancing = true
					mp.command_native({ "playlist-play-index", pos_before + 1 })
					local pos_after = mp.get_property_number("playlist-pos", -1) or -1
					if pos_after == pos_before + 1 then
						mp.set_property_bool("pause", false)
						log("advance via playlist index")
						return true
					end
					advancing = false
				end
				local nxt = next_file_in_dir(snap_path)
				if nxt then
					advancing = true
					mp.command_native({ "loadfile", nxt, "replace" })
					mp.set_property_bool("pause", false)
					log("advance via FS replace")
					return true
				end
				log("no next")
				return false
			end
			-- events
			mp.register_event("file-loaded", function()
				CUR_FULL = cur_fs_path_now() or CUR_FULL
				refresh_movie_autoskip_state(true)
				index_chapters()
				if advancing then
					advancing = false
					mp.set_property_bool("pause", false)
				end
			end)
			mp.observe_property("path", "string", function()
				local p = cur_fs_path_now()
				if p then CUR_FULL = p end
			end)
			mp.observe_property("chapter-list", "native", index_chapters)
			mp.observe_property("time-pos", "number", function(_, t)
				if not t or not autoskip_active() or advancing then return end
				-- Prologue: skip every matching start-of-file prologue segment in sequence.
				if o.prologue and #prologue_segments > 0 then
					while prologue_next <= #prologue_segments do
						local seg = prologue_segments[prologue_next]
						if not seg.start or t < (seg.start - o.preroll) then break end
						prologue_next = prologue_next + 1
						if seg.is_last then
							if advance() then return end
						end
						if seg.stop and seg.stop > t then
							log(("skip Prologue CH%d → %.2fs"):format(seg.idx, seg.stop))
							mp.commandv("seek", seg.stop, "absolute", "exact")
							return
						end
					end
				end
				-- OP
				if o.op and not op_done and op_start and t >= (op_start - o.preroll) then
					op_done = true
					if effectively_last(op_idx, op_end) then
						advance()
					elseif op_end and op_end > t then
						log(("skip OP → %.2fs"):format(op_end))
						mp.commandv("seek", op_end, "absolute", "exact")
					end
				end
				-- ED/outro/preview: skip every matching segment in sequence.
				if o.ed and #ed_segments > 0 then
					while ed_next <= #ed_segments do
						local seg = ed_segments[ed_next]
						if not seg.start or t < (seg.start - o.preroll) then break end
						ed_next = ed_next + 1
						if seg.is_last then
							if advance() then return end
						end
						if seg.stop and seg.stop > t then
							log(("skip ED CH%d → %.2fs"):format(seg.idx, seg.stop))
							mp.commandv("seek", seg.stop, "absolute", "exact")
							return
						end
					end
				end
			end)
			-- EOF fallback
			mp.register_event("end-file", function(ev)
				if advancing then
					log("EOF ignored (already advancing)")
					return
				end
				if autoskip_active() and ev.reason == "eof" and not advancing then
					log("EOF → advance (single trigger)")
					advance()
				end
			end)
		'';
		"mpv/scripts/subselect.lua".text = ''
			-- subselect.lua — pick best subtitle track
			local priorities = {
				"shadycrab", -- Azael's preferred release group
				"dialogue", -- prefer subtitle tracks with this keyword
				"english",
				"en",
			}
			local function lower(s) return (s or ""):lower() end
			local function is_forced_sub(s)
				local title = lower(s.title or "")
				return s.forced or title:find("forced", 1, true) ~= nil
			end
			-- CC/SDH tracks duplicate dialogue with sound cues (e.g. "[door slams]", "[music]")
			-- and are usually not what you want when a regular sub exists.
			local function is_cc_sdh(s)
				local title = lower(s.title or "")
				return title:find("cc", 1, true) ~= nil
						or title:find("sdh", 1, true) ~= nil
			end
			local function find_first(subs, pat, allow_forced, allow_cc)
				for i = #subs, 1, -1 do
					local s = subs[i]
					local title = lower(s.title or "")
					local lang  = lower(s.lang or "")
					local forced = is_forced_sub(s)
					local cc     = is_cc_sdh(s)
					if (allow_forced or not forced)
							and (allow_cc or not cc)
							and (title:find(pat, 1, true) or lang == pat) then
						return s
					end
				end
				return nil
			end
			mp.register_event("file-loaded", function()
				local tracks = mp.get_property_native("track-list") or {}
				local subs = {}
				for _, t in ipairs(tracks) do
					if t.type == "sub" and not t.external then
						table.insert(subs, t)
					end
				end
				if #subs == 0 then return end
				for _, pat in ipairs(priorities) do
					-- 1st pass: non-forced, non-CC/SDH (preferred)
					local pick = find_first(subs, pat, false, false)
					-- 2nd pass: still skip forced, but allow CC/SDH if no clean match
					if not pick then pick = find_first(subs, pat, false, true) end
					-- 3rd pass: allow forced too (only as last resort within this priority)
					if not pick then pick = find_first(subs, pat, true,  true) end
					if pick then
						mp.set_property_number("sid", pick.id)
						mp.osd_message("Auto-selected subtitle: "..(pick.title or pick.lang or "?"), 3)
						return
					end
				end
				-- fallback to first subtitle
				mp.set_property_number("sid", subs[1].id)
				mp.osd_message("Fallback subtitle: "..(subs[1].title or subs[1].lang or "?"), 3)
			end)
		'';
	};
}
