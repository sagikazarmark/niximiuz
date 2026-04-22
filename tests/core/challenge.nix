{ core, ... }:
let
  inherit (core) mkChallenge checkChallengeManifest;

  sampleManifest = {
    name = "invisible-pod";
    title = "Invisible Pod";
  };

  validFullManifest = sampleManifest // {
    kind = "challenge";
  };

  chMinimal = mkChallenge {
    name = "invisible-pod";
    manifest = sampleManifest;
  };

  chWithSolutionString = mkChallenge {
    name = "invisible-pod";
    manifest = sampleManifest;
    solution = "The answer is 42.";
  };

  chWithSolutionPath = mkChallenge {
    name = "invisible-pod";
    manifest = sampleManifest;
    solution = ../fixtures/discover/regular-file.txt;
  };

  chWithStatic = mkChallenge {
    name = "invisible-pod";
    manifest = sampleManifest;
    static = ../fixtures/discover;
  };

  chContentFilesList = mkChallenge {
    name = "invisible-pod";
    manifest = sampleManifest;
    contentFiles = [ ../fixtures/discover/regular-file.txt ];
  };

  chRootFilesAttrs = mkChallenge {
    name = "invisible-pod";
    manifest = sampleManifest;
    rootFiles = {
      "docker-bake.json" = ../fixtures/discover/regular-file.txt;
    };
  };

  scriptMatches = pattern: s: builtins.match pattern s != null;
in
{
  testMkChallengeName = {
    expr = chMinimal.name;
    expected = "invisible-pod";
  };

  testMkChallengeUsesRunCommand = {
    expr = chMinimal._kind;
    expected = "run-command";
  };

  testMkChallengeCopiesIndex = {
    expr = scriptMatches ".*cp .* \\$out/content/index\\.md.*" chMinimal.script;
    expected = true;
  };

  testMkChallengeNoSolutionWhenAbsent = {
    expr = scriptMatches ".*solution\\.md.*" chMinimal.script;
    expected = false;
  };

  testMkChallengeSolutionStringCopied = {
    expr = scriptMatches ".*cp .* \\$out/content/solution\\.md.*" chWithSolutionString.script;
    expected = true;
  };

  testMkChallengeSolutionPathCopied = {
    expr = scriptMatches ".*cp .* \\$out/content/solution\\.md.*" chWithSolutionPath.script;
    expected = true;
  };

  testMkChallengeStaticCopies = {
    expr = scriptMatches ".*cp -r[^ ]* .* \\$out/content/__static__/.*" chWithStatic.script;
    expected = true;
  };

  testMkChallengeContentFilesListBasename = {
    expr = scriptMatches ".*cp .* \\$out/content/regular-file\\.txt.*" chContentFilesList.script;
    expected = true;
  };

  testMkChallengeRootFilesAttrs = {
    expr = scriptMatches ".*cp .* \\$out/docker-bake\\.json.*" chRootFilesAttrs.script;
    expected = true;
  };

  # --- checkChallengeManifest ---
  testCheckChallengeManifestPasses = {
    expr = checkChallengeManifest validFullManifest;
    expected = validFullManifest;
  };

  testCheckChallengeManifestThrowsWrongKind = {
    expr =
      (builtins.tryEval (checkChallengeManifest (validFullManifest // { kind = "tutorial"; }))).success;
    expected = false;
  };

  testCheckChallengeManifestThrowsMissingName = {
    expr =
      (builtins.tryEval (checkChallengeManifest (builtins.removeAttrs validFullManifest [ "name" ])))
      .success;
    expected = false;
  };

  testCheckChallengeManifestThrowsMissingTitle = {
    expr =
      (builtins.tryEval (checkChallengeManifest (builtins.removeAttrs validFullManifest [ "title" ])))
      .success;
    expected = false;
  };

  testCheckChallengeManifestThrowsEmptyName = {
    expr = (builtins.tryEval (checkChallengeManifest (validFullManifest // { name = ""; }))).success;
    expected = false;
  };
}
