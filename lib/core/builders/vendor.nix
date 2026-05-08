# Structural builder for vendor-shaped content.
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
let
  normalizePage = name: src: if builtins.isString src then builtins.toFile name src else src;
in
{
  # mkVendor: assemble a flat vendor page tree.
  #
  # Output layout:
  #   $out/content/index.md: YAML frontmatter (manifest) + body
  #   $out/content/<page>.md: optional sub-pages, authored with frontmatter
  #   $out/content/__static__/: static assets
  #   $out/<file>: from `rootFiles`
  #
  # Vendor sub-pages carry their own frontmatter and are copied as-is. The
  # vendor index page gets its frontmatter from `manifest`, mirroring the
  # tutorial builder convention.
  mkVendor =
    {
      name,
      manifest,
      body ? "",
      pages ? { },
      static ? null,
      contentFiles ? null,
      rootFiles ? null,
    }:
    let
      normalizedPages = builtins.mapAttrs normalizePage pages;
      pageNames = builtins.attrNames normalizedPages;
      nonMarkdown = builtins.filter (n: builtins.match ".*\\.md" n == null) pageNames;

      checkedPages = assertNoReservedNames "mkVendor.pages" [
        "index.md"
        "__static__"
      ] normalizedPages;
      checkedContentFiles = assertNoReservedNames "mkVendor.contentFiles" (
        [
          "index.md"
          "__static__"
        ]
        ++ pageNames
      ) contentFiles;
      checkedRootFiles = assertNoReservedNames "mkVendor.rootFiles" [ "content" ] rootFiles;

      fullManifest = manifest // {
        kind = "page";
      };
      coverRes = resolveCover fullManifest;
      indexFile = writeFrontMatter {
        inherit body;
        frontmatter = coverRes.manifest;
        name = "index.md";
      };

      pageCmds = makeFilesCmds checkedPages "$out/content";
      staticCmds = makeFilesCmdsMulti [
        static
        coverRes.coverSources
      ] "$out/content/__static__";
      contentFileCmds = makeFilesCmds checkedContentFiles "$out/content";
      rootFileCmds = makeFilesCmds checkedRootFiles "$out";
    in
    if nonMarkdown != [ ] then
      throw "mkVendor.pages: ${builtins.head nonMarkdown} is not a Markdown file"
    else
      pkgs.runCommand name { } ''
        mkdir -p $out/content
        cp ${indexFile} $out/content/index.md
        ${pageCmds}
        ${staticCmds}
        ${contentFileCmds}
        ${rootFileCmds}
        ${buildTimeSubstCmd}
      '';

  checkVendorManifest =
    let
      c = check "checkVendorManifest";
    in
    m:
    assert c.nonEmptyString m "title";
    m;
}
