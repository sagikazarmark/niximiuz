{
  description = "niximiuz example content repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    bake.url = "github:sagikazarmark/nix-docker-bake/v0.9.0";
    bake.inputs.nixpkgs.follows = "nixpkgs";

    niximiuz.url = "path:..";
    niximiuz.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      bake,
      niximiuz,
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
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ niximiuz.overlays.default ];
            };
          }
        );

      packagesFor =
        pkgs:
        let
          content = niximiuz.mkContentPipeline {
            inherit pkgs;
            bake = bake.lib;
            root = ./.;
            registry = "ghcr.io/sagikazarmark/niximiuz/examples";
          };
        in
        niximiuz.mkPackages { inherit pkgs content; };
    in
    {
      # Every content + bake artifact the pipeline produces, flattened
      # into a single `packages.<system>.*` namespace. Adding a new
      # manifest.nix (or bake.nix) anywhere under playgrounds/ tutorials/
      # challenges/ ... surfaces here automatically, no flake edit.
      packages = forAllSystems ({ pkgs, ... }: packagesFor pkgs);

      # `nix flake check` from inside example/ exercises the full
      # pipeline (labx rendering, bake scope wiring, channel handling)
      # independently from the niximiuz tests.
      checks = forAllSystems ({ pkgs, ... }: packagesFor pkgs);

      # `nix develop` drops into a shell with the tooling needed for the
      # justfile recipes (labctl for content push, docker for image push
      # via buildx bake, yq-go for reading manifest.yaml slugs).
      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.just
              pkgs.labctl
              pkgs.yq-go
            ];
          };
        }
      );
    };
}
