{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git gh curl wget
    vim tmux
    ripgrep fd fzf jq
    btop htop
    pciutils usbutils
  ] ++ [ (pkgs.callPackage ../pkgs/codex.nix { }) ];
}
