{ config, pkgs, lib, ... }:

{
  # Main user account
  users.users.iris = {
    isNormalUser = true;
    description = "Iris";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    createHome = true;
    home = "/home/iris";

    # SSH keys (add yours here)
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... iris@machine"
    ];
  };

  # Enable zsh system-wide
  programs.zsh.enable = true;

  # Passwordless sudo for iris
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Home Manager config for iris
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.iris = { pkgs, ... }: {
    home.stateVersion = "24.05";

    # Packages
    home.packages = with pkgs; [
      ripgrep fd fzf bat eza
    ];

    # Zsh with Oh My Zsh
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      oh-my-zsh = {
        enable = true;
        theme = "robbyrussell";
        plugins = [ "git" "docker" "sudo" "history" ];
      };

      shellAliases = {
        ll = "eza -la";
        l = "eza";
        gs = "git status";
        c = "claude";
      };

      initExtra = ''
        # Load secrets if available
        [ -f ~/.secrets ] && source ~/.secrets
      '';
    };

    # Git
    programs.git = {
      enable = true;
      userName = "Iris";
      userEmail = "iris@example.com";
    };

    # SSH client
    programs.ssh = {
      enable = true;
    };
  };
}
