{
  description = "My Hugo Blog as a Nix Flake";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.hugo-theme-etch = {
    url = "github:LukasJoswiak/etch";
    flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    hugo-theme-etch,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.blog = pkgs.stdenv.mkDerivation {
        name = "blog";
        src = ./blog;
        buildPhase = ''
          mkdir -p themes
          ln -s ${hugo-theme-etch} themes/etch
          ${pkgs.hugo}/bin/hugo --minify
        '';
        installPhase = ''
          cp -r public $out
        '';
        meta = with pkgs.lib; {
          description = "Things I consider interesting";
          license = licenses.mit;
          platforms = platforms.all;
        };
      };
      packages.home = pkgs.stdenv.mkDerivation {
        name = "home";
        src = ./home;
        installPhase = ''
          cp -r . $out
        '';
        meta = with pkgs.lib; {
          description = "My personal Website";
          license = licenses.mit;
          platforms = platforms.all;
        };
      };
      devShell = pkgs.mkShell {
        nativeBuildInputs = [pkgs.hugo];
        buildInputs = [];
      };
    });
}
