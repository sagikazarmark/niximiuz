# Core library primitives. Also bundles the content-authoring layer as
# the `content` attribute for convenience; use `removeAttrs ... [ "content" ]`
# to get the pure-core surface.
# Usage: import ./nix/niximiuz/lib/core { inherit pkgs; }
{ pkgs }:
let
  discover = import ./discover.nix;
  kind = import ./content-kind.nix { inherit (discover) discoverEntries; };
  yaml = import ./yaml.nix { inherit pkgs; };
  resolve = import ./resolve.nix;
  checkLib = import ./check.nix;
  utils = import ./utils.nix pkgs.lib;
  image = import ./image.nix;

  builderDeps = {
    inherit pkgs;
    inherit (yaml) writeYaml writeFrontMatter;
    inherit (resolve)
      resolveCover
      makeFilesCmds
      makeFilesCmdsMulti
      assertNoReservedNames
      buildTimeSubstCmd
      ;
    inherit (checkLib) check;
  };

  playground = import ./builders/playground.nix builderDeps;
  tutorial = import ./builders/tutorial.nix builderDeps;
  challenge = import ./builders/challenge.nix builderDeps;
  training = import ./builders/training.nix builderDeps;
  course = import ./builders/course.nix builderDeps;

  content = import ../content { inherit pkgs core; };

  # Self-reference so the content layer can read core primitives.
  core = {
    inherit (discover) discoverEntries discoverAssets;
    inherit (kind) mkContentKind defaultHasMarker;
    inherit (yaml) writeYaml writeFrontMatter;
    inherit (resolve) hashedCover;
    inherit (playground) mkPlayground checkPlaygroundManifest;
    inherit (tutorial) mkTutorial checkTutorialManifest;
    inherit (challenge) mkChallenge checkChallengeManifest;
    inherit (training) mkTraining checkTrainingManifest;
    inherit (course) mkCourse checkCourseManifest;

    lib = {
      inherit (utils)
        buildTime
        readBlock
        toBuildArgs
        ;
      resolve = {
        inherit (resolve) resolveCover makeFilesCmds;
      };
      inherit image;
    };
  };
in
core
// {
  # Content-authoring layer (higher-level API that translates to core).
  inherit content;
}
