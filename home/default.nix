{ config, pkgs, lib, ... }:

{
  home.username = "iris";
  home.homeDirectory = "/home/iris";

  nixpkgs.config.allowUnfree = true;
  home.stateVersion = "24.05";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Packages
  home.packages = with pkgs; [
    # Core tools
    git vim curl wget htop tmux jq unzip
    ripgrep fd fzf bat eza

    # GitHub CLI
    gh

    # 1Password CLI
    _1password-cli

    # Cloudflare tools
    cloudflared

    # Railway CLI
    railway

    # SSH tools
    autossh mosh

    # Networking
    dnsutils

    # Secrets management
    sops age

    # JS / Node
    bun
    nodejs_22

    # JVM (iris-os, manas, ironrainbow run on Clojure)
    temurin-bin-21
    clojure

    # Python (iris-stt, iris-tts)
    python311
    uv

    # Database (iris-os) — includes psql + server binaries
    postgresql_18

    # Schema sync tool (iris-os uses psqldef)
    sqldef

    # Audio (iris-os /api/transcribe + /api/turn-check shell out to ffmpeg)
    ffmpeg
  ];

  # Install Claude Code via curl (always latest)
  home.activation.installClaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.local/bin/claude" ]; then
      export PATH="${pkgs.curl}/bin:${pkgs.coreutils}/bin:${pkgs.gzip}/bin:${pkgs.gnutar}/bin:$PATH"
      $DRY_RUN_CMD ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | $DRY_RUN_CMD ${pkgs.bash}/bin/bash
    fi
  '';

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
      claude = "~/.local/bin/claude --dangerously-skip-permissions";
      c = "~/.local/bin/claude --dangerously-skip-permissions";
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
    settings = {
      user.name = "Paul";
      user.email = "p4ulcristian@gmail.com";
      init.defaultBranch = "main";
      core.editor = "vim";
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };

  # SSH client
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "ssh.inventoriwill.com" = {
        proxyCommand = "cloudflared access ssh --hostname %h";
      };
    };
  };

  # Tmux
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    historyLimit = 10000;
  };
}
