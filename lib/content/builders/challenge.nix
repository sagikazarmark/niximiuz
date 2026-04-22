# Challenge content builder. Adds `solution` to the default tutorial-style
# shape by reading solution.md from the rendered output (when present).
{
  core,
  content,
  pkgs,
}:
let
  common = import ./common.nix { inherit core content pkgs; };
in
{
  mkChallenge = common.mkChanneled {
    kind = "challenge";
    coreBuilder = core.mkChallenge;
    builderArgs =
      args@{ rendered, ... }:
      let
        solutionPath = "${rendered}/solution.md";
      in
      common.defaultBuilderArgs args
      // {
        solution = if builtins.pathExists solutionPath then builtins.readFile solutionPath else null;
      };
  };
}
