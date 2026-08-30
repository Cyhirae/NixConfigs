{ config, pkgs, ... }:
let
	rtorrentOpen = pkgs.writeShellScriptBin "rtorrent-open" ''
		exec ${pkgs.kitty}/bin/kitty --class rtorrent -e ${pkgs.rtorrent}/bin/rtorrent "$@"
	'';
in
{
	home.packages = [
		pkgs.rtorrent
		rtorrentOpen
	];
	# Minimal persistent configuration for magnets and torrent files.
	home.file.".rtorrent.rc".text = ''
		directory.default.set = ${config.home.homeDirectory}/Downloads
		session.path.set = ${config.xdg.stateHome}/rtorrent/session
		dht.mode.set = auto
		protocol.pex.set = yes
		trackers.use_udp.set = yes
		network.port_range.set = 49164-49164
		network.port_random.set = no
	'';
	# rTorrent requires its session directory to exist before startup.
	systemd.user.tmpfiles.rules = [
		"d %h/Downloads 0755 - - - -"
		"d %S/rtorrent 0700 - - - -"
		"d %S/rtorrent/session 0700 - - - -"
	];
	xdg.desktopEntries.rtorrent = {
		name = "rTorrent";
		genericName = "BitTorrent Client";
		comment = "Open torrents and magnet links in Kitty";
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
