{ config, pkgs, lib, ... }:

{
  # ============================================
  # Main user account
  # ============================================

  users.users.paul = {
    isNormalUser = true;
    description = "Paul";
    extraGroups = [
      "wheel"           # sudo access
      "networkmanager"
      "docker"          # if using docker
    ];

    # SSH public keys for passwordless login
    openssh.authorizedKeys.keys = [
      # Add your SSH public key(s) here
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... paul@machine"
      # "ssh-rsa AAAAB3NzaC1yc2EAAAA... paul@another-machine"
    ];

    # Default shell
    shell = pkgs.bash;  # or pkgs.zsh

    # Create home directory
    createHome = true;
    home = "/home/paul";
  };

  # ============================================
  # Home Manager configuration (optional)
  # ============================================

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.paul = { pkgs, ... }: {
    home.stateVersion = "24.05";

    # User-specific packages
    home.packages = with pkgs; [
      ripgrep
      fd
      fzf
      bat
      eza  # modern ls
    ];

    # Git configuration
    programs.git = {
      enable = true;
      userName = "Paul";
      userEmail = "paul@example.com";  # Update this
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = false;
        core.editor = "vim";
      };
    };

    # GitHub CLI configuration
    programs.gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };

    # Bash configuration
    programs.bash = {
      enable = true;
      shellAliases = {
        ll = "eza -la";
        la = "eza -a";
        l = "eza";
        gs = "git status";
        gd = "git diff";
        gc = "git commit";
        gp = "git push";
      };
      initExtra = ''
        # Claude Code alias (if npx wrapper isn't in path)
        alias claude='npx -y @anthropic-ai/claude-code'
        alias railway='npx -y @railway/cli'

        # Load secrets if available
        if [ -f ~/.secrets ]; then
          source ~/.secrets
        fi
      '';
    };

    # SSH client configuration
    programs.ssh = {
      enable = true;
      matchBlocks = {
        "github.com" = {
          hostname = "github.com";
          user = "git";
          identityFile = "~/.ssh/github_key";
        };
        # Add your jump hosts, servers, etc.
        # "jump" = {
        #   hostname = "jump.example.com";
        #   user = "paul";
        #   identityFile = "~/.ssh/jump_key";
        # };
      };
    };

    # Tmux configuration
    programs.tmux = {
      enable = true;
      terminal = "screen-256color";
      historyLimit = 10000;
      extraConfig = ''
        set -g mouse on
        set -g base-index 1
        setw -g pane-base-index 1
      '';
    };

    # Create directories
    home.file.".ssh/.keep".text = "";
    home.file.".config/claude/.keep".text = "";
  };

  # ============================================
  # Sudo configuration
  # ============================================

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;  # Set to false for passwordless sudo
    extraRules = [
      {
        users = [ "paul" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
