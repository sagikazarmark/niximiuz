# Flake-output shaping helpers. Turn the nested
# `content.<kind>.<entry>.<channel>` surface of `mkContentPipeline` into
# the flat attrsets `packages.<system>.*` expects.
#
# Naming is a convention, not a mandate: if your repo wants a different
# scheme (dots, slashes, kind-last), compose `flatten` with your own
# projection instead of using `mkPackages`.
{ pkgs }:
let
  inherit (pkgs) lib;

  # flatten: `{ <entry> = { <channel> = v; }; }` →
  # `{ "<prefix>-<entry>-<channel>" = v; }`. Pure; works on any nested
  # attrset, not just derivations.
  flatten =
    prefix: byEntry:
    builtins.listToAttrs (
      builtins.concatLists (
        lib.mapAttrsToList (
          entry: byChannel:
          lib.mapAttrsToList (channel: value: {
            name = "${prefix}-${entry}-${channel}";
            value = value;
          }) byChannel
        ) byEntry
      )
    );

  # wrapPaths: convert `{ name = <store-path>; ... }` into
  # `{ name = <derivation symlinking that path>; ... }`. Bake files come
  # out of nix-docker-bake as raw store paths; `packages.<system>.*`
  # requires derivations, so this wraps them into trivial symlink drvs.
  wrapPaths =
    byName: builtins.mapAttrs (name: path: pkgs.runCommand name { } "ln -s ${path} $out") byName;

  # mkPackages: project an `mkContentPipeline` output into the flat
  # attrset `packages.<system>` wants. Kind names are singularized
  # (playgrounds → playground, courses → course), bake files wrapped
  # into symlink derivations.
  mkPackages =
    content:
    flatten "playground" (content.playgrounds or { })
    // flatten "tutorial" (content.tutorials or { })
    // flatten "challenge" (content.challenges or { })
    // flatten "training" (content.trainings or { })
    // flatten "course" (content.courses or { })
    // wrapPaths (flatten "bake" (content.bakeFiles or { }));
in
{
  inherit flatten wrapPaths mkPackages;
}
