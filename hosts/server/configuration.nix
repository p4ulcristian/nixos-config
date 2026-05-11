{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/packages.nix
    # ../../modules/services.nix  # Enable after secrets are set up
    ../../modules/users.nix
    # ../../modules/secrets.nix   # Enable after secrets are set up
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hostname
  networking.hostName = "nixserver";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";  # Disable after first login
      PasswordAuthentication = true;  # Disable after adding SSH keys
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # Timezone
  time.timeZone = "UTC";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable flakes
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System state version (don't change after install)
  system.stateVersion = "24.05";
}
