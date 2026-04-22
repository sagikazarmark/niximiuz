{ core, ... }:
let
  inherit (core) mkPlayground checkPlaygroundManifest;

  # Authors omit kind, the builder injects it. `name` is a platform
  # manifest field; authors control it (empty string is valid).
  sampleManifest = {
    name = "etcd";
    title = "Etcd";
    playground = {
      machines = [ ];
    };
  };

  # Fully-valid manifest used by checker tests, includes kind which the
  # checker requires.
  validFullManifest = sampleManifest // {
    kind = "playground";
  };

  pgMinimal = mkPlayground {
    name = "etcd";
    manifest = sampleManifest;
  };

  pgWithStatic = mkPlayground {
    name = "etcd";
    manifest = sampleManifest;
    static = ../fixtures/discover;
  };

  # Attrset form, explicit target names.
  pgContentFilesAttrs = mkPlayground {
    name = "etcd";
    manifest = sampleManifest;
    contentFiles = {
      "NOTES.md" = ../fixtures/discover/regular-file.txt;
      "README.md" = ../fixtures/discover/regular-file.txt;
    };
  };

  # List form, basenames preserved.
  pgContentFilesList = mkPlayground {
    name = "etcd";
    manifest = sampleManifest;
    contentFiles = [ ../fixtures/discover/regular-file.txt ];
  };

  pgRootFilesAttrs = mkPlayground {
    name = "etcd";
    manifest = sampleManifest;
    rootFiles = {
      "docker-bake.json" = ../fixtures/discover/regular-file.txt;
    };
  };

  pgRootFilesList = mkPlayground {
    name = "etcd";
    manifest = sampleManifest;
    rootFiles = [ ../fixtures/discover/regular-file.txt ];
  };

  pgWithCoverPath = mkPlayground {
    name = "etcd";
    manifest = sampleManifest // {
      cover = ../fixtures/discover/regular-file.txt;
    };
  };

  pgWithStaticList = mkPlayground {
    name = "etcd";
    manifest = sampleManifest;
    static = [
      ../fixtures/discover
      ../fixtures/discover/regular-file.txt
    ];
  };

  pgWithStaticAttrs = mkPlayground {
    name = "etcd";
    manifest = sampleManifest;
    static = {
      "cover.svg" = ../fixtures/discover/regular-file.txt;
    };
  };

  scriptMatches = pattern: s: builtins.match pattern s != null;
