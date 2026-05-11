{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    # Core tools
    git
    vim
    curl
    wget
    htop
    tmux
    jq
    unzip
    ripgrep
    fd

    # Node.js (required for claude, railway)
    nodejs_20
    nodePackages.npm

    # GitHub CLI
    gh

    # Cloudflare tools
    cloudflared
    # nodePackages.wrangler  # Uncomment if needed

    # SSH tools
    autossh
    openssh
    mosh

    # Networking
    dnsutils  # for dig
    iproute2
    netcat

    # Claude Code CLI wrapper
    (writeShellScriptBin "claude" ''
      export PATH="${nodejs_20}/bin:$PATH"

      # Set API key if available
      if [ -f "$HOME/.config/claude/api-key" ]; then
        export ANTHROPIC_API_KEY=$(cat "$HOME/.config/claude/api-key")
      fi

      exec npx -y @anthropic-ai/claude-code "$@"
    '')

    # Railway CLI wrapper
    (writeShellScriptBin "railway" ''
      export PATH="${nodejs_20}/bin:$PATH"
      exec npx -y @railway/cli "$@"
    '')
  ];

  # Enable programs that have NixOS modules
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      core.editor = "vim";
    };
  };
}
