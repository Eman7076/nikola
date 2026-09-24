# rig = Arch Linux — NOT NixOS.
# Use the wg-quick conf package (same peer inventory as court.wireguard):
#
#   nix build .#wg-conf-rig
#   sudo cp result /etc/wireguard/wg-court.conf   # or result/wg-court.conf if dir
#   # put private key at /etc/wireguard/wg-court.key (see peers.nix privateKeyPath)
#   sudo wg-quick up wg-court
#
# This file is intentionally not a NixOS module.
{ }
