{
  description = "Nikola — Court contractor deliverables (D1 home + D2 LUKS + D3 WireGuard + D4 ideas + D1–D5.5 deliverables + D6 fleet pitch / D6.1–D6.2 / D6.4)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      # D2.2.1: pin to v1.12.0 (nixos-25.05-era). Latest master uses
      # driver.machines_qemu which 25.05's test Driver lacks → AttributeError
      # after install/reboot. nixpkgs 25.05 also packages disko 1.12.0.
      # git+https + explicit rev avoids GitHub API rate limits on this VM.
      url = "git+https://github.com/nix-community/disko.git?ref=refs/tags/v1.12.0&rev=ff442f5d1425feb86344c028298548024f21256d";
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
        # D5.2: JamePeng llama-cpp-python 0.3.49 CUDA (empty d5/patches/). Heavy to *build* without GPU cache.
        llama-cpp-python-cuda = import ./d5/llama-cpp-python.nix {
          pkgs = pkgsCuda;
          patchesDir = ./d5/patches;
        };
      };

      checks.${system} = {
        d2-luks-eval = import ./d2/eval-luks.nix { inherit pkgs; };
        d2-luks-passphrase = import ./d2/nixos-test.nix { inherit pkgs; };
        d2-disko-layout = import ./d2/nixos-test-disko.nix { inherit pkgs disko; };
        d3-wireguard-eval = import ./d3/eval-wireguard.nix { inherit pkgs; };
        d3-wireguard-mesh = import ./d3/nixos-test.nix { inherit pkgs; };
        # D5.2: instantiate shell / python drvs only — no GPU, no full CUDA build.
        d5-shell-eval = import ./d5/eval-shell.nix { pkgs = pkgsCuda; };
        d5-python-eval = import ./d5/eval-python.nix { pkgs = pkgsCuda; };
        d5-python-with-dummy-patch = import ./d5/eval-python-dummy.nix { pkgs = pkgsCuda; };
        # D6.2: one-bell fan-in (eval always; full nixosTest may need Court rig virt).
        d6-one-bell-eval = import ./d6/one-bell/eval-one-bell.nix { inherit pkgs; };
        d6-one-bell = import ./d6/one-bell/nixos-test.nix { inherit pkgs; };
        # D6.4: Spock freshness canary (eval + pure script; no Persistent=true).
        d6-freshness-eval = import ./d6/freshness/eval-freshness.nix { inherit pkgs; };
        d6-freshness-script = import ./d6/freshness/check-canary-script.nix { inherit pkgs; };
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
        # D5.2: CUDA JamePeng llama-cpp-python 0.3.49 + llama-server for the Arch rig (see d5/README.md).
        llama-cuda = import ./d5/shell.nix { pkgs = pkgsCuda; };
        d5 = self.devShells.${system}.llama-cuda;
      };
    };
}
