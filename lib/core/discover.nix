# Helpers for discovering content entries in a directory tree.
{
  # discoverEntries: walk a directory, filter by predicate, map each passing
  # entry to a value. The building block for content-kind collectors.
  #
  # Parameters:
  #   baseDir: path to scan (e.g., ./playgrounds)
  #   hasMarker: predicate (name → path → bool); defaults to accept-all
  #   toEntry: value builder (name → path → value)
  #
  # Returns { <name> = <toEntry name path>; ... } for every directory under
  # baseDir that passes hasMarker.
  discoverEntries =
    {
      baseDir,
      hasMarker ? (_name: _path: true),
      toEntry,
    }:
    let
      # Missing baseDir → no entries. Minimal repos often point at
      # content-kind dirs they don't (yet) use; throwing here would
      # force every consumer to maintain stub dirs or wrap each call
      # in pathExists.
      allEntries = if builtins.pathExists baseDir then builtins.readDir baseDir else { };
      names = builtins.filter (
        name: (allEntries.${name} or "regular") == "directory" && hasMarker name (baseDir + "/${name}")
      ) (builtins.attrNames allEntries);
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = toEntry name (baseDir + "/${name}");
      }) names
    );

  # discoverAssets: opt-in convention detector for a single content directory.
  # Returns an attrset of commonly-expected siblings, each null if absent.
  #
  # Intended usage: a flavor's `mkEntry` calls this to auto-detect conventional
  # files without hand-coding pathExists checks:
  #
  #   mkEntry = name: path: let
  #     a = core.discoverAssets path;
  #     manifest = import (path + "/manifest.nix") { inherit name; };
  #   in core.mkChallenge {
  #     inherit name manifest;
  #     inherit (a) body solution static;
  #   };
  #
  # The core library does not itself consume the result, conventions are
  # applied at the call site.
  discoverAssets = dir: {
    body = if builtins.pathExists (dir + "/index.md") then dir + "/index.md" else null;
    solution = if builtins.pathExists (dir + "/solution.md") then dir + "/solution.md" else null;
    static = if builtins.pathExists (dir + "/static") then dir + "/static" else null;
  };
}
