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
        nativeBuildInputs = [pkgs.texlive.combined.scheme-small];
        buildPhase = ''
          mkdir -p dist
          ${pkgs.pandoc}/bin/pandoc src/cv.md -f markdown -t pdf -V geometry:"top=2cm" -o dist/cv.pdf
          ${pkgs.pandoc}/bin/pandoc src/cv.md -f markdown -t html -H src/pandoc.css --metadata pagetitle="David Sierra CV" -s -o dist/cv.html
          ${pkgs.pandoc}/bin/pandoc src/cv.md -f markdown -t odt -o dist/cv.odt
          ${pkgs.pandoc}/bin/pandoc src/cv.md -f markdown -t markdown -o dist/cv.md
          rm -r src
        '';
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
