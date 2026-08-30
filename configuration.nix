
{ config, lib, pkgs, ... }:

{
	imports = [
		./hardware-configuration.nix
		./nvidia.nix
		./protons.nix
		./obs.nix
	];

	nix.settings."experimental-features" = [
		"nix-command"
		"flakes"
	];

	nixpkgs.config.allowUnfree = true;

	boot.loader.systemd-boot.enable = false;
	boot.loader.efi.canTouchEfiVariables = true;

	boot.loader.limine = {
		enable = true;
		efiSupport = true;
		biosSupport = false;
		maxGenerations = 10;
		secureBoot.enable = false;
	};

	boot.kernelPackages = pkgs.linuxPackages_cachyos;

	networking.hostName = "nixos-celt";
	networking.networkmanager.enable = true;

	time.timeZone = "Europe/Warsaw";
	i18n.defaultLocale = "en_US.UTF-8";

	console = {
		font = "Lat2-Terminus16";
		keyMap = "fi";
	};

	networking.firewall = {
		allowedTCPPorts = [ 49164 ];
		allowedUDPPorts = [ 49164 ];
	};

	users.users.cyhirae = {
		isNormalUser = true;
		shell = pkgs.zsh;

		extraGroups = [
			"networkmanager"
			"wheel"
			"video"
			"input"
		];
	};

	programs.zsh.enable = true;

	programs.hyprland = {
		enable = true;
		withUWSM = true;
		xwayland.enable = true;
	};

	services.displayManager.ly = {
		enable = true;
		x11Support = false;
	};

	programs.steam = {
		enable = true;
		package = pkgs.millennium-steam;
		gamescopeSession.enable = true;
	};

	programs.gamemode.enable = true;
	hardware.graphics = {
		enable = true;
		enable32Bit = true;
	};

	security.polkit.enable = true;
	security.rtkit.enable = true;

	services.dbus.enable = true;
	services.gvfs.enable = true;
	services.udisks2.enable = true;
	services.upower.enable = true;

	services.pipewire = {
		enable = true;
		alsa.enable = true;
		alsa.support32Bit = true;
		pulse.enable = true;
	};

	services.ananicy = {
		enable = true;
		package = pkgs.ananicy-cpp;
		rulesProvider = pkgs.ananicy-rules-cachyos_git;
	};

	environment.systemPackages = with pkgs; [
		git
		neovim
		sbctl
		curl
		wget
		mangohud
		lutris
		easyeffects
	];

	system.stateVersion = "26.05";

}

