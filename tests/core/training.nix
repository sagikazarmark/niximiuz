{ core, ... }:
let
  inherit (core) mkTraining checkTrainingManifest;

  sampleManifest = {
    name = "dagger-workshop";
    title = "Dagger Workshop";
  };

  validFullManifest = sampleManifest // {
    kind = "training";
  };

  trMinimal = mkTraining {
    name = "dagger-workshop";
    manifest = sampleManifest;
  };

  trWithProgramString = mkTraining {
    name = "dagger-workshop";
    manifest = sampleManifest;
    program = "# Program overview";
  };

  trWithProgramPath = mkTraining {
    name = "dagger-workshop";
    manifest = sampleManifest;
    program = ../fixtures/discover/regular-file.txt;
  };

  trWithUnits = mkTraining {
    name = "dagger-workshop";
    manifest = sampleManifest;
    units = {
      "unit-01-intro.md" = "# Intro";
      "unit-02-body.md" = ../fixtures/discover/regular-file.txt;
    };
  };

  trWithStatic = mkTraining {
    name = "dagger-workshop";
    manifest = sampleManifest;
    static = ../fixtures/discover;
  };

  trContentFilesList = mkTraining {
    name = "dagger-workshop";
    manifest = sampleManifest;
    contentFiles = [ ../fixtures/discover/regular-file.txt ];
  };

  scriptMatches = pattern: s: builtins.match pattern s != null;
in
{
  testMkTrainingName = {
    expr = trMinimal.name;
    expected = "dagger-workshop";
  };

  testMkTrainingCopiesIndex = {
    expr = scriptMatches ".*cp .* \\$out/content/index\\.md.*" trMinimal.script;
    expected = true;
  };

  testMkTrainingNoProgramWhenAbsent = {
    expr = scriptMatches ".*program\\.md.*" trMinimal.script;
    expected = false;
  };

  testMkTrainingNoUnitsWhenAbsent = {
    expr = scriptMatches ".*unit.*" trMinimal.script;
    expected = false;
  };

  testMkTrainingProgramStringCopied = {
    expr = scriptMatches ".*cp .* \\$out/content/program\\.md.*" trWithProgramString.script;
    expected = true;
  };

  testMkTrainingProgramPathCopied = {
    expr = scriptMatches ".*cp .* \\$out/content/program\\.md.*" trWithProgramPath.script;
    expected = true;
  };

  testMkTrainingUnitIntroCopied = {
    expr = scriptMatches ".*cp .* \\$out/content/unit-01-intro\\.md.*" trWithUnits.script;
    expected = true;
  };

  testMkTrainingUnitBodyCopied = {
    expr = scriptMatches ".*cp .* \\$out/content/unit-02-body\\.md.*" trWithUnits.script;
    expected = true;
  };

  testMkTrainingStaticCopies = {
    expr = scriptMatches ".*cp -r[^ ]* .* \\$out/content/__static__/.*" trWithStatic.script;
    expected = true;
  };

  testMkTrainingContentFilesListBasename = {
    expr = scriptMatches ".*cp .* \\$out/content/regular-file\\.txt.*" trContentFilesList.script;
    expected = true;
  };

  # --- checkTrainingManifest ---
  testCheckTrainingManifestPasses = {
    expr = checkTrainingManifest validFullManifest;
    expected = validFullManifest;
  };

  testCheckTrainingManifestThrowsWrongKind = {
    expr =
      (builtins.tryEval (checkTrainingManifest (validFullManifest // { kind = "tutorial"; }))).success;
    expected = false;
  };

  testCheckTrainingManifestThrowsMissingName = {
    expr =
      (builtins.tryEval (checkTrainingManifest (builtins.removeAttrs validFullManifest [ "name" ])))
      .success;
    expected = false;
  };

  testCheckTrainingManifestThrowsMissingTitle = {
    expr =
      (builtins.tryEval (checkTrainingManifest (builtins.removeAttrs validFullManifest [ "title" ])))
      .success;
    expected = false;
  };

  testCheckTrainingManifestThrowsEmptyName = {
    expr = (builtins.tryEval (checkTrainingManifest (validFullManifest // { name = ""; }))).success;
    expected = false;
  };
}
