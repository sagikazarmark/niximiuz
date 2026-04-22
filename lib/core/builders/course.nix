# Structural builder for course-shaped content.
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
  # Recursive assembler. Cover resolution applies at every level.
  buildNode =
    outPath: isRoot: node:
    let
      indexName = if isRoot then "index.md" else "00-index.md";

      # Reserved: builder-owned files at this node + every child directory
      # name (children land as subdirs and must not be shadowed).
      children = node.children or { };
      childNames = builtins.attrNames children;
      ctx = if isRoot then "mkCourse.contentFiles" else "mkCourse.children.<node>.contentFiles";
      checkedContentFiles = assertNoReservedNames ctx (
        [
          indexName
          "__static__"
        ]
        ++ childNames
      ) (node.contentFiles or null);

      coverRes = resolveCover node.manifest;

      indexFile = writeFrontMatter {
        frontmatter = coverRes.manifest;
        body = node.body or "";
        name = indexName;
      };

      staticLine = makeFilesCmdsMulti [
        (node.static or null)
        coverRes.coverSources
      ] "${outPath}/__static__";

      contentFileLines = makeFilesCmds checkedContentFiles outPath;
      childLines = builtins.concatStringsSep "\n" (
        map (
          childName:
          let
            childPath = "${outPath}/${childName}";
          in
          "mkdir -p ${childPath}\n" + buildNode childPath false children.${childName}
        ) (builtins.attrNames children)
      );
    in
    builtins.concatStringsSep "\n" [
      "mkdir -p ${outPath}"
      "cp ${indexFile} ${outPath}/${indexName}"
      staticLine
      contentFileLines
      childLines
    ];
in
{
  # mkCourse: assemble a course output tree.
  #
  # Output layout (root):
  #   $out/content/index.md: YAML frontmatter (manifest+kind) + body
  #   $out/content/__static__/: root static + cover (optional)
  #   $out/content/<child-name>/: one directory per entry in `children`
  #   $out/content/<file>: from root's `contentFiles`
  #   $out/<file>: from `rootFiles`
  #
  # Children recursively accept { manifest, body?, static?, contentFiles?,
  # children? }; each child subtree emits 00-index.md in its directory.
  # Cover resolution applies at every node.
  #
  # File-spec params (static, contentFiles, rootFiles) accept the same
  # shapes as in mkPlayground.
  #
  # `kind = "course"` is injected at the root; children supply their own
  # (typically "module" or "lesson").
  mkCourse =
    {
      name,
      manifest,
      body ? "",
      static ? null,
      contentFiles ? null,
      rootFiles ? null,
      children ? { },
    }:
    let
      rootManifest = manifest // {
        kind = "course";
      };

      checkedRootFiles = assertNoReservedNames "mkCourse.rootFiles" [ "content" ] rootFiles;
      rootFileCmds = makeFilesCmds checkedRootFiles "$out";

      contentTree = buildNode "$out/content" true {
        manifest = rootManifest;
        inherit
          body
          static
          contentFiles
          children
          ;
      };
    in
    pkgs.runCommand name { } ''
      ${contentTree}
      ${rootFileCmds}
      ${buildTimeSubstCmd}
    '';

  # checkCourseManifest: light shape validation for the root course manifest.
  checkCourseManifest =
    let
      c = check "checkCourseManifest";
    in
    m:
    assert c.kind m "course";
    assert c.nonEmptyString m "name";
    assert c.nonEmptyString m "title";
    assert c.optionalString m "description";
    m;
}
