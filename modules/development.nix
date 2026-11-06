{ pkgs, codex-cli-nix, llm-agents, ... }:
{
  # Allow prebuilt binaries such as VS Code Server's Node.js to run on NixOS.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    git gh curl wget
    vim tmux
    ripgrep fd fzf jq
    btop htop
    pciutils usbutils
    cargo rustc rustfmt clippy
    gcc nodejs python3
  ] ++ [
    codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2
    (pkgs.writeShellScriptBin "opencode" ''
      exec ${llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2}/bin/opencode2 "$@"
    '')
  ];
}
