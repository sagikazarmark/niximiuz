# Structural builder for playground-shaped content.
{
  pkgs,
  writeYaml,
  resolveCover,
  makeFilesCmds,
  makeFilesCmdsMulti,
  assertNoReservedNames,
  buildTimeSubstCmd,
  check,
  ...
}:
{
  # mkPlayground: assemble a playground output directory.
  #
  # Output layout:
  #   $out/content/manifest.yaml: generated from `manifest` (kind injected)
  #   $out/content/__static__/: merged from `static` + cover (if a path)
  #   $out/content/<file>: from `contentFiles`
  #   $out/<file>: from `rootFiles`
  #
  # File-spec params (`static`, `contentFiles`, `rootFiles`) all accept the
  # same shapes:
  #   null: nothing
  #   path / drv: single source; basename used (dir merged)
  #   list [ ... ]: entries copied with their basenames (dirs merged)
  #   attrset: explicit `{ "target-name" = source; ... }`
  #
  # Cover handling: if `manifest.cover` is a Nix path, the file is copied
  # into __static__/ and the manifest's cover is rewritten. Cover sources
  # always merge by basename, even when `static` uses the attrset form,
  # cover is copied alongside (not renamed by the attrset's keys).
  #
  # `kind = "playground"` is injected automatically, authors omit it.
  #
  # Parameters:
  #   name: derivation name stem (required)
  #   manifest: attrset serialized as manifest.yaml; kind injected
  #                   (required). Must contain non-empty `name`.
  #   static: file spec; default: null
  #   contentFiles: file spec; default: null
  #   rootFiles: file spec; default: null
  mkPlayground =
    {
      name,
      manifest,
      static ? null,
      contentFiles ? null,
      rootFiles ? null,
    }:
    let
      checkedContentFiles = assertNoReservedNames "mkPlayground.contentFiles" [
        "manifest.yaml"
        "__static__"
      ] contentFiles;
      checkedRootFiles = assertNoReservedNames "mkPlayground.rootFiles" [ "content" ] rootFiles;

      coverRes = resolveCover manifest;
      fullManifest = coverRes.manifest // {
        kind = "playground";
      };
      manifestFile = writeYaml {
        value = fullManifest;
        name = "manifest.yaml";
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
      cp ${manifestFile} $out/content/manifest.yaml
      ${staticCmd}
      ${contentFileCmds}
      ${rootFileCmds}
      ${buildTimeSubstCmd}
    '';

  # checkPlaygroundManifest: light shape validation.
  checkPlaygroundManifest =
    let
      c = check "checkPlaygroundManifest";
    in
    m:
    assert c.kind m "playground";
    assert c.nonEmptyString m "name";
    assert c.nonEmptyString m "title";
    assert c.optionalString m "description";
    assert c.attrs m "playground";
    m;
}
