{
  description = "Nikola — Court contractor deliverables (D1 home + D2 LUKS drafts)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations.box = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
          ./modules/devtools.nix
        ];
      };

      checks.${system} = {
        d2-luks-eval = import ./d2/eval-luks.nix { inherit pkgs; };
        d2-luks-passphrase = import ./d2/nixos-test.nix { inherit pkgs; };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          ripgrep
          fd
          jq
          helix
          nixfmt-rfc-style
          nil
          statix
          deadnix
        ];
      };
    };
}
