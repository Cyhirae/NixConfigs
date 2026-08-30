{ config, pkgs, ... }:

{
	services.xserver.videoDrivers = [ "nvidia" ];

	hardware.graphics = {
		enable = true;
		enable32Bit = true;
	};

	hardware.nvidia = {
		modesetting.enable = true;

		powerManagement.enable = false;
		powerManagement.finegrained = false;

		open = false;

		nvidiaSettings = true;

		package = pkgs.nvidia_cachyos;
	};
}