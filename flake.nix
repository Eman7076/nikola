{
  description = "Nikola — Court contractor deliverables (D1 home + D2 LUKS + D3 WireGuard + D4 ideas + D5 llama CUDA)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      # Pin via flake.lock; git+https avoids GitHub API rate limits on some VMs.
      url = "git+https://github.com/nix-community/disko.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      disko,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # CUDA toolkit is unfree — scoped pkgs for D5 only (does not taint default pkgs).
      pkgsCuda = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations.box = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
          ./modules/devtools.nix
        ];
      };

      packages.${system} = {
        # wg-quick confs for non-NixOS peers (same d3/peers.nix inventory).
        # result → wg-court.conf; private key via PostUp path (never inline).
        wg-conf-rig = import ./d3/wg-conf.nix {
          inherit pkgs;
          thisPeer = "rig";
        };
        wg-conf-conduit = import ./d3/wg-conf.nix {
          inherit pkgs;
          thisPeer = "conduit";
        };
      };

      checks.${system} = {
        d2-luks-eval = import ./d2/eval-luks.nix { inherit pkgs; };
        d2-luks-passphrase = import ./d2/nixos-test.nix { inherit pkgs; };
        d2-disko-layout = import ./d2/nixos-test-disko.nix { inherit pkgs disko; };
        d3-wireguard-eval = import ./d3/eval-wireguard.nix { inherit pkgs; };
        d3-wireguard-mesh = import ./d3/nixos-test.nix { inherit pkgs; };
        # Instantiate D5 CUDA shell drv only — no GPU, no full CUDA build required.
        d5-shell-eval = import ./d5/eval-shell.nix { pkgs = pkgsCuda; };
      };

      devShells.${system} = {
        default = pkgs.mkShell {
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
            wireguard-tools
          ];
        };
        # Optional CUDA llama.cpp shell for the Arch rig (see d5/README.md).
        llama-cuda = import ./d5/shell.nix { pkgs = pkgsCuda; };
        d5 = self.devShells.${system}.llama-cuda;
      };
    };
}
