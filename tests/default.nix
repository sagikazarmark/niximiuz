# Unified test suite. Merges core + content subjects into one runTests pass.
#
# Run: nix eval --impure --expr 'import ./tests/default.nix { pkgs = import <nixpkgs> { }; }'
{ pkgs }:
let
  lib = pkgs.lib;
  helpers = import ./helpers.nix { inherit pkgs; };
  inherit (helpers) core content mockPkgs;

  subjects = [
    # Core tests
    (import ./core/discover.nix { inherit core; })
    (import ./core/content-kind.nix { inherit core; })
    (import ./core/yaml.nix { inherit core; })
    (import ./core/resolve.nix { inherit core; })
    (import ./core/playground.nix { inherit core; })
    (import ./core/tutorial.nix { inherit core; })
    (import ./core/challenge.nix { inherit core; })
    (import ./core/training.nix { inherit core; })
    (import ./core/course.nix { inherit core; })
    (import ./core/utils.nix { inherit core; })
    (import ./core/image.nix { inherit core; })

    # Content-layer tests
    (import ./content/channel.nix { inherit content; })
    (import ./content/playground.nix { inherit content mockPkgs core; })
    (import ./content/tutorial.nix { inherit content mockPkgs core; })
    (import ./content/challenge.nix { inherit content mockPkgs core; })
    (import ./content/training.nix { inherit content mockPkgs core; })
    (import ./content/course.nix { inherit content mockPkgs core; })
    (import ./content/collectors.nix { inherit content mockPkgs core; })
  ];

  allTests = builtins.foldl' (acc: s: acc // s) { } subjects;

  failures = lib.runTests allTests;
in
if failures == [ ] then
  "all tests passed (${toString (builtins.length (builtins.attrNames allTests))} assertions)"
else
  throw "test failures:\n${builtins.toJSON failures}"
