# D2 — Court flake wiring fragment (copy into the controller / window flake)
# Author: Nikola (Court Contract 001) · Spock D2.1
#
# Target output is .#window until the rename to controller.
# Pin disko to a release that matches your nixpkgs channel when possible.

{
  description = "FRAGMENT — merge into Court flake; not a standalone flake";

  inputs = {
    # …existing Court inputs…
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"; # or Court pin
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      ...
    }:
    {
      # Until rename: nixosConfigurations.window
      # After rename:  nixosConfigurations.controller
      nixosConfigurations.window = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./d2/disko.nix # or path where you vendor these files
          ./d2/luks.nix
          # …existing Court modules (boot.loader, zramSwap, networking, …)…
          # After disko adopt: strip fileSystems."/" and fileSystems."/boot"
          # from hardware-configuration.nix
        ];
      };
    };
}
