{ inputs, ... }:

{
  imports = [
    inputs.flake-file.flakeModules.dendritic
    inputs.flake-aspects.flakeModule
    inputs.flake-parts.flakeModules.modules
  ];

  systems = [ "x86_64-linux" ];

  flake-file.inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-aspects.url = "github:vic/flake-aspects";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
