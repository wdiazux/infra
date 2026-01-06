# NixOS Golden Image Configuration
# This configuration is applied during Packer build to create the golden template.
# Customize this file to bake packages and settings into the template.
#
# Cloud-init integration for Terraform/Proxmox deployment:
# - Hostname: Set via VM name in Terraform
# - IP Address: Set via ipconfig in Terraform
# - SSH Keys: Set via user_account.keys in Terraform (added to default user)
# - User: Default user is 'wdiaz' (configurable via ciuser in Proxmox)

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  # Set your time zone.
  time.timeZone = "America/El_Salvador";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Cloud-init integration for Terraform/Proxmox deployment
  # Manages: hostname, network, SSH keys, and optionally user
  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      # Cloud-init configuration
      system_info = {
        default_user = {
          name = "wdiaz";
          lock_passwd = true;
          gecos = "William Diaz";
          groups = [ "wheel" ];
          sudo = [ "ALL=(ALL) NOPASSWD:ALL" ];
          shell = "/run/current-system/sw/bin/bash";
        };
      };
      # Disable password authentication, use SSH keys only
      ssh_pwauth = false;
      # Allow cloud-init to manage SSH keys
      disable_root = false;
      # Preserve hostname set by cloud-init
      preserve_hostname = false;
    };
  };

  # Networking - cloud-init will configure hostname and IP
  # Fallback to DHCP if cloud-init doesn't provide network config
  networking = {
    hostName = lib.mkDefault "";  # Set by cloud-init
    useDHCP = lib.mkDefault true; # Fallback if cloud-init doesn't configure
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  # Define a user account - this is the base user, cloud-init can add SSH keys
  # Cloud-init SSH keys from Terraform are ADDED to this user's authorized_keys
  users.users = {
    # Default user with passwordless sudo
    wdiaz = {
      isNormalUser = true;
      uid = 1000;
      home = "/home/wdiaz";
      description = "William Diaz";
      extraGroups = [ "wheel" ];
      # Base SSH key - always present. Cloud-init keys are added via ~/.ssh/authorized_keys
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLKAGUPImKUu4nzdZJttQSAsf2lMjZCPFiMcIew6OHu root@wdiaz.org"
      ];
    };

    # Root user SSH access (for Packer provisioning and emergency access)
    root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLKAGUPImKUu4nzdZJttQSAsf2lMjZCPFiMcIew6OHu root@wdiaz.org"
    ];
  };

  # Allow cloud-init to manage mutable user state (SSH keys in ~/.ssh/)
  users.mutableUsers = true;

  # Passwordless sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # QEMU Guest Agent (for Proxmox integration)
  services.qemuGuest.enable = true;


  # System packages
  environment.systemPackages = with pkgs; [
    # Essential tools
    vim
    git
    curl
    wget
    htop
    tmux
    tree
    jq
    ripgrep
    fd

    # System utilities
    pciutils
    usbutils
    lsof
    strace
  ];

  # Nix settings
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # System version - don't change after initial install
  system.stateVersion = "25.11";
}
