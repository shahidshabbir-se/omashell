{
  description = "Omashell, an independent Quickshell desktop shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          omashell = pkgs.callPackage ./nix/package.nix { };
        in
        {
          default = omashell;
          omashell = omashell;
        });

      apps = eachSystem (system:
        let
          package = self.packages.${system}.default;
        in
        {
          default = {
            type = "app";
            program = "${package}/bin/omashell";
          };
        });

      homeManagerModules.default = import ./nix/home-manager-module.nix;
      homeManagerModules.omashell = self.homeManagerModules.default;

      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
