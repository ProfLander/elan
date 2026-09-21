{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, emacs-overlay, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ emacs-overlay.overlays.default ];
      };

      highlight-sexp = pkgs.emacsPackages.trivialBuild {
        pname = "highlight-sexp";
        version = "master";

        src = pkgs.fetchFromGitHub {
          owner = "daimrod";
          repo = "highlight-sexp";
          rev = "master";
          sha256 = "sha256-6XhhfKVTcU6VPa5MZqXMN9x2nmKBTw8FU+SaV7CYnok=";
        };
      };

      emacs = pkgs.emacsWithPackagesFromUsePackage {
        package = pkgs.emacs-pgtk;
        config = ./init.el;
        defaultInitFile = true;
        alwaysEnsure = true;

        extraEmacsPackages = epkgs: [
          highlight-sexp
        ];
      };
    in
    {
      packages.${system}.default = pkgs.buildEnv {
        name = "emacs-environment";

        paths = [
          emacs
          pkgs.wl-clipboard
        ];
      };
    };
}
