{
  description = "Omashell, an independent Quickshell desktop shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.omasnap-src = {
    url = "github:omacom/omasnap/v1.26.2";
    flake = false;
  };

  outputs = { self, nixpkgs, omasnap-src, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          omasnap = pkgs.callPackage ./nix/omasnap.nix { src = omasnap-src; };
          omashell = pkgs.callPackage ./nix/package.nix { inherit omasnap; };
        in
        {
          default = omashell;
          omashell = omashell;
          omasnap = omasnap;
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

      homeManagerModules.default =
        { lib, pkgs, ... }:
        {
          imports = [ ./nix/home-manager-module.nix ];
          programs.omashell.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
      homeManagerModules.omashell = self.homeManagerModules.default;

      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
