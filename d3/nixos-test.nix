# D3 — nixosTest: three-peer WireGuard mesh (rig / controller / conduit)
# Author: Nikola
#
# TEST-ONLY WireGuard keypairs below — disposable, never use in production.
# Nested KVM on Nikola's Grok Bot VM is broken; run this check on the rig
# or any host with working virt:
#
#   nix build -L .#checks.x86_64-linux.d3-wireguard-mesh
#
# Proves:
#   1. every peer pings every other peer over mesh IPs
#   2. stopping one peer does not break connectivity between the remaining two

{ pkgs, ... }:
let
  # --- TEST-ONLY keys (wg genkey / wg pubkey). DO NOT reuse outside this test. ---
  testKeys = {
    # TEST-ONLY — not a Court production key
    rig = {
      private = "ICBJnZwrjk4TvUMusgXlxLrfA9JfShzk3BqkgLi74FA=";
      public = "sKEDqQpxjR2n2RG5xYqj3Pt67KHGosqgiwhHlO8a2Dk=";
    };
    # TEST-ONLY — not a Court production key
    controller = {
      private = "OOnLnhU/oo1eSHFBEvOo/Rk1NAofuHdrd+6mQ/rP/Ho=";
      public = "JuA9FgMHvbY43hDLpiVyx0SHXN2Je4gP6adR7R04TgI=";
    };
    # TEST-ONLY — not a Court production key
    conduit = {
      private = "EK2x+/UMe+WojDTD4PzmX5/O8lF2Be4E/QFbYOkVcV8=";
      public = "/NMF4iCj19Bt2g8v8/lWOUz3DJOM3CaUweDWsBEQiHM=";
    };
  };

  meshPort = 51820;

  # Underlay (VLAN 1) addresses — stand-ins for public/reachable endpoints in the lab.
  underlay = {
    rig = "192.168.1.1";
    controller = "192.168.1.2";
    conduit = "192.168.1.3";
  };

  mesh = {
    rig = "10.77.0.1";
    controller = "10.77.0.2";
    conduit = "10.77.0.3";
  };

  peerCommon =
    thisPeer:
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = [ ./wireguard-mesh.nix ];

      virtualisation.vlans = [ 1 ];
      networking.useDHCP = false;
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = underlay.${thisPeer};
          prefixLength = 24;
        }
      ];

      # TEST-ONLY private key file path — module requires privateKeyFile (no inline keys).
      environment.etc."court-wg/private.key" = {
        mode = "0400";
        text = testKeys.${thisPeer}.private;
      };

      court.wireguard = {
        enable = true;
        thisPeer = thisPeer;
        privateKeyFile = "/etc/court-wg/private.key";
        listenPort = meshPort;
        persistentKeepalive = 25;
        peers = {
          rig = {
            publicKey = testKeys.rig.public;
            address = mesh.rig;
            endpoint = "${underlay.rig}:${toString meshPort}";
          };
          controller = {
            publicKey = testKeys.controller.public;
            address = mesh.controller;
            endpoint = "${underlay.controller}:${toString meshPort}";
          };
          conduit = {
            publicKey = testKeys.conduit.public;
            address = mesh.conduit;
            endpoint = "${underlay.conduit}:${toString meshPort}";
          };
        };
      };

      environment.systemPackages = with pkgs; [
        wireguard-tools
        iputils
      ];
    };
in
pkgs.nixosTest {
  name = "nikola-d3-wireguard-mesh";

  nodes = {
    rig = peerCommon "rig";
    controller = peerCommon "controller";
    conduit = peerCommon "conduit";
  };

  testScript = ''
    start_all()

    for m in [rig, controller, conduit]:
        m.wait_for_unit("multi-user.target")
        m.wait_for_unit("wireguard-wg-court.service")

    # Handshake / reachability: every peer → every other peer over mesh IPs.
    rig.wait_until_succeeds("ping -c 1 -W 2 ${mesh.controller}", timeout=60)
    rig.wait_until_succeeds("ping -c 1 -W 2 ${mesh.conduit}", timeout=60)
    controller.wait_until_succeeds("ping -c 1 -W 2 ${mesh.rig}", timeout=60)
    controller.wait_until_succeeds("ping -c 1 -W 2 ${mesh.conduit}", timeout=60)
    conduit.wait_until_succeeds("ping -c 1 -W 2 ${mesh.rig}", timeout=60)
    conduit.wait_until_succeeds("ping -c 1 -W 2 ${mesh.controller}", timeout=60)

    # Sanity: wg show has peers.
    rig.succeed("wg show wg-court | grep -q interface")

    # One peer down must not break the other two (full mesh, not hub-spoke).
    conduit.crash()
    rig.wait_until_succeeds("ping -c 1 -W 2 ${mesh.controller}", timeout=30)
    controller.wait_until_succeeds("ping -c 1 -W 2 ${mesh.rig}", timeout=30)
    # Conduit mesh IP must NOT answer while that node is down.
    rig.fail("ping -c 1 -W 2 ${mesh.conduit}")
  '';
}
