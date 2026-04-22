# Content-authoring layer on top of core. Takes { pkgs, core } and
# exposes channel helpers, labx integration, and builders that handle
# the full authoring→core translation (static mode or labx-orchestrating
# mode).
{ pkgs, core }:
let
  channel = import ./channel.nix { inherit (pkgs) lib; };
  labx = import ./labx.nix { inherit pkgs core; };

  # Assemble the content self-attrset so builders can reference channel
  # helpers + labx via `content.*` (same surface downstream consumers see).
  content = {
    inherit (channel)
      substituteChannel
      prefixTitle
      resolveChannelFields
      publicAccessControl
      defaultAccessControl
      isChannelPublic
      mkChanneledContent
      ;
    inherit (labx) renderWithLabx;
  };

  builderDeps = {
    inherit core content pkgs;
  };

  playground = import ./builders/playground.nix builderDeps;
  tutorial = import ./builders/tutorial.nix builderDeps;
  challenge = import ./builders/challenge.nix builderDeps;
  training = import ./builders/training.nix builderDeps;
  course = import ./builders/course.nix builderDeps;
in
content
// {
  # Content builders, one entry point per kind. Static mode when the
  # caller supplies `manifest` (or loadManifest); orchestrating mode
  # (labx + body derivation) when the caller supplies `source`.
  inherit (playground) mkPlayground;
  inherit (tutorial) mkTutorial;
  inherit (challenge) mkChallenge;
  inherit (training) mkTraining;
  inherit (course) mkCourse;
}
