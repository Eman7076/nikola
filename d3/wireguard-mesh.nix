# D3 — Court WireGuard mesh (reusable NixOS module)
# Author: Nikola (Court Contract 001)
#
# Peers (contract names): rig, controller, conduit.
# Private keys: path only (privateKeyFile). Never embed key material here.
# Public keys and endpoints are fine as strings in host config.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.court.wireguard;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    filterAttrs
    mapAttrsToList
    ;

  peerNames = [
    "rig"
    "controller"
    "conduit"
  ];

  peerSubmodule = types.submodule (
    { name, ... }:
    {
      options = {
        publicKey = mkOption {
          type = types.str;
          description = "WireGuard public key (safe to put in git / host config).";
        };
        endpoint = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Optional host:port for this peer. Leave null when the peer is behind
            CGNAT / has no inbound path — that peer must dial out (keepalive).
          '';
          example = "rig.example.net:51820";
        };
        address = mkOption {
          type = types.str;
          description = "Mesh IPv4 address for this peer (inside meshCidr).";
        };
      };
    }
  );

  thisAddress = cfg.peers.${cfg.thisPeer}.address;
  meshPrefixLength =
    let
      parts = lib.splitString "/" cfg.meshCidr;
    in
    if builtins.length parts == 2 then lib.toInt (builtins.elemAt parts 1) else 24;
  # /32 per remote peer — full mesh; hub/spoke can widen AllowedIPs later.
  otherPeers = filterAttrs (n: _: n != cfg.thisPeer) cfg.peers;
in
{
  options.court.wireguard = {
    enable = mkEnableOption "Court WireGuard mesh (rig / controller / conduit)";

    interface = mkOption {
      type = types.str;
      default = "wg-court";
      description = "WireGuard interface name.";
    };

    privateKeyFile = mkOption {
      # String path on the running system (not a store object). agenix/sops
      # expose secret paths as strings; never paste key material into Nix.
      type = types.str;
      description = ''
        Absolute path to this host's WireGuard private key file on disk.
        Required. Do not inline private keys in Nix — use agenix, sops-nix,
        or a root-only file provisioned out of band.
      '';
      example = "/run/secrets/wg-court.key";
    };

    thisPeer = mkOption {
      type = types.enum peerNames;
      description = "Which mesh peer this host is (contract name).";
    };

    meshCidr = mkOption {
      type = types.str;
      default = "10.77.0.0/24";
      description = ''
        IPv4 mesh prefix. Default scheme (documented in d3/README.md):
          rig        = 10.77.0.1
          controller = 10.77.0.2
          conduit    = 10.77.0.3
      '';
    };

    listenPort = mkOption {
      type = types.port;
      default = 51820;
      description = "UDP listen port for WireGuard.";
    };

    persistentKeepalive = mkOption {
      type = types.int;
      default = 25;
      description = ''
        Seconds between keepalive packets to each configured peer.
        Keeps NAT/CGNAT mappings alive when at least one side has a reachable
        endpoint. Set 0 to disable (not recommended for home/CGNAT peers).
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open listenPort/UDP and trust the wg interface for ICMP/mesh traffic.";
    };

    peers = mkOption {
      type = types.attrsOf peerSubmodule;
      description = ''
        All mesh peers keyed by contract name. Must include thisPeer and the
        other two. Each entry needs publicKey + address; endpoint optional.
      '';
      example = {
        rig = {
          publicKey = "REPLACE_RIG_PUBLIC_KEY=";
          address = "10.77.0.1";
          endpoint = "rig.example.net:51820";
        };
        controller = {
          publicKey = "REPLACE_CONTROLLER_PUBLIC_KEY=";
          address = "10.77.0.2";
          endpoint = "controller.example.net:51820";
        };
        conduit = {
          publicKey = "REPLACE_CONDUIT_PUBLIC_KEY=";
          address = "10.77.0.3";
          endpoint = null; # CGNAT — outbound + keepalive only
        };
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.all (n: cfg.peers ? ${n}) peerNames;
        message = "court.wireguard.peers must define rig, controller, and conduit.";
      }
      {
        assertion = cfg.peers ? ${cfg.thisPeer};
        message = "court.wireguard.peers must include thisPeer (${cfg.thisPeer}).";
      }
    ];

    networking.wireguard.interfaces.${cfg.interface} = {
      ips = [ "${thisAddress}/${toString meshPrefixLength}" ];
      listenPort = cfg.listenPort;
      privateKeyFile = cfg.privateKeyFile;
      peers = mapAttrsToList (
        name: peer:
        {
          name = name;
          publicKey = peer.publicKey;
          allowedIPs = [ "${peer.address}/32" ];
          persistentKeepalive = cfg.persistentKeepalive;
        }
        // lib.optionalAttrs (peer.endpoint != null) { endpoint = peer.endpoint; }
      ) otherPeers;
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedUDPPorts = [ cfg.listenPort ];
      trustedInterfaces = [ cfg.interface ];
    };

    environment.systemPackages = [ pkgs.wireguard-tools ];
  };
}
