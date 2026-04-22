# Repo-level bake primitives. Unopinionated wrapping of nix-docker-bake:
# module discovery, sibling vars.nix overrides, scope building, per-
# channel bake-file collection. No dependency on the content layer.
let
  # discoverBakeModules: walk a directory for subdirs containing bake.nix.
  # Returns { <dirname> = <path-to-bake.nix>; ... }. Compose multiple roots
  # with `//` to build a single `modules` attrset.
  discoverBakeModules =
    baseDir:
    let
      entries = builtins.readDir baseDir;
      subdirs = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
      withBakeNix = builtins.filter (name: builtins.pathExists (baseDir + "/${name}/bake.nix")) subdirs;
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = baseDir + "/${name}/bake.nix";
      }) withBakeNix
    );

  # loadVars: import a sibling vars.nix next to a module's bake.nix, or
  # return {} if no sibling exists.
  loadVars =
    modulePath:
    let
      varsPath = (builtins.dirOf modulePath) + "/vars.nix";
    in
    if builtins.pathExists varsPath then import varsPath else { };

  # mkScope: build a bake scope with sibling vars.nix overrides applied.
  #
  # Thin wrapper over `bake.mkScope` that, after building the base scope,
  # walks every module and applies its sibling `vars.nix` (if any) via
  # `.override`. Scope-internal cross-module references (a module reading
  # `self.${name}`) keep the un-overridden value; external consumers see
  # the vars-applied module on both `scope.<name>` and `scope.modules.<name>`.
  mkScope =
    {
      bake,
      modules,
      moduleArgs ? { },
      lib ? _final: _prev: { },
    }:
    let
      baseScope = bake.mkScope {
        inherit moduleArgs lib modules;
      };

      applyModuleVars =
        name: mod:
        let
          vars = loadVars modules.${name};
        in
        if vars == { } then mod else mod.override vars;

      appliedModules = builtins.mapAttrs applyModuleVars baseScope.modules;
    in
    baseScope // appliedModules // { modules = appliedModules; };

  # collectBakeFiles: for every module, for every channel, materialize a
  # bake-file derivation. `scopeFor channel` is a caller-supplied function
  # that returns the scope for a given channel (typically a closure over
  # channel-aware `moduleArgs` / `lib` that calls `mkScope`).
  #
  # Parallels the content collectors: produces
  # `{ <module> = { <channel> = <file>; ... }; ... }`.
  collectBakeFiles =
    {
      bake,
      modules,
      channels,
      scopeFor,
    }:
    builtins.mapAttrs (
      moduleName: _:
      builtins.listToAttrs (
        map (channel: {
          name = channel;
          value = bake.mkBakeFile (scopeFor channel).modules.${moduleName};
        }) channels
      )
    ) modules;
in
{
  inherit
    discoverBakeModules
    loadVars
    mkScope
    collectBakeFiles
    ;
}
