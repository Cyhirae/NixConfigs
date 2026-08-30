# NixConfigs

Personal NixOS configuration built around flakes, Home Manager, Hyprland, and Limine.

> [!WARNING]
> Use with caution. This configuration is personal and may be untested or unsuitable for your hardware and setup.

## What is included

- NixOS configuration managed with a flake
- Home Manager integration
- Hyprland desktop configuration
- Limine bootloader setup
- NVIDIA-specific configuration
- Neovim configuration
- Steam/Proton-related configuration
- Chaotic Nyx packages
- Noctalia Home Manager module
- Millennium Steam client customization

## Repository layout

- `flake.nix` - flake inputs and NixOS system definition
- `configuration.nix` - main NixOS system configuration
- `home.nix` - Home Manager configuration
- `nvidia.nix` - NVIDIA-specific settings
- `nvim.nix` - Neovim configuration
- `protons.nix` - Proton and gaming-related configuration

## Usage

Review the configuration carefully before applying it. In particular, check usernames, hostnames, hardware-specific settings, disks, graphics configuration, and any imported modules.

The flake currently defines the `nixos-celt` NixOS configuration. A typical rebuild command is:

```sh
sudo nixos-rebuild switch --flake .#nixos-celt
```

Do not run the command blindly on another system; adapt the configuration first.
