{ config, pkgs, lib, ... }:

{
  # ============================================
  # Agenix Secrets Configuration
  # ============================================

  # Path to age identity file for decryption at boot
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"  # Use system SSH key
    # "/home/paul/.config/agenix/key.txt"  # Or user key
  ];

  # ============================================
  # Secret definitions
  # ============================================

  age.secrets = {
    # Cloudflared tunnel credentials
    cloudflared-credentials = {
      file = ../secrets/cloudflared-credentials.age;
      path = "/etc/cloudflared/credentials.json";
      owner = "cloudflared";
      group = "cloudflared";
      mode = "0400";
    };

    # Cloudflared config (contains tunnel ID, etc.)
    cloudflared-config = {
      file = ../secrets/cloudflared-config.age;
      path = "/etc/cloudflared/config.yml";
      owner = "cloudflared";
      group = "cloudflared";
      mode = "0400";
    };

    # GitHub CLI token
    gh-token = {
      file = ../secrets/gh-token.age;
      path = "/home/paul/.config/gh/hosts.yml";
      owner = "paul";
      group = "users";
      mode = "0600";
    };

    # Anthropic API key for Claude
    anthropic-api-key = {
      file = ../secrets/anthropic-api-key.age;
      path = "/home/paul/.config/claude/api-key";
      owner = "paul";
      group = "users";
      mode = "0600";
    };

    # Railway token
    railway-token = {
      file = ../secrets/railway-token.age;
      path = "/home/paul/.config/railway/config.json";
      owner = "paul";
      group = "users";
      mode = "0600";
    };

    # AutoSSH tunnel private key
    tunnel-ssh-key = {
      file = ../secrets/tunnel-ssh-key.age;
      path = "/home/tunnel/.ssh/tunnel_key";
      owner = "tunnel";
      group = "tunnel";
      mode = "0600";
    };

    # Shell secrets (environment variables)
    shell-secrets = {
      file = ../secrets/shell-secrets.age;
      path = "/home/paul/.secrets";
      owner = "paul";
      group = "users";
      mode = "0600";
    };
  };

  # ============================================
  # Environment variables from secrets
  # ============================================

  # Load API keys as environment variables for services
  systemd.services.cloudflared-tunnel.serviceConfig.EnvironmentFile =
    config.age.secrets.shell-secrets.path;

  # For user sessions, secrets are sourced from ~/.secrets in .bashrc
}
