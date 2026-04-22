# niximiuz example

A minimal content repository demonstrating `mkContentPipeline`. Each
content kind has exactly one entry so the full authoring surface is
covered without dragging in repo-specific conventions.

## Layout

```
example/
├── flake.nix
├── justfile
├── playgrounds/
│   └── niximiuz-example/: playground; builds a rootfs image
├── tutorials/
│   └── niximiuz-example/: markdown + labx template variables
└── challenges/
    └── niximiuz-example/: index.md + solution.md
```

## Building

The flake auto-flattens every content entry into
`packages.<system>.<kind>-<entry>-<channel>`. Adding a new manifest.nix
under any content directory surfaces automatically, no flake edit.

```bash
nix flake show                                          # list everything
nix flake check                                         # build every content derivation
nix build .#playground-hello-live                       # single entry
nix build .#bake-hello-live                             # bake file for an image
```

## Publishing

A `justfile` wraps the push workflow. Drop into the devshell and go:

```bash
nix develop                                             # labctl + yq + just
just build playground niximiuz-example live             # nix build → store path
just push-content challenge niximiuz-example dev        # labctl content push
just push-image niximiuz-example live                   # docker buildx bake --push
just push playground niximiuz-example live              # image then manifest
```

Images push to `ghcr.io/sagikazarmark/niximiuz/examples/playgrounds/<name>:<channel>`.
The registry is hardcoded in `flake.nix`, consumers building their own
content repo should point their flake at a registry they control.

## Integration testing

`just test` runs each content kind against the live platform via
`labctl`. Push first, authenticate (`labctl auth login ...`), then:

```bash
just test playground niximiuz-example live   # start → ssh tests.sh → destroy
just test tutorial niximiuz-example live     # start → solver → wait on tasks
just test challenge niximiuz-example live    # same flow as tutorial
```

Playgrounds run `playgrounds/<name>/tests.sh` over SSH. Tutorials and
challenges run `<kind>s/<name>/solution/run.sh` against a running
session, then `labctl playground tasks --wait --fail-fast` drains the
`tasks = { ... }` block in the manifest. Both use the example
playground as the session host; the tutorial/challenge manifests
reference it by slug.

## What CI does with this

`nix flake check` is run as a standalone job, independent from the
parent niximiuz tests. The parent flake exposes the framework itself;
this flake exposes content *produced* by the framework, so a regression
in either layer surfaces from a different angle.

## Reference, not template

This directory intentionally lives inside the niximiuz source tree: the
flake input reads `niximiuz.url = "path:.."`, which means every example
build is against the current working tree. A formal template that
scaffolds a new repo from this layout is out of scope here.
