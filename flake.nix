{
  description = "Preconfigured NixOS with claude, railway, gh, cloudflared";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, agenix, home-manager, ... }@inputs:
    let
      # Support both architectures
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];

      # Create pkgs for a given system
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          })
          (import ./overlays/claude.nix)
          (import ./overlays/railway.nix)
        ];
      };

      # Create a NixOS configuration for a given system
      mkSystem = system: modules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          pkgs = mkPkgs system;
        };
        inherit modules;
      };

    in {
      # ===== x86_64-linux configurations =====

      nixosConfigurations.server = mkSystem "x86_64-linux" [
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        ./hosts/server/configuration.nix
      ];

      nixosConfigurations.iso = mkSystem "x86_64-linux" [
        agenix.nixosModules.default
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        ./iso.nix
      ];

      # Auto-install ISO (boots and installs automatically)
      nixosConfigurations.iso-autoinstall = mkSystem "x86_64-linux" [
        ./iso-autoinstall.nix
      ];

      # ===== aarch64-linux configurations (for ARM Macs) =====

      nixosConfigurations.server-arm = mkSystem "aarch64-linux" [
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        ./hosts/server/configuration.nix
      ];

      nixosConfigurations.iso-arm = mkSystem "aarch64-linux" [
        agenix.nixosModules.default
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        ./iso.nix
      ];
    };
}
