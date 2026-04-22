# mkContentKind: discovery + dispatch for directory-per-entry layouts.
#
# Generic over entry shape. The caller provides `mkEntry` to decide what each
# discovered directory maps to. A directory with a `default.nix` short-circuits
# to that file (the escape hatch).
{ discoverEntries }:
let
  defaultHasMarker =
    _name: p:
    builtins.pathExists (p + "/manifest.yaml")
    || builtins.pathExists (p + "/manifest.nix")
    || builtins.pathExists (p + "/default.nix");
in
{
  inherit defaultHasMarker;

  # Parameters:
  #   baseDir: directory to scan
  #   hasMarker: predicate (name: path: bool) for what counts as an entry.
  #                   Defaults to "has manifest.yaml | manifest.nix | default.nix".
  #   mkEntry: (name: path: value), how to build a non-default.nix entry.
  #                   Required.
  #   defaultArgs: (name: path: attrs), args passed when default.nix is
  #                   present. Defaults to { name }.
  mkContentKind =
    {
      baseDir,
      hasMarker ? defaultHasMarker,
      mkEntry,
      defaultArgs ? (name: _path: { inherit name; }),
    }:
    discoverEntries {
      inherit baseDir hasMarker;
      toEntry =
        name: path:
        if builtins.pathExists (path + "/default.nix") then
          import path (defaultArgs name path)
        else
          mkEntry name path;
    };
}
