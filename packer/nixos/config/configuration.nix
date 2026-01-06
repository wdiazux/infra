# NixOS Golden Image Configuration
# This configuration is applied during Packer build to create the golden template.
# Customize this file to bake packages and settings into the template.
#
# Cloud-init integration: Hostname and networking are configured by Proxmox cloud-init
# when deploying via Terraform. Set vm_name and ipconfig in Terraform to configure.

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
  # Hostname and IP are set via Proxmox cloud-init drive
  services.cloud-init = {
    enable = true;
    network.enable = true;
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    # Default user with passwordless sudo
    wdiaz = {
      isNormalUser = true;
      uid = 1000;
      initialPassword = "password";
      home = "/home/wdiaz";
      description = "William Diaz";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLKAGUPImKUu4nzdZJttQSAsf2lMjZCPFiMcIew6OHu root@wdiaz.org"
      ];
    };

    # Root user SSH access
    root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLKAGUPImKUu4nzdZJttQSAsf2lMjZCPFiMcIew6OHu root@wdiaz.org"
    ];
  };

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
