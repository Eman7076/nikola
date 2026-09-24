# D3 — nixosTest: three-peer WireGuard mesh (rig / controller / conduit)
# Author: Nikola
#
# TEST-ONLY WireGuard keypairs below — disposable, never use in production.
# Nested KVM on Nikola's Grok Bot VM is broken; run this check on the rig
# or any host with working virt:
#
#   nix build -L .#checks.x86_64-linux.d3-wireguard-mesh
#
# Underlay note (D3.1 fix):
#   NixosTest assigns virtualisation.test.nodeNumber by alphabetical attrNames:
#     conduit=1, controller=2, rig=3 → VLAN1 addresses 192.168.1.<n>.
#   Do NOT set networking.interfaces.eth1 addresses — that duplicates/conflicts
#   with the driver's auto underlay. Use hostname Endpoints ("controller:51820")
#   so /etc/hosts from the test driver resolves to the real primary IPs.
#
# Proves:
#   1. underlay ping matrix (hostname) before mesh
#   2. wg show / ip addr / ip route dumped before mesh pings
#   3. every peer pings every other peer over mesh IPs
#   4. stopping one peer does not break connectivity between the remaining two

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

  inventory = import ./peers.nix;
  meshPort = inventory.listenPort;

  mesh = {
    rig = inventory.peers.rig.address;
    controller = inventory.peers.controller.address;
    conduit = inventory.peers.conduit.address;
  };

  # Hostname endpoints — test driver /etc/hosts → real VLAN1 primary IPs.
  testPeers = {
    rig = {
      publicKey = testKeys.rig.public;
      address = mesh.rig;
      endpoint = "rig:${toString meshPort}";
    };
    controller = {
      publicKey = testKeys.controller.public;
      address = mesh.controller;
      endpoint = "controller:${toString meshPort}";
    };
    conduit = {
      publicKey = testKeys.conduit.public;
      address = mesh.conduit;
      endpoint = "conduit:${toString meshPort}";
    };
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

      # Keep VLAN 1; do NOT assign eth1 addresses (driver owns underlay IPs).
      virtualisation.vlans = [ 1 ];
      networking.useDHCP = false;

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
        persistentKeepalive = inventory.persistentKeepalive;
        meshCidr = inventory.meshCidr;
        peers = testPeers;
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

    # --- Diagnostics before mesh pings (failure mode must be obvious) ---
    for m in [rig, controller, conduit]:
        print(f"=== {m.name}: hostname / ip / route / wg show ===")
        print(m.succeed("hostname; echo ---; ip -4 addr; echo ---; ip route; echo ---; wg show wg-court"))

    # Underlay ping matrix via hostnames (resolves to driver-assigned VLAN1 IPs).
    rig.wait_until_succeeds("ping -c 1 -W 2 controller", timeout=30)
    rig.wait_until_succeeds("ping -c 1 -W 2 conduit", timeout=30)
    controller.wait_until_succeeds("ping -c 1 -W 2 rig", timeout=30)
    controller.wait_until_succeeds("ping -c 1 -W 2 conduit", timeout=30)
    conduit.wait_until_succeeds("ping -c 1 -W 2 rig", timeout=30)
    conduit.wait_until_succeeds("ping -c 1 -W 2 controller", timeout=30)

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
