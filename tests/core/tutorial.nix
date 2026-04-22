{ core, ... }:
let
  inherit (core) mkTutorial checkTutorialManifest;

  sampleManifest = {
    name = "load-balancing";
    title = "Load Balancing 101";
  };

  validFullManifest = sampleManifest // {
    kind = "tutorial";
  };

  tutMinimal = mkTutorial {
    name = "load-balancing";
    manifest = sampleManifest;
  };

  tutWithStatic = mkTutorial {
    name = "load-balancing";
    manifest = sampleManifest;
    body = "# Hello";
    static = ../fixtures/discover;
  };

  # Attrset form
  tutContentFilesAttrs = mkTutorial {
    name = "load-balancing";
    manifest = sampleManifest;
    contentFiles = {
      "notes.md" = ../fixtures/discover/regular-file.txt;
    };
  };

  # List form
  tutContentFilesList = mkTutorial {
    name = "load-balancing";
    manifest = sampleManifest;
    contentFiles = [ ../fixtures/discover/regular-file.txt ];
  };

  scriptMatches = pattern: s: builtins.match pattern s != null;
in
{
  testMkTutorialName = {
    expr = tutMinimal.name;
    expected = "load-balancing";
  };

  testMkTutorialUsesRunCommand = {
    expr = tutMinimal._kind;
    expected = "run-command";
  };

  testMkTutorialCopiesIndex = {
    expr = scriptMatches ".*cp .* \\$out/content/index\\.md.*" tutMinimal.script;
    expected = true;
  };

  testMkTutorialNoStaticWhenAbsent = {
    expr = scriptMatches ".*__static__.*" tutMinimal.script;
    expected = false;
  };

  testMkTutorialStaticMakesDir = {
    expr = scriptMatches ".*mkdir -p \\$out/content/__static__.*" tutWithStatic.script;
    expected = true;
  };

  testMkTutorialStaticCopies = {
    expr = scriptMatches ".*cp -r[^ ]* .* \\$out/content/__static__/.*" tutWithStatic.script;
    expected = true;
  };

  testMkTutorialContentFilesAttrs = {
    expr = scriptMatches ".*cp .* \\$out/content/notes\\.md.*" tutContentFilesAttrs.script;
    expected = true;
  };

  testMkTutorialContentFilesListBasename = {
    expr = scriptMatches ".*cp .* \\$out/content/regular-file\\.txt.*" tutContentFilesList.script;
    expected = true;
  };

  # --- checkTutorialManifest ---
  testCheckTutorialManifestPasses = {
    expr = checkTutorialManifest validFullManifest;
    expected = validFullManifest;
  };

  testCheckTutorialManifestThrowsWrongKind = {
    expr =
      (builtins.tryEval (checkTutorialManifest (validFullManifest // { kind = "playground"; }))).success;
    expected = false;
  };

  testCheckTutorialManifestThrowsMissingName = {
    expr =
      (builtins.tryEval (checkTutorialManifest (builtins.removeAttrs validFullManifest [ "name" ])))
      .success;
    expected = false;
  };

  testCheckTutorialManifestThrowsMissingTitle = {
    expr =
      (builtins.tryEval (checkTutorialManifest (builtins.removeAttrs validFullManifest [ "title" ])))
      .success;
    expected = false;
  };

  testCheckTutorialManifestThrowsEmptyName = {
    expr = (builtins.tryEval (checkTutorialManifest (validFullManifest // { name = ""; }))).success;
    expected = false;
  };

  # List-form directory containing index.md at top level is rejected.
  testMkTutorialContentFilesListDirWithIndexRejected = {
    expr =
      (builtins.tryEval
        (mkTutorial {
          name = "t";
          manifest = sampleManifest;
          contentFiles = [ ../fixtures/evil/dir-with-index ];
        }).script
      ).success;
    expected = false;
  };
}
