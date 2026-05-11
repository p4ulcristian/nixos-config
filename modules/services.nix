{ config, pkgs, lib, ... }:

{
  # ============================================
  # Cloudflared Tunnel
  # ============================================

  # Option 1: Using NixOS module (if available in your nixpkgs version)
  # services.cloudflared = {
  #   enable = true;
  #   tunnels = {
  #     "my-tunnel" = {
  #       credentialsFile = config.age.secrets.cloudflared-credentials.path;
  #       default = "http_status:404";
  #       ingress = {
  #         "app.example.com" = "http://localhost:3000";
  #         "ssh.example.com" = "ssh://localhost:22";
  #       };
  #     };
  #   };
  # };

  # Option 2: Manual systemd service (works everywhere)
  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare Tunnel";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "cloudflared";
      Group = "cloudflared";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run";
      Restart = "on-failure";
      RestartSec = "5s";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadOnlyPaths = [ "/" ];
      ReadWritePaths = [ "/etc/cloudflared" ];
    };
  };

  # Create cloudflared user
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
    home = "/var/lib/cloudflared";
    createHome = true;
  };
  users.groups.cloudflared = { };

  # Cloudflared config directory
  # The actual config.yml and credentials will be managed by agenix
  environment.etc."cloudflared/.keep".text = "";

  # ============================================
  # AutoSSH Tunnels
  # ============================================

  # Example: Persistent SSH tunnel for remote access
  systemd.services.autossh-tunnel = {
    description = "AutoSSH Reverse Tunnel";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "tunnel";  # Create dedicated user

      # AutoSSH settings
      Environment = [
        "AUTOSSH_GATETIME=0"
        "AUTOSSH_PORT=0"  # Disable monitoring port, rely on ServerAliveInterval
      ];

      ExecStart = ''
        ${pkgs.autossh}/bin/autossh -M 0 -N \
          -o "ServerAliveInterval=30" \
          -o "ServerAliveCountMax=3" \
          -o "StrictHostKeyChecking=accept-new" \
          -o "ExitOnForwardFailure=yes" \
          -i /home/tunnel/.ssh/tunnel_key \
          -R 2222:localhost:22 \
          tunnel@jump.example.com
      '';

      Restart = "always";
      RestartSec = "10s";
    };
  };

  # Tunnel user for autossh
  users.users.tunnel = {
    isSystemUser = true;
    group = "tunnel";
    home = "/home/tunnel";
    createHome = true;
    shell = pkgs.bash;
  };
  users.groups.tunnel = { };

  # ============================================
  # Additional useful services
  # ============================================

  # Automatic security updates
  system.autoUpgrade = {
    enable = true;
    flake = "/etc/nixos";
    flags = [ "--update-input" "nixpkgs" ];
    dates = "04:00";
    allowReboot = false;  # Set to true for unattended servers
  };

  # Enable fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment.enable = true;
  };

  # Enable automatic TRIM for SSDs
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };
}
