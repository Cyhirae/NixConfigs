{ config, pkgs, ... }:

let
	rtorrentOpen = pkgs.writeShellScriptBin "rtorrent-open" ''
		set -eu

		state="${config.xdg.stateHome}/rtorrent"
		watch="$state/watch"
		lock="$state/launcher.lock"

		${pkgs.coreutils}/bin/mkdir -p "$watch"

		queue_torrent() {
			argument="$1"
			identifier="$(${pkgs.coreutils}/bin/printf '%s' "$argument" \
				| ${pkgs.coreutils}/bin/sha256sum \
				| ${pkgs.coreutils}/bin/cut -d ' ' -f 1)"
			temporary="$watch/$identifier.tmp"
			destination="$watch/$identifier.torrent"

			case "$argument" in
				magnet:*)
					length="$(${pkgs.coreutils}/bin/printf '%s' "$argument" \
						| ${pkgs.coreutils}/bin/wc -c \
						| ${pkgs.coreutils}/bin/tr -d ' ')"
					${pkgs.coreutils}/bin/printf 'd10:magnet-uri%s:%se' \
						"$length" "$argument" > "$temporary"
					;;
				file://*)
					path="$(${pkgs.python3}/bin/python -c \
						'import sys, urllib.parse; print(urllib.parse.unquote(urllib.parse.urlparse(sys.argv[1]).path))' \
						"$argument")"
					${pkgs.coreutils}/bin/cp -- "$path" "$temporary"
					;;
				http://*|https://*)
					${pkgs.curl}/bin/curl --fail --location \
						--output "$temporary" "$argument"
					;;
				*)
					${pkgs.coreutils}/bin/cp -- "$argument" "$temporary"
					;;
			esac

			# Atomic rename prevents rTorrent from reading a partial file.
			${pkgs.coreutils}/bin/mv -- "$temporary" "$destination"
		}

		for argument in "$@"; do
			queue_torrent "$argument"
		done

		# Serialize process detection so simultaneous browser clicks do not
		# launch multiple rTorrent instances.
		exec 9>"$lock"
		${pkgs.util-linux}/bin/flock 9

		if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" \
			-x 'rtorrent( main)?' > /dev/null; then
			exit 0
		fi

		exec ${pkgs.kitty}/bin/kitty --class rtorrent \
			-e ${pkgs.rtorrent}/bin/rtorrent
	'';
in
{
	home.packages = [
		pkgs.rtorrent
		rtorrentOpen
	];

	home.file.".rtorrent.rc".text = ''
		directory.default.set = ${config.home.homeDirectory}/Downloads
		session.path.set = ${config.xdg.stateHome}/rtorrent/session
		session.use_lock.set = yes

		dht.mode.set = auto
		protocol.pex.set = yes
		trackers.use_udp.set = yes

		network.port_range.set = 49164-49164
		network.port_random.set = no

		# Browser links are deposited here and loaded by the active session.
		schedule2 = watch_directory,1,2,load.start=${config.xdg.stateHome}/rtorrent/watch/*.torrent

		# Stop seeding by removing completed entries immediately. d.erase
		# removes session metadata and the UI entry but never deletes data.
		method.set_key = event.download.finished,remove_finished,d.erase=

		# Clean up completed entries restored from an older session too.
		method.set_key = event.download.inserted_session,remove_completed,"branch=d.complete=,d.erase="
	'';

	systemd.user.tmpfiles.rules = [
		"d %h/Downloads 0755 - - - -"
		"d %S/rtorrent 0700 - - - -"
		"d %S/rtorrent/session 0700 - - - -"
		"d %S/rtorrent/watch 0700 - - - -"
	];

	xdg.desktopEntries.rtorrent = {
		name = "rTorrent";
		genericName = "BitTorrent Client";
		comment = "Queue torrents and magnet links in rTorrent";
		exec = "rtorrent-open %U";
		terminal = false;
		mimeType = [
			"application/x-bittorrent"
			"x-scheme-handler/magnet"
		];
		categories = [ "Network" "FileTransfer" "P2P" ];
	};

	xdg.mimeApps = {
		enable = true;
		defaultApplications = {
			"application/x-bittorrent" = [ "rtorrent.desktop" ];
			"x-scheme-handler/magnet" = [ "rtorrent.desktop" ];
		};
	};
}
