# Structural builder for challenge-shaped content.
{
  pkgs,
  writeFrontMatter,
  resolveCover,
  makeFilesCmds,
  makeFilesCmdsMulti,
  assertNoReservedNames,
  buildTimeSubstCmd,
  check,
  ...
}:
{
  # mkChallenge: assemble a challenge output directory.
  #
  # Output layout:
  #   $out/content/index.md: YAML frontmatter (manifest + kind) + body
  #   $out/content/solution.md: plain markdown (no frontmatter), if set
  #   $out/content/__static__/: merged from `static` + cover (if a path)
  #   $out/content/<file>: from `contentFiles`
  #   $out/<file>: from `rootFiles`
  #
  # File-spec params accept null | path | derivation | list | attrset.
  # (See mkPlayground for full shape spec.)
  #
  # `kind = "challenge"` is injected automatically.
  #
  # Parameters:
  #   name: derivation name stem (required)
  #   manifest: YAML frontmatter attrset; kind injected (required).
  #                   Must contain non-empty `name`.
  #   body: index.md body (string or path); default: ""
  #   solution: solution.md body (string or path); default: null
  #   static: file spec; default: null
  #   contentFiles: file spec; default: null
  #   rootFiles: file spec; default: null
  mkChallenge =
    {
      name,
      manifest,
      body ? "",
      solution ? null,
      static ? null,
      contentFiles ? null,
      rootFiles ? null,
    }:
    let
      checkedContentFiles = assertNoReservedNames "mkChallenge.contentFiles" [
        "index.md"
        "solution.md"
        "__static__"
      ] contentFiles;
      checkedRootFiles = assertNoReservedNames "mkChallenge.rootFiles" [ "content" ] rootFiles;

      coverRes = resolveCover manifest;
      fullManifest = coverRes.manifest // {
        kind = "challenge";
      };

      indexFile = writeFrontMatter {
        inherit body;
        frontmatter = fullManifest;
        name = "index.md";
      };

      solutionFile =
        if solution == null then
          null
        else if builtins.isPath solution then
          solution
        else
          pkgs.writeText "solution.md" solution;

      solutionCmd = if solutionFile != null then "cp ${solutionFile} $out/content/solution.md" else "";

      staticCmd = makeFilesCmdsMulti [
        static
        coverRes.coverSources
      ] "$out/content/__static__";

      contentFileCmds = makeFilesCmds checkedContentFiles "$out/content";
      rootFileCmds = makeFilesCmds checkedRootFiles "$out";
    in
    pkgs.runCommand name { } ''
      mkdir -p $out/content
      cp ${indexFile} $out/content/index.md
      ${solutionCmd}
      ${staticCmd}
      ${contentFileCmds}
      ${rootFileCmds}
      ${buildTimeSubstCmd}
    '';

  # checkChallengeManifest: light shape validation.
  checkChallengeManifest =
    let
      c = check "checkChallengeManifest";
    in
    m:
    assert c.kind m "challenge";
    assert c.nonEmptyString m "name";
    assert c.nonEmptyString m "title";
    assert c.optionalString m "description";
    m;
}
