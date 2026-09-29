{ lib, ... }:
{
  imports = [
    ./disko.nix
    ../../modules/base.nix
    ../../modules/networking.nix
    ../../modules/ssh.nix
    ../../modules/development.nix
    ../../modules/ddns-go.nix
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix)
    ./hardware-configuration.nix;

  networking.hostName = "minipc";

  # Generic initrd coverage for the first install, before real hardware data exists.
  boot.initrd.availableKernelModules = [
    "nvme" "ahci" "xhci_pci" "usb_storage" "usbhid" "sd_mod"
  ];
  hardware.enableRedistributableFirmware = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # First installation is on NixOS 26.05. Keep this value across later upgrades.
  system.stateVersion = "26.05";
}
