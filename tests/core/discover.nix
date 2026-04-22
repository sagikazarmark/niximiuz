{ core, ... }:
let
  inherit (core) discoverEntries discoverAssets;
  fixtures = ../fixtures/discover;
  assetsFixtures = ../fixtures/assets;

  markerOnly = discoverEntries {
    baseDir = fixtures;
    hasMarker = _name: p: builtins.pathExists (p + "/.marker");
    toEntry = name: _: name;
  };

  acceptAll = discoverEntries {
    baseDir = fixtures;
    toEntry = name: _: name;
  };

  pathCheck = discoverEntries {
    baseDir = fixtures;
    hasMarker = _name: p: builtins.pathExists (p + "/.marker");
    toEntry = _name: path: builtins.isPath path;
  };

  nameCheck = discoverEntries {
    baseDir = fixtures;
    hasMarker = _name: p: builtins.pathExists (p + "/.marker");
    toEntry = name: _: "got-${name}";
  };

  noneMatch = discoverEntries {
    baseDir = fixtures;
    hasMarker = _: _: false;
    toEntry = n: _: n;
  };
in
{
  testDiscoverMarkerOnlyNames = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames markerOnly);
    expected = [
      "entry-a"
      "entry-b"
    ];
  };

  testDiscoverMarkerValueA = {
    expr = markerOnly.entry-a;
    expected = "entry-a";
  };

  testDiscoverMarkerValueB = {
    expr = markerOnly.entry-b;
    expected = "entry-b";
  };

  testDiscoverAcceptAllSeesThreeDirs = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames acceptAll);
    expected = [
      "entry-a"
      "entry-b"
      "entry-c"
    ];
  };

  testDiscoverSkipsRegularFiles = {
    expr = acceptAll ? "regular-file.txt";
    expected = false;
  };

  testDiscoverToEntryReceivesPath = {
    expr = pathCheck.entry-a;
    expected = true;
  };

  testDiscoverToEntryReceivesName = {
    expr = nameCheck.entry-a;
    expected = "got-entry-a";
  };

  testDiscoverEmptyWhenNoneMatch = {
    expr = noneMatch;
    expected = { };
  };

  # ---------- discoverAssets ----------

  # Complete: index.md + solution.md + static/ all present.
  testDiscoverAssetsCompleteBody = {
    expr = builtins.isPath (discoverAssets (assetsFixtures + "/complete")).body;
    expected = true;
  };

  testDiscoverAssetsCompleteSolution = {
    expr = builtins.isPath (discoverAssets (assetsFixtures + "/complete")).solution;
    expected = true;
  };

  testDiscoverAssetsCompleteStatic = {
    expr = builtins.isPath (discoverAssets (assetsFixtures + "/complete")).static;
    expected = true;
  };

  # Minimal: only index.md.
  testDiscoverAssetsMinimalBody = {
    expr = builtins.isPath (discoverAssets (assetsFixtures + "/minimal")).body;
    expected = true;
  };

  testDiscoverAssetsMinimalSolutionNull = {
    expr = (discoverAssets (assetsFixtures + "/minimal")).solution;
    expected = null;
  };

  testDiscoverAssetsMinimalStaticNull = {
    expr = (discoverAssets (assetsFixtures + "/minimal")).static;
    expected = null;
  };

  # Empty directory: everything null.
  testDiscoverAssetsEmptyBody = {
    expr = (discoverAssets (assetsFixtures + "/empty")).body;
    expected = null;
  };

  testDiscoverAssetsEmptySolution = {
    expr = (discoverAssets (assetsFixtures + "/empty")).solution;
    expected = null;
  };

  testDiscoverAssetsEmptyStatic = {
    expr = (discoverAssets (assetsFixtures + "/empty")).static;
    expected = null;
  };
}
