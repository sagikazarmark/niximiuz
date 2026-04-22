# Storage-convention helpers: walk a repository and interpret its on-disk
# layout (manifest.nix / bake.nix / vars.nix sidecars). Each sub-module
# is independently usable; this aggregator is convenience.
{
  bake = import ./bake.nix;
  content = import ./content.nix;
}
