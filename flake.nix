{
	description = "NixOS configuration with Limine, Hyprland, and Home Manager";

	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

		chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		noctalia = {
			url = "github:noctalia-dev/noctalia/v5.0.0-beta.10";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		millennium.url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
	};

	outputs = { nixpkgs, home-manager, noctalia, millennium, chaotic, ... }:
		{
			nixosConfigurations.nixos-celt = nixpkgs.lib.nixosSystem {
				system = "x86_64-linux";

				modules = [

					{
						nixpkgs.overlays = [
							millennium.overlays.default
						];
						
					}

					chaotic.nixosModules.default

					./configuration.nix
					home-manager.nixosModules.home-manager

					{
						home-manager = {
							useGlobalPkgs = true;
							useUserPackages = true;
							backupFileExtension = "hm-backup";
							sharedModules = [
								noctalia.homeModules.default
							];
							users.cyhirae = import ./home.nix;
						};
					}
				];
			};
		};
}

