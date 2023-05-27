{
  description = "Lifts nix into the modern day";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
  {
    packages.x86_64-linux.unnix =
      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
        };
        stuff = import ./stuff.nix {};
      in
      pkgs.stdenv.mkDerivation rec {
        name = "unnix";
        version = "0.1.0";
        src = ./.;

        configurePhase = "";
        
        buildInputs = with pkgs; [ nim curl ];
        buildPhase = "nim c -d:release --nimcache:cache --skipUserCfg:on --skipParentCfg:on --noNimblePath ${stuff.nimPathArgs} src/unnix.nim";

        installPhase = "
          mkdir -p $out/bin
          cp src/unnix $out/bin/unnix
        ";
      };
    
    packages.x86_64-linux.default = self.packages.x86_64-linux.unnix;
  };
}
