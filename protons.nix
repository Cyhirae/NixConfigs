{ pkgs, ... }:

let
	protonTools = with pkgs; [
		proton-cachyos
		dwproton-bin
	];

	protonToolsPath = pkgs.lib.concatStringsSep ":" (
		map (package: "${package.steamcompattool}") protonTools
		++ [ "/home/cyhirae/.steam/root/compatibilitytools.d" ]
	);

	syncProtonTools = pkgs.writeShellScript "sync-proton-tools" ''
		set -eu

		steam="$HOME/.steam/root/compatibilitytools.d"
		heroic="$HOME/.config/heroic/tools/proton"
		lutris="$HOME/.local/share/lutris/runners/wine"
		bottles="$HOME/.local/share/bottles/runners"

		${pkgs.coreutils}/bin/mkdir -p "$steam" "$heroic" "$lutris" "$bottles"

		link_everywhere() {
			source="$1"
			name="$2"

			for target in "$heroic" "$lutris" "$bottles"; do
				${pkgs.coreutils}/bin/ln -sfn "$source" "$target/$name"
			done
		}

		link_everywhere "${pkgs.proton-cachyos.steamcompattool}" "Proton-CachyOS-Nix"
		link_everywhere "${pkgs.dwproton-bin.steamcompattool}" "DW-Proton-Nix"

		# ProtonUp installs its downloads into Steam's compatibilitytools.d.
		for tool in "$steam"/*; do
			[ -d "$tool" ] || continue
			link_everywhere "$tool" "$(${pkgs.coreutils}/bin/basename "$tool")"
		done
	'';
in
{
	# Installs the ProtonUp CLI plus the declarative Proton builds.
	environment.systemPackages = with pkgs; [
		protonup-ng
		proton-cachyos
		dwproton-bin
	];

	# Steam consumes the Nix packages through its native NixOS option.
	programs.steam.extraCompatPackages = protonTools;

	# Also expose the Nix builds and ProtonUp directory to applications
	# launched from the graphical or terminal session.
	environment.sessionVariables.STEAM_EXTRA_COMPAT_TOOLS_PATHS = protonToolsPath;

	# Share all tools with Heroic, Lutris, and Bottles at login.
	systemd.user.services.proton-tools-sync = {
		description = "Share Proton compatibility tools between game launchers";
		wantedBy = [ "default.target" ];
		serviceConfig = {
			Type = "oneshot";
			ExecStart = syncProtonTools;
		};
	};

	# Repeat the sync whenever ProtonUp changes compatibilitytools.d.
	systemd.user.paths.proton-tools-sync = {
		description = "Watch for ProtonUp compatibility-tool changes";
		wantedBy = [ "default.target" ];
		pathConfig = {
			PathChanged = "%h/.steam/root/compatibilitytools.d";
			Unit = "proton-tools-sync.service";
		};
	};
}
