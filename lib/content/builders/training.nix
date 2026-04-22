# Training content builder. In static mode forwards caller's args to
# core.mkTraining; in orchestrating mode derives body from index.md.
# Program/units are author-supplied (no on-disk discovery for those).
{
  core,
  content,
  pkgs,
}:
let
  common = import ./common.nix { inherit core content pkgs; };
in
{
  mkTraining = common.mkChanneled {
    kind = "training";
    coreBuilder = core.mkTraining;
  };
}
