# Structural builder for training-shaped content.
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
  # mkTraining: assemble a training output directory.
  #
  # Output layout:
  #   $out/content/index.md: YAML frontmatter (manifest + kind) + body
  #   $out/content/program.md: pre-rendered markdown, if `program` is set
  #   $out/content/<unit-file>: one per entry in `units`
  #   $out/content/__static__/: merged from `static` + cover (if a path)
  #   $out/content/<file>: from `contentFiles`
  #   $out/<file>: from `rootFiles`
  #
  # File-spec params accept null | path | derivation | list | attrset.
  # (See mkPlayground for full shape spec.)
  #
  # `kind = "training"` is injected automatically.
  #
  # Parameters:
  #   name: derivation name stem (required)
  #   manifest: YAML frontmatter attrset; kind injected (required).
  #                   Must contain non-empty `name`.
  #   body: index.md body (string or path); default: ""
  #   program: program.md content (string or path); default: null
  #   units: attrset { filename = path-or-string; ... }; default: {}
  #   static: file spec; default: null
  #   contentFiles: file spec; default: null
  #   rootFiles: file spec; default: null
  mkTraining =
    {
      name,
      manifest,
      body ? "",
      program ? null,
      units ? { },
      static ? null,
      contentFiles ? null,
      rootFiles ? null,
    }:
    let
      # Reserved: builder-owned outputs plus the user-declared unit filenames
      # (units land in $out/content/ and shouldn't also appear in contentFiles).
      unitNames = builtins.attrNames units;
      checkedContentFiles = assertNoReservedNames "mkTraining.contentFiles" (
        [
          "index.md"
          "program.md"
          "__static__"
        ]
        ++ unitNames
      ) contentFiles;
      checkedRootFiles = assertNoReservedNames "mkTraining.rootFiles" [ "content" ] rootFiles;

      coverRes = resolveCover manifest;
      fullManifest = coverRes.manifest // {
        kind = "training";
      };

      indexFile = writeFrontMatter {
        inherit body;
        frontmatter = fullManifest;
        name = "index.md";
      };

      asFile = fname: v: if builtins.isPath v then v else pkgs.writeText fname v;

      programFile = if program == null then null else asFile "program.md" program;
      programCmd = if programFile != null then "cp ${programFile} $out/content/program.md" else "";

      unitCmds = builtins.concatStringsSep "\n" (
        map (fname: "cp ${toString (asFile fname units.${fname})} $out/content/${fname}") (
          builtins.attrNames units
        )
      );

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
      ${programCmd}
      ${unitCmds}
      ${staticCmd}
      ${contentFileCmds}
      ${rootFileCmds}
      ${buildTimeSubstCmd}
    '';

  # checkTrainingManifest: light shape validation.
  checkTrainingManifest =
    let
      c = check "checkTrainingManifest";
    in
    m:
    assert c.kind m "training";
    assert c.nonEmptyString m "name";
    assert c.nonEmptyString m "title";
    assert c.optionalString m "description";
    m;
}
