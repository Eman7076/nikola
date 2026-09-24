{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # everyday
    git
    ripgrep
    fd
    jq
    eza
    bat
    tree
    curl
    wget
    unzip
    helix

    # nix craft for Court deliverables
    nixfmt-rfc-style
    nil
    statix
    deadnix
    nix-output-monitor

    # light docs / video prep later (CPU); no CUDA claimed here
    ffmpeg
  ];
}
