{ config, pkgs, lib, ... }:

{
  home.username = "iris";
  home.homeDirectory = "/home/iris";
  home.stateVersion = "24.05";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Packages
  home.packages = with pkgs; [
    # Core tools
    git vim curl wget htop tmux jq unzip
    ripgrep fd fzf bat eza

    # Node.js (for claude, railway)
    nodejs_20

    # GitHub CLI
    gh

    # Cloudflare tools
    cloudflared

    # SSH tools
    autossh mosh

    # Networking
    dnsutils
  ];

  # Claude Code CLI wrapper
  home.file.".local/bin/claude" = {
    executable = true;
    text = ''
      #!/bin/bash
      export PATH="${pkgs.nodejs_20}/bin:$PATH"

      # Load API key if available
      if [ -f "$HOME/.anthropic_key" ]; then
        export ANTHROPIC_API_KEY=$(cat "$HOME/.anthropic_key")
      fi

      exec npx -y @anthropic-ai/claude-code "$@"
    '';
  };

  # Railway CLI wrapper
  home.file.".local/bin/railway" = {
    executable = true;
    text = ''
      #!/bin/bash
      export PATH="${pkgs.nodejs_20}/bin:$PATH"
      exec npx -y @railway/cli "$@"
    '';
  };

  # Claude settings (all permissions)
  home.file.".config/claude/settings.json".text = builtins.toJSON {
    permissions = {
      allow = [
        "Bash(*)"
        "Read(*)"
        "Write(*)"
        "Edit(*)"
        "Glob(*)"
        "Grep(*)"
        "WebFetch(*)"
      ];
      deny = [];
    };
  };

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
      # Add local bin to path
      export PATH="$HOME/.local/bin:$PATH"

      # Load secrets if available
      [ -f ~/.secrets ] && source ~/.secrets
    '';
  };

  # Git
  programs.git = {
    enable = true;
    userName = "Iris";
    userEmail = "iris@example.com";
    extraConfig = {
      init.defaultBranch = "main";
      core.editor = "vim";
    };
  };

  # SSH client
  programs.ssh = {
    enable = true;
  };

  # Tmux
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    historyLimit = 10000;
  };
}
