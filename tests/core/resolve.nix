{ core, ... }:
let
  resolve = import ../../lib/core/resolve.nix;
  inherit (resolve)
    resolveCover
    hashedCover
    makeFilesCmds
    makeFilesCmdsMulti
    ;

  scriptMatches = pattern: s: builtins.match pattern s != null;
in
{
  # ---------- resolveCover ----------

  testResolveCoverPathRewrites = {
    expr = (resolveCover { cover = ../fixtures/discover/regular-file.txt; }).manifest.cover;
    expected = "__static__/regular-file.txt";
  };

  testResolveCoverPathCollectsSource = {
    expr =
      builtins.length
        (resolveCover { cover = ../fixtures/discover/regular-file.txt; }).coverSources;
    expected = 1;
  };

  testResolveCoverStringPassthrough = {
    expr = (resolveCover { cover = "/__static__/custom.svg"; }).manifest.cover;
    expected = "/__static__/custom.svg";
  };

  testResolveCoverStringNoSource = {
    expr = (resolveCover { cover = "/__static__/custom.svg"; }).coverSources;
    expected = [ ];
  };

  testResolveCoverAbsentManifest = {
    expr = (resolveCover { title = "x"; }).manifest;
    expected = {
      title = "x";
    };
  };

  testResolveCoverAbsentSources = {
    expr = (resolveCover { title = "x"; }).coverSources;
    expected = [ ];
  };

  testResolveCoverPreservesOtherFields = {
    expr =
      (resolveCover {
        title = "x";
        cover = ../fixtures/discover/regular-file.txt;
      }).manifest.title;
    expected = "x";
  };

  # ---------- hashedCover ----------

  # Marker → cover rewritten to "<base>.<hash8>.<ext>" form.
  testHashedCoverRewritesManifest = {
    expr =
      let
        res = resolveCover { cover = hashedCover ../fixtures/discover/regular-file.txt; };
      in
      builtins.match "__static__/regular-file\\.[0-9a-f]{8}\\.txt" res.manifest.cover != null;
    expected = true;
  };

  # Marker → coverSources is an attrset keyed by the hashed target name.
  testHashedCoverSourcesIsAttrs = {
    expr =
      let
        res = resolveCover { cover = hashedCover ../fixtures/discover/regular-file.txt; };
      in
      builtins.isAttrs res.coverSources && !(builtins.isList res.coverSources);
    expected = true;
  };

  testHashedCoverSourcesKeyIsHashed = {
    expr =
      let
        res = resolveCover { cover = hashedCover ../fixtures/discover/regular-file.txt; };
        keys = builtins.attrNames res.coverSources;
      in
      builtins.length keys == 1
      && builtins.match "regular-file\\.[0-9a-f]{8}\\.txt" (builtins.head keys) != null;
    expected = true;
  };

  # Plain Nix path → preserves original name (unchanged behavior).
  testResolveCoverPlainPathUnhashed = {
    expr = (resolveCover { cover = ../fixtures/discover/regular-file.txt; }).manifest.cover;
    expected = "__static__/regular-file.txt";
  };

  # ---------- makeFilesCmds: empty inputs ----------

  testMakeFilesCmdsNull = {
    expr = makeFilesCmds null "/target";
    expected = "";
  };

  testMakeFilesCmdsEmptyList = {
    expr = makeFilesCmds [ ] "/target";
    expected = "";
  };

  testMakeFilesCmdsEmptyAttrs = {
    expr = makeFilesCmds { } "/target";
    expected = "";
  };

  # ---------- makeFilesCmds: single path/dir ----------

  # Single path: wrapped to list, basename used, mkdir emitted.
  testMakeFilesCmdsSinglePath = {
    expr =
      let
        cmds = makeFilesCmds ../fixtures/discover/regular-file.txt "/target";
      in
      scriptMatches ".*mkdir -p /target.*\ncp -f .*regular-file\\.txt /target/regular-file\\.txt.*" cmds;
    expected = true;
  };

  # Single dir: cp -r merge.
  testMakeFilesCmdsSingleDir = {
    expr =
      let
        cmds = makeFilesCmds ../fixtures/discover "/target";
      in
      scriptMatches ".*cp -rf .*/. /target/.*" cmds;
    expected = true;
  };

  # ---------- makeFilesCmds: list form ----------

  testMakeFilesCmdsListBasename = {
    expr =
      let
        cmds = makeFilesCmds [ ../fixtures/discover/regular-file.txt ] "/target";
      in
      scriptMatches ".*cp -f .*regular-file\\.txt /target/regular-file\\.txt.*" cmds;
    expected = true;
  };

  # List with mixed dir + file → cp -rf for dir, cp -f for file.
  testMakeFilesCmdsListMixed = {
    expr =
      let
        cmds = makeFilesCmds [
          ../fixtures/discover
          ../fixtures/discover/regular-file.txt
        ] "/target";
      in
      (scriptMatches ".*cp -rf .*" cmds) && (scriptMatches ".*cp -f .*regular-file.*" cmds);
    expected = true;
  };

  # ---------- makeFilesCmds: attrset form ----------

  testMakeFilesCmdsAttrsExplicit = {
    expr =
      let
        cmds = makeFilesCmds { "renamed.txt" = ../fixtures/discover/regular-file.txt; } "/target";
      in
      scriptMatches ".*cp -f .* /target/renamed\\.txt.*" cmds;
    expected = true;
  };

  # Attrset preserves the explicit name; source basename also appears (in src path).
  testMakeFilesCmdsAttrsRenames = {
    expr =
      let
        cmds = makeFilesCmds { "renamed.txt" = ../fixtures/discover/regular-file.txt; } "/target";
      in
      (scriptMatches ".*regular-file\\.txt.*" cmds) && (scriptMatches ".*/target/renamed\\.txt.*" cmds);
    expected = true;
  };

  # ---------- makeFilesCmdsMulti ----------

  # Combines several specs into one block, all targeting the same dir.
  testMakeFilesCmdsMultiCombines = {
    expr =
      let
        cmds = makeFilesCmdsMulti [
          [ ../fixtures/discover/regular-file.txt ]
          { "renamed.md" = ../fixtures/discover/regular-file.txt; }
        ] "/target";
      in
      (scriptMatches ".*regular-file\\.txt /target/regular-file\\.txt.*" cmds)
      && (scriptMatches ".*/target/renamed\\.md.*" cmds);
    expected = true;
  };

  # Empty/null specs are skipped (no extra noise).
  testMakeFilesCmdsMultiSkipsEmpty = {
    expr = makeFilesCmdsMulti [
      null
      [ ]
      { }
    ] "/target";
    expected = "";
  };
}
