{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    # Core tools
    git vim curl wget htop tmux jq unzip
    ripgrep fd

    # Node.js (for claude, railway)
    nodejs_20

    # GitHub CLI
    gh

    # Cloudflare tools
    cloudflared

    # SSH tools
    autossh openssh mosh

    # Networking
    dnsutils iproute2

    # Claude Code CLI
    (writeShellScriptBin "claude" ''
      export PATH="${nodejs_20}/bin:$PATH"

      # Load API key if available
      if [ -f "$HOME/.anthropic_key" ]; then
        export ANTHROPIC_API_KEY=$(cat "$HOME/.anthropic_key")
      fi

      exec npx -y @anthropic-ai/claude-code "$@"
    '')

    # Railway CLI
    (writeShellScriptBin "railway" ''
      export PATH="${nodejs_20}/bin:$PATH"
      exec npx -y @railway/cli "$@"
    '')
  ];

  # System-wide Claude settings
  environment.etc."claude/settings.json".text = builtins.toJSON {
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

  # Git config
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      core.editor = "vim";
    };
  };
}
