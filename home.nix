{ config, pkgs, lib, ... }:
{
  home.username = "box";
  home.homeDirectory = "/home/box";
  home.stateVersion = "25.05";

  # Generic Linux (Debian VM), not NixOS.
  targets.genericLinux.enable = true;

  # Keep a durable notes tree inside the flake checkout so hops can restore
  # both tools and working notes from one directory.
  home.sessionVariables = {
    NIKOLA_HOME = "${config.home.homeDirectory}/nikola-home";
    EDITOR = "hx";
  };

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "eza -lah";
      hm-nikola = "home-manager switch --flake ~/nikola-home#box";
    };
    initExtra = ''
      # Nikola D1: prefer flake-managed tools when present
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '';
  };

  programs.git = {
    enable = true;
    userName = "Nikola";
    userEmail = "nikola@court.local";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Symlink the working checkout if we keep it under ~/nikola-home
  # (bootstrap copies /workspace/nikola-home there).
  home.file."nikola-home-README.md".text = ''
    Nikola home flake lives beside this file when you copy the bundle to ~/nikola-home.
    Switch: home-manager switch --flake ~/nikola-home#box
  '';
}
