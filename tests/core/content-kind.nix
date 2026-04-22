{ core, ... }:
let
  inherit (core) mkContentKind defaultHasMarker;
  kindsDir = ../fixtures/kinds;

  kindResult = mkContentKind {
    baseDir = kindsDir;
    mkEntry = name: _path: {
      kind = "synthetic";
      inherit name;
    };
  };

  customArgsKind = mkContentKind {
    baseDir = kindsDir;
    mkEntry = name: _: { inherit name; };
    defaultArgs = name: _path: {
      inherit name;
      injected = "custom-value";
    };
  };

  narrowKind = mkContentKind {
    baseDir = kindsDir;
    hasMarker = _name: p: builtins.pathExists (p + "/default.nix");
    mkEntry = name: _: { inherit name; };
  };
in
{
  testDefaultHasMarkerYaml = {
    expr = defaultHasMarker "x" (kindsDir + "/with-yaml");
    expected = true;
  };

  testDefaultHasMarkerNix = {
    expr = defaultHasMarker "x" (kindsDir + "/with-nix-manifest");
    expected = true;
  };

  testDefaultHasMarkerDefault = {
    expr = defaultHasMarker "x" (kindsDir + "/with-default");
    expected = true;
  };

  testDefaultHasMarkerNone = {
    expr = defaultHasMarker "x" (kindsDir + "/no-markers");
    expected = false;
  };

  testMkContentKindDiscoversMarked = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames kindResult);
    expected = [
      "with-default"
      "with-nix-manifest"
      "with-yaml"
    ];
  };

  testMkContentKindAppliesMkEntry = {
    expr = kindResult.with-yaml;
    expected = {
      kind = "synthetic";
      name = "with-yaml";
    };
  };

  testMkContentKindDefaultNixShortCircuits = {
    expr = kindResult.with-default.sentinel;
    expected = "default-escape-hatch";
  };

  testMkContentKindDefaultNixReceivesName = {
    expr = kindResult.with-default.hasName;
    expected = true;
  };

  testMkContentKindDefaultArgsPassthrough = {
    expr = customArgsKind.with-default.receivedArgs.injected;
    expected = "custom-value";
  };

  testMkContentKindCustomHasMarkerNarrows = {
    expr = builtins.attrNames narrowKind;
    expected = [ "with-default" ];
  };
}
