{
  description = "Minimal NixOS configuration for an AI coding Mini PC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    llm-agents.url = "github:numtide/llm-agents.nix";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, disko, codex-cli-nix, llm-agents, ... }:
    let
      system = "x86_64-linux";
      # Change this before installation if you want a different login name.
      username = "yulinye";
    in {
      nixosConfigurations.minipc = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit username codex-cli-nix llm-agents; };
        modules = [
          disko.nixosModules.disko
          ./hosts/minipc/default.nix
        ];
      };
    };
}
