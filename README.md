# niximiuz

Nix framework for building and publishing content for the
[iximiuz-labs](https://labs.iximiuz.com) platform.

Four layers, each usable on its own:

- **Core** (`./lib/core`), low-level primitives that emit the platform
  output contract (manifest.yaml layout, index.md frontmatter,
  `$out/content/...` file shapes). Plus yaml/image/resolve/utils/check
  helpers.
- **Content** (`./lib/content`), authoring SDK on top of core. Adds
  channels, access control, labx Go-template rendering, and
  channel-iterating builders. This is the higher-level interface authors
  work against.
- **Loaders** (`./lib/loaders`), directory-convention readers. Walk a
  repository laid out as `manifest.nix` + optional `bake.nix` / `vars.nix`
  sidecars, and feed entries into the content builders.
- **Entrypoint** (`default.nix`), `mkContentPipeline` wires all three
  layers together with iximiuz-standard repo conventions (amd64-only
  platforms, ubuntu rootfs default, `live`+extras channel convention,
  `${registry}/${path}:${channel}` moving-tag format).

## Usage

As a flake input:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bake.url = "github:sagikazarmark/nix-docker-bake";
    niximiuz.url = "github:sagikazarmark/niximiuz";  # example URL
  };

  outputs = { self, nixpkgs, bake, niximiuz, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ niximiuz.overlays.default ];
      };

      content = niximiuz.mkContentPipeline {
        inherit pkgs;
        bake = bake.lib;
        root = ./.;
        registry = "ghcr.io/you/your-labs";
        vars = {
          # Threaded into bake moduleArgs for every channel.
          kubeVersion = "v1.34.0";
        };
        # Optional: per-entry data exposed to labx templates under
        # `.Extra.<key>`. Called with `{ bakeScope }` curried in so the
        # wiring can reach module passthru / sibling vars.nix. Compose
        # `lib.loaders.content.mkEntryData` if the `.Extra.bake.*`
        # convention fits; otherwise return whatever shape your templates
        # want.
        # data = { bakeScope }: name: path: { ... };
      };
    in {
      # Nested surface: `content.<kind>.<entry>.<channel>` and
      # `content.bakeFiles.<entry>.<channel>`. Useful for custom projections
      # or if you want to expose a different naming scheme.
      inherit (content) bakeScope bakeFiles playgrounds tutorials challenges trainings courses;

      # Flat projection: `packages.<system>.<kind>-<entry>-<channel>` and
      # `packages.<system>.bake-<entry>-<channel>`. Ready for `nix build`
      # and `nix flake check`.
      packages.${system} = niximiuz.mkPackages { inherit pkgs content; };
    };
}
```

That assumes your repo follows the standard layout:
`playgrounds/<name>/manifest.nix`, `tutorials/<name>/manifest.nix`, etc.,
and optional `bake.nix` / `vars.nix` sidecars next to each playground.
For a complete runnable flake, see `./example/flake.nix`.

## Flake outputs

| Output | Signature | Notes |
| --- | --- | --- |
| `lib.core` | `{ pkgs }: → core // { content = ... }` | Core primitives + content layer as `.content`. |
| `lib.content` | `{ pkgs }: → content` | Content layer on its own (no core attached). |
| `lib.loaders` | `{ bake, content }` | Directory-walk helpers. No `pkgs` at this layer. |
| `lib.flake` | `{ pkgs }: → { flatten, wrapPaths, mkPackages }` | Flake-output shaping. Flatten nested content into `packages.<system>.*`. |
| `mkContentPipeline` | `{ pkgs, bake, root, registry, ... }: → { bakeScope, bakeFiles, playgrounds, tutorials, challenges, trainings, courses }` | Top-level entrypoint. |
| `mkPackages` | `{ pkgs, content }: → { "<kind>-<entry>-<channel>" = drv; ... }` | Shorthand for `lib.flake.mkPackages`. |
| `overlays.default` | overlay providing `pkgs.labctl` + `pkgs.labx` | Required for labx rendering. |
| `packages.*.{labctl, labx}` | CLI tools | Apply via the overlay or reference directly. |

## Pick the right layer

- **Full preset**: use `mkContentPipeline`. Repo conventions baked in.
- **Custom repo layout**: compose `lib.loaders` + `lib.content` + `lib.core` yourself. See `default.nix` for the reference composition.
- **Custom content shape**: `lib.content` is the most repo-neutral.
  Channels + labx + builders, no directory assumptions. Usable from
  non-standard layouts or even programmatic manifest sources.
- **No opinions at all**: use `lib.core` directly. You get the platform
  output contract and nothing else.

## `mkContentPipeline` knobs

```nix
mkContentPipeline {
  # Required
  pkgs, bake, root, registry,

  # Common
  defaultRoot         = "docker-image://.../rootfs:ubuntu-24-04";   # override if needed
  channels            = [ "dev" ];                                   # extra channels; "live" is always present
  vars                = { kubeVersion = "..."; ... };                 # moduleArgs passthrough
  data                = { bakeScope }: name: path: { ... };          # per-entry template data (.Extra.*); default: empty
  extraImageRoots     = [ ];                                         # extra dirs with bake.nix modules

  # Path overrides (defaults follow the standard layout)
  playgroundsDir, tutorialsDir, challengesDir, trainingsDir,
  coursesDir, templatesDir,

  # Escape hatches
  extraBakeModuleArgs     = _channel: {};
  extraBakeLibExtensions  = _channel: _final: _prev: {};
  extraManifestArgs       = _name: _path: _channel: {};              # repo-specific manifest fields
}
```

## Opinions `mkContentPipeline` bakes in

These are the conventions `mkContentPipeline` bakes in. If yours
differ, compose your own entrypoint from the `content/` and `loaders/`
layers instead of using the preset.

- **Platforms**: `[ "linux/amd64" ]`. Hardcoded, the platform is
  single-arch by design.
- **Tag format**: `lib.tag channel "path"` produces
  `${registry}/${path}:${channel}`. `lib.tagTarget channel "path" target`
  adds that as the companion moving tag alongside the content-addressed
  hash tag.
- **vars.nix sidecar**: per-entry `vars.nix` overrides (for both bake
  modules and manifest `.Extra.bake.*` data) picked up automatically.

## Writing a manifest

```nix
# playgrounds/foo/manifest.nix
{ name, channel ? null, registry, defaultRoot, pkgs, lib, images ? {}, ... }:
{
  inherit name;
  title = "Foo";
  channels = {
    live = { name = "foo"; public = true; };
    dev  = { name = "foo.dev"; };
  };
  playground = if channel == null then { } else {
    machines = [ {
      name = "foo";
      drives = [ { source = images.main.passthru.imageRef; } ];
    } ];
  };
}
```

Fields available (via `extraManifestArgs` your entrypoint supplies):
- `name`, `channel`, `pkgs`, `bakeScope`, always provided by niximiuz.
- `images`, when a bake module matches this entry, this is its
  `targets` attrset. Authors reach content-addressed refs via
  `images.<target>.passthru.imageRef`.
- anything you injected in `extraManifestArgs` (pinDigest, custom
  lib helpers, personal defaults, ...).

## License

The project is licensed under the [MIT License](LICENSE).
