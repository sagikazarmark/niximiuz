# Tutorial content builder. In static mode (no source), forwards caller's
# args unchanged to core.mkTutorial. In orchestrating mode (source given),
# renders templates via labx and derives body from the rendered index.md.
{
  core,
  content,
  pkgs,
}:
let
  common = import ./common.nix { inherit core content pkgs; };
in
{
  mkTutorial = common.mkChanneled {
    kind = "tutorial";
    coreBuilder = core.mkTutorial;
  };
}
