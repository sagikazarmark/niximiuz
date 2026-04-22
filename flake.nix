{
  description = "niximiuz, content framework for iximiuz labs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );

      treefmtFor =
        pkgs:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        };

      # Strip the `content` attr from `./lib/core`'s output so the content
      # layer is fed just the pure-core surface, not the combined bundle.
      pureCore = pkgs: builtins.removeAttrs (import ./lib/core { inherit pkgs; }) [ "content" ];
    in
    {
      # Library surface, four independently importable layers grouped
      # under `lib`. Consumers that only want core primitives use
      # `lib.core { inherit pkgs; }`; orchestrators compose with
      # `lib.content` + `lib.loaders`; flake-consumers hand an
      # `mkContentPipeline` output to `lib.flake.mkPackages` for the
      # flat projection into `packages.<system>.*`.
      lib = {
        # Core primitives (content bundled as `.content` for convenience).
        core = import ./lib/core;

        # Content-authoring SDK: higher-level interface that translates
        # channel / labx / access-control concepts down to the core
        # output format.
        content =
          { pkgs }:
          import ./lib/content {
            inherit pkgs;
            core = pureCore pkgs;
          };

        # Loaders: storage-convention readers. Walk repositories in the
        # iximiuz-standard shape (manifest.nix / bake.nix / vars.nix
        # sidecars) and feed entries into the content builders. Pure
        # attrset of helpers; no `pkgs` at this layer.
        loaders = import ./lib/loaders;

        # Flake helpers: project the nested content-pipeline output
        # into the flat namespace `packages.<system>.*` requires, wrap
        # raw bake-file paths into derivations, etc.
        flake = { pkgs }: import ./lib/flake { inherit pkgs; };
      };

      # Top-level entrypoint: composes core + content + loaders with
      # iximiuz-standard repo conventions. Call with
      # `mkContentPipeline { pkgs; bake; root; registry; ... }`.
      inherit (import ./.) mkContentPipeline;

      # Shorthand for the 90% path: flatten an `mkContentPipeline` output
      # into `packages.<system>.*`. Equivalent to
      # `(lib.flake { inherit pkgs; }).mkPackages content`.
      mkPackages = { pkgs, content }: (import ./lib/flake { inherit pkgs; }).mkPackages content;

      overlays.default = import ./overlay.nix;

      packages = forAllSystems (
        { pkgs, ... }:
        let
          pkgs' = pkgs.extend self.overlays.default;
        in
        {
          labctl = pkgs'.labctl;
          labx = pkgs'.labx;
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: (treefmtFor pkgs).config.build.wrapper);

      checks = forAllSystems (
        { pkgs, ... }:
        {
          tests =
            pkgs.runCommand "niximiuz-tests"
              {
                nativeBuildInputs = [ pkgs.nix ];
                NIX_PATH = "nixpkgs=${nixpkgs}";
              }
              ''
                result=$(nix-instantiate --eval --strict \
                  --option experimental-features "" \
                  ${self}/tests/default.nix 2>&1) || {
                  echo "$result" >&2
                  exit 1
                }
                case "$result" in
                  *"all tests passed"*)
                    echo "$result"
                    touch $out
                    ;;
                  *)
                    echo "$result" >&2
                    exit 1
                    ;;
                esac
              '';

          formatting = (treefmtFor pkgs).config.build.check self;

          integration = import ./tests/integration.nix {
            inherit pkgs;
            core = self.lib.core { inherit pkgs; };
          };

          integration-content = import ./tests/integration-content.nix {
            inherit pkgs;
            content = (self.lib.core { inherit pkgs; }).content;
          };
        }
      );
    };
}
