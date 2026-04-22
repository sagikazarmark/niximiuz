# Repo-level content pipeline primitives. Unopinionated plumbing around
# per-kind loaders, manifest-arg assembly, template directory resolution,
# and per-entry data. No flavor or personal-layer assumptions; opinions
# live one layer up.
let
  # mkTemplateDirs: factory for the per-entry template-dirs resolver. The
  # returned function takes an entry path and prepends any per-entry
  # `templates/` directory to the supplied globals. Non-existent globals
  # are silently dropped, a repo that doesn't maintain an `_templates/`
  # tree shouldn't fail eval over it.
  mkTemplateDirs =
    { globals }:
    path:
    let
      existingGlobals = builtins.filter builtins.pathExists globals;
      perEntry = if builtins.pathExists (path + "/templates") then [ (path + "/templates") ] else [ ];
    in
    existingGlobals ++ perEntry;

  # mkManifestArgs: build the function that feeds arguments into every
  # entry's `manifest.nix`. Returns a generic set (name, channel, pkgs);
  # when a `bakeScope` is supplied, additionally injects the per-name
  # bake-module targets and exposes `bakeScope` itself. Consumers layer
  # additional fields via `extras name path channel`.
  mkManifestArgs =
    {
      pkgs,
      bakeScope ? null,
      extras ?
        _name: _path: _channel:
        { },
    }:
    name: path: channel:
    {
      inherit name channel pkgs;
    }
    // (
      if bakeScope != null then
        {
          images = bakeScope.modules.${name}.targets or { };
          inherit bakeScope;
        }
      else
        { }
    )
    // (extras name path channel);

  # mkEntryData: factory for the per-entry `.Extra.bake.*` data fn. Merges
  # the caller-supplied `bakeConfigData` (static across entries) with a
  # sibling `vars.nix` when present. Entries without a `vars.nix` just
  # get `bakeConfigData`; callers that want a fallback (e.g. from
  # bakeScope module `passthru.vars`) wrap this helper or write their
  # own fn, the library stays agnostic of scope shape.
  mkEntryData =
    { bakeConfigData }:
    name: path:
    let
      varsPath = path + "/vars.nix";
      siblingVars = if builtins.pathExists varsPath then import varsPath else { };
    in
    {
      bake = bakeConfigData // siblingVars;
    };

  # mkCollectors: compose a set of flavor builders into repo-walking
  # loaders. Given a `perKind` map of flavor builders (each takes
  # `{ name, source, loadManifest, templateDirs, data }` and returns
  # per-channel outputs), produces the same keys as
  # `baseDir -> { <entry> = <per-channel-drvs>; ... }` functions.
  #
  # The flavor builder owns the authoring→core translation (labx render,
  # body extraction, access control, etc.). This helper only walks the
  # directory and wires each entry's path to its flavor builder.
  mkCollectors =
    {
      perKind,
      core,
      manifestArgs,
      templateDirs,
      data,
    }:
    builtins.mapAttrs (
      _kind: flavorBuilder: baseDir:
      core.discoverEntries {
        inherit baseDir;
        hasMarker = _name: p: builtins.pathExists (p + "/manifest.nix");
        toEntry =
          name: path:
          flavorBuilder {
            inherit name;
            loadManifest = channel: import (path + "/manifest.nix") (manifestArgs name path channel);
            source = path;
            templateDirs = templateDirs path;
            data = data name path;
          };
      }
    ) perKind;
in
{
  inherit
    mkTemplateDirs
    mkManifestArgs
    mkEntryData
    mkCollectors
    ;
}
