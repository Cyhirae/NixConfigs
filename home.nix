{ config, pkgs, ... }:

{
	imports = [
		./nvim.nix
		./mpv.nix
		./rtorrent.nix
	];

	home.username = "cyhirae";
	home.homeDirectory = "/home/cyhirae";
	home.stateVersion = "26.05";
	home.sessionVariables = {
		TERMINAL = "kitty";
		EDITOR = "nvim";
		VISUAL = "nvim";
		SUDO_EDITOR = "nvim";
	};


	programs.home-manager.enable = true;

	programs.zsh = {
		enable = true;
		enableCompletion = true;
		autosuggestion.enable = true;
		syntaxHighlighting.enable = true;

		history = {
			size = 10000;
			save = 10000;
			ignoreDups = true;
			share = true;
		};
	};

	programs.fzf = {
		enable = true;
		enableZshIntegration = true;
	};

	programs.zoxide = {
		enable = true;
		enableZshIntegration = true;
	};

	programs.yazi = {
		enable = true;
		enableZshIntegration = true;

		settings = {
			mgr = {
				show_hidden = true;
				sort_by = "natural";
				sort_dir_first = true;
			};

			opener.edit = [
				{
					run = "yazi-edit %s1";
					block = true;
					desc = "Neovim";
					for = "unix";
				}
			];


			open.prepend_rules = [
				{ url = "*.nix"; use = "edit"; }
				{ mime = "text/*"; use = "edit"; }
			];
		};
	};

	programs.noctalia = {
		enable = true;
		systemd.enable = true;

		settings.theme.mode = "dark";
		};


	programs.kitty.enable = true;

	home.packages = with pkgs; [
		brave-origin-nightly
		vscodium
		pwvucontrol
		fastfetch
		btop
		fd
		fzf
		jq
		poppler
		ffmpegthumbnailer
		imagemagick
		p7zip
		ripgrep
		tree
		unar
		unzip
		zoxide
		bottles
		heroic
		vesktop
		davinci-resolve
		ffmpeg

		(writeShellScriptBin "yazi-edit" ''
			file="$1"

			if [ -w "$file" ]; then
				exec nvim -- "$file"
			else
				exec env SUDO_EDITOR=nvim sudoedit -- "$file"
			fi
		'')
	];

	xdg.desktopEntries.yazi = {
		name = "Yazi";
		genericName = "File Manager";
		comment = "Terminal file manager";
		exec = "kitty -e yazi";
		terminal = false;
		categories = [ "System" "FileTools" "FileManager" ];
	};

	wayland.windowManager.hyprland = {
		enable = true;
		configType = "hyprlang";
		systemd.enable = false;

		settings = {
			"$mod" = "SUPER";
			monitor = ",1920x1080@60,0x0,1";

			input = {
				kb_layout = "fi";
				follow_mouse = 1;

				touchpad = {
					natural_scroll = true;
				};
			};

			general = {
				gaps_in = 5;
				gaps_out = 10;
				border_size = 2;
				layout = "dwindle";
			};

			decoration = {
				rounding = 8;

				blur = {
					enabled = true;
					size = 4;
					passes = 2;
				};
			};

			bind = [
				"$mod, SPACE, exec, noctalia msg panel-toggle launcher"
				"$mod, H, exec, noctalia msg panel-toggle session"
				"$mod, T, exec, uwsm app -- kitty"
				"$mod, W, exec, uwsm app -- brave-origin-nightly"
				"$mod, C, exec, uwsm app -- codium"
				"$mod, E, exec, uwsm app -- kitty -e yazi"
				"CTRL ALT, V, exec, uwsm app -- pwvucontrol"
				"$mod, Q, killactive"
				"$mod, F, fullscreen"
				"$mod, V, togglefloating"
				"$mod SHIFT, E, exec, uwsm stop"

				"$mod, 1, workspace, 1"
				"$mod, 2, workspace, 2"
				"$mod, 3, workspace, 3"
				"$mod, 4, workspace, 4"
				"$mod, 5, workspace, 5"

				"$mod SHIFT, 1, movetoworkspace, 1"
				"$mod SHIFT, 2, movetoworkspace, 2"
				"$mod SHIFT, 3, movetoworkspace, 3"
				"$mod SHIFT, 4, movetoworkspace, 4"
				"$mod SHIFT, 5, movetoworkspace, 5"

				"$mod SHIFT, S, exec, noctalia msg screenshot-region"
			];

			bindm = [
				"$mod, mouse:272, movewindow"
				"$mod, mouse:273, resizewindow"
			];
		};
	};
}


