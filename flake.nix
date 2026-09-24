{
  description = "Nikola — Court contractor home for the Grok Bot / sandbox VM (survives hops via this flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    # Apply on this VM (Debian-class userland, no NixOS):
    #   nix run home-manager/release-25.05 -- switch --flake /path/to/nikola-home#box
    # Later hops, once HM is on PATH:
    #   home-manager switch --flake /path/to/nikola-home#box
    homeConfigurations.box = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home.nix
        ./modules/devtools.nix
      ];
    };

    # Convenience: nix develop .  → shell with the same tools without switching
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        git ripgrep fd jq helix nixfmt-rfc-style
        nil statix deadnix
      ];
    };
  };
}