in
{
  testMkPlaygroundName = {
    expr = pgMinimal.name;
    expected = "etcd";
  };

  testMkPlaygroundUsesRunCommand = {
    expr = pgMinimal._kind;
    expected = "run-command";
  };

  testMkPlaygroundCopiesManifest = {
    expr = scriptMatches ".*cp .* \\$out/content/manifest\\.yaml.*" pgMinimal.script;
    expected = true;
  };

  testMkPlaygroundNoStaticWhenAbsent = {
    expr = scriptMatches ".*__static__.*" pgMinimal.script;
    expected = false;
  };

  testMkPlaygroundStaticMakesDir = {
    expr = scriptMatches ".*mkdir -p \\$out/content/__static__.*" pgWithStatic.script;
    expected = true;
  };

  testMkPlaygroundStaticCopies = {
    expr = scriptMatches ".*cp -r[^ ]* .* \\$out/content/__static__/.*" pgWithStatic.script;
    expected = true;
  };

  # --- contentFiles: attrset form ---
  testMkPlaygroundContentFilesAttrsNotes = {
    expr = scriptMatches ".*cp .* \\$out/content/NOTES\\.md.*" pgContentFilesAttrs.script;
    expected = true;
  };

  testMkPlaygroundContentFilesAttrsReadme = {
    expr = scriptMatches ".*cp .* \\$out/content/README\\.md.*" pgContentFilesAttrs.script;
    expected = true;
  };

  # --- contentFiles: list form (basename preserved) ---
  testMkPlaygroundContentFilesListBasename = {
    expr = scriptMatches ".*cp .* \\$out/content/regular-file\\.txt.*" pgContentFilesList.script;
    expected = true;
  };

  # --- rootFiles: attrset form ---
  testMkPlaygroundRootFilesAttrsBake = {
    expr = scriptMatches ".*cp .* \\$out/docker-bake\\.json.*" pgRootFilesAttrs.script;
    expected = true;
  };

  testMkPlaygroundRootFilesAttrsNotInsideContent = {
    expr = scriptMatches ".*\\$out/content/docker-bake\\.json.*" pgRootFilesAttrs.script;
    expected = false;
  };

  # --- rootFiles: list form (basename preserved) ---
  testMkPlaygroundRootFilesListBasename = {
    expr = scriptMatches ".*\ncp[^-r][^\n]*regular-file\\.txt \\$out/regular-file\\.txt.*" (
      "\n" + pgRootFilesList.script
    );
    expected = true;
  };

  testMkPlaygroundCoverPathCopied = {
    expr = scriptMatches ".*regular-file\\.txt.*\\$out/content/__static__/.*" pgWithCoverPath.script;
    expected = true;
  };

  testMkPlaygroundStaticListDirCopied = {
    expr = scriptMatches ".*cp -r[^ ]* .* \\$out/content/__static__/.*" pgWithStaticList.script;
    expected = true;
  };

  testMkPlaygroundStaticListFileCopied = {
    expr =
      scriptMatches ".*\ncp[^-r][^\n]*regular-file\\.txt \\$out/content/__static__/regular-file\\.txt.*"
        ("\n" + pgWithStaticList.script);
    expected = true;
  };

  # static attrset form: explicit names, lands in __static__/.
  testMkPlaygroundStaticAttrsExplicitName = {
    expr = scriptMatches ".*cp .* \\$out/content/__static__/cover\\.svg.*" pgWithStaticAttrs.script;
    expected = true;
  };

  # --- checkPlaygroundManifest ---
  testCheckPlaygroundManifestPasses = {
    expr = checkPlaygroundManifest validFullManifest;
    expected = validFullManifest;
  };

  testCheckPlaygroundManifestThrowsMissingKind = {
    expr =
      (builtins.tryEval (checkPlaygroundManifest (builtins.removeAttrs validFullManifest [ "kind" ])))
      .success;
    expected = false;
  };

  testCheckPlaygroundManifestThrowsWrongKind = {
    expr =
      (builtins.tryEval (checkPlaygroundManifest (validFullManifest // { kind = "tutorial"; }))).success;
    expected = false;
  };

  testCheckPlaygroundManifestThrowsMissingName = {
    expr =
      (builtins.tryEval (checkPlaygroundManifest (builtins.removeAttrs validFullManifest [ "name" ])))
      .success;
    expected = false;
  };

  testCheckPlaygroundManifestThrowsMissingTitle = {
    expr =
      (builtins.tryEval (checkPlaygroundManifest (builtins.removeAttrs validFullManifest [ "title" ])))
      .success;
    expected = false;
  };

  testCheckPlaygroundManifestThrowsMissingPlayground = {
    expr =
      (builtins.tryEval (
        checkPlaygroundManifest (builtins.removeAttrs validFullManifest [ "playground" ])
      )).success;
    expected = false;
  };

  testCheckPlaygroundManifestThrowsEmptyName = {
    expr = (builtins.tryEval (checkPlaygroundManifest (validFullManifest // { name = ""; }))).success;
    expected = false;
  };

  # description is optional, absent is fine.
  testCheckPlaygroundManifestDescriptionAbsentOK = {
    expr = (checkPlaygroundManifest validFullManifest) == validFullManifest;
    expected = true;
  };

  testCheckPlaygroundManifestDescriptionStringOK = {
    expr =
      let
        m = validFullManifest // {
          description = "ok";
        };
      in
      (checkPlaygroundManifest m) == m;
    expected = true;
  };

  testCheckPlaygroundManifestDescriptionNonStringThrows = {
    expr =
      (builtins.tryEval (checkPlaygroundManifest (validFullManifest // { description = 42; }))).success;
    expected = false;
  };

  # --- reserved-name guards ---

  # contentFiles cannot clobber the builder-written manifest.yaml.
  testMkPlaygroundContentFilesRejectsManifestYaml = {
    expr =
      (builtins.tryEval
        (mkPlayground {
          name = "etcd";
          manifest = sampleManifest;
          contentFiles = {
            "manifest.yaml" = ../fixtures/discover/regular-file.txt;
          };
        }).script
      ).success;
    expected = false;
  };

  # contentFiles cannot clobber __static__.
  testMkPlaygroundContentFilesRejectsStatic = {
    expr =
      (builtins.tryEval
        (mkPlayground {
          name = "etcd";
          manifest = sampleManifest;
          contentFiles = {
            "__static__" = ../fixtures/discover/regular-file.txt;
          };
        }).script
      ).success;
    expected = false;
  };

  # rootFiles cannot clobber the content/ subdir.
  testMkPlaygroundRootFilesRejectsContent = {
    expr =
      (builtins.tryEval
        (mkPlayground {
          name = "etcd";
          manifest = sampleManifest;
          rootFiles = {
            "content" = ../fixtures/discover/regular-file.txt;
          };
        }).script
      ).success;
    expected = false;
  };

  # List form with a file whose basename is reserved also throws.
  testMkPlaygroundContentFilesListRejectsReserved = {
    expr =
      let
        manifestYamlFile = builtins.toFile "manifest.yaml" "clobber: true";
      in
      (builtins.tryEval
        (mkPlayground {
          name = "etcd";
          manifest = sampleManifest;
          contentFiles = [ manifestYamlFile ];
        }).script
      ).success;
    expected = false;
  };

  # rootFiles with a slashed key would bypass the layer boundary, rejected.
  testMkPlaygroundRootFilesRejectsSlashKey = {
    expr =
      (builtins.tryEval
        (mkPlayground {
          name = "etcd";
          manifest = sampleManifest;
          rootFiles = {
            "content/manifest.yaml" = ../fixtures/discover/regular-file.txt;
          };
        }).script
      ).success;
    expected = false;
  };

  # Same check applies to contentFiles, slashed keys write into subdirs.
  testMkPlaygroundContentFilesRejectsSlashKey = {
    expr =
      (builtins.tryEval
        (mkPlayground {
          name = "etcd";
          manifest = sampleManifest;
          contentFiles = {
            "sub/file.txt" = ../fixtures/discover/regular-file.txt;
          };
        }).script
      ).success;
    expected = false;
  };

  # List-form directory containing a top-level reserved entry is rejected.
  # (targetNamesInSpec reads the dir at eval time.)
  testMkPlaygroundRootFilesListDirWithContentRejected = {
    expr =
      (builtins.tryEval
        (mkPlayground {
          name = "etcd";
          manifest = sampleManifest;
          rootFiles = [ ../fixtures/evil/dir-with-content ];
        }).script
      ).success;
    expected = false;
  };
}
