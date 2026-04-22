# Structural builder for tutorial-shaped content.
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
  # mkTutorial: assemble a tutorial output directory.
  #
  # Output layout:
  #   $out/content/index.md: YAML frontmatter (manifest + kind) + body
  #   $out/content/__static__/: merged from `static` + cover (if a path)
  #   $out/content/<file>: from `contentFiles`
  #   $out/<file>: from `rootFiles`
  #
  # File-spec params (static, contentFiles, rootFiles) accept:
  #   null | path | derivation | list | attrset
  # (See mkPlayground for the full shape spec.)
  #
  # `kind = "tutorial"` is injected automatically.
  #
  # Parameters:
  #   name: derivation name stem (required)
  #   manifest: YAML frontmatter attrset; kind injected (required).
  #                   Must contain non-empty `name`.
  #   body: markdown body (string or path); default: ""
  #   static: file spec; default: null
  #   contentFiles: file spec; default: null
  #   rootFiles: file spec; default: null
  mkTutorial =
    {
      name,
      manifest,
      body ? "",
      static ? null,
      contentFiles ? null,
      rootFiles ? null,
    }:
    let
      checkedContentFiles = assertNoReservedNames "mkTutorial.contentFiles" [
        "index.md"
        "__static__"
      ] contentFiles;
      checkedRootFiles = assertNoReservedNames "mkTutorial.rootFiles" [ "content" ] rootFiles;

      coverRes = resolveCover manifest;
      fullManifest = coverRes.manifest // {
        kind = "tutorial";
      };

      indexFile = writeFrontMatter {
        inherit body;
        frontmatter = fullManifest;
        name = "index.md";
      };

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
      ${staticCmd}
      ${contentFileCmds}
      ${rootFileCmds}
      ${buildTimeSubstCmd}
    '';

  # checkTutorialManifest: light shape validation.
  checkTutorialManifest =
    let
      c = check "checkTutorialManifest";
    in
    m:
    assert c.kind m "tutorial";
    assert c.nonEmptyString m "name";
    assert c.nonEmptyString m "title";
    assert c.optionalString m "description";
    m;
}
