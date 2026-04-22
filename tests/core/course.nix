{ core, ... }:
let
  inherit (core) mkCourse checkCourseManifest;

  sampleManifest = {
    name = "khtw";
    title = "Kubernetes the Hard Way";
  };

  validFullManifest = sampleManifest // {
    kind = "course";
  };

  courseMinimal = mkCourse {
    name = "khtw";
    manifest = sampleManifest;
  };

  courseWithChildren = mkCourse {
    name = "khtw";
    manifest = sampleManifest;
    children = {
      "01-intro" = {
        manifest = {
          kind = "module";
          title = "Intro";
        };
      };
      "02-body" = {
        manifest = {
          kind = "module";
          title = "Body";
        };
      };
    };
  };

  courseThreeDeep = mkCourse {
    name = "khtw";
    manifest = sampleManifest;
    children = {
      "03-control-plane" = {
        manifest = {
          kind = "module";
          title = "Control Plane";
        };
        children = {
          "02-kube-apiserver" = {
            manifest = {
              kind = "lesson";
              title = "API Server";
            };
            contentFiles = {
              "01-overview.md" = "# Overview";
              "02-intro.md" = "# Intro";
            };
          };
        };
      };
    };
  };

  courseNestedStatic = mkCourse {
    name = "khtw";
    manifest = sampleManifest;
    static = ../fixtures/discover;
    children = {
      "01-intro" = {
        manifest = {
          kind = "lesson";
          title = "Intro";
        };
        static = ../fixtures/discover;
      };
    };
  };

  courseWithRootFiles = mkCourse {
    name = "khtw";
    manifest = sampleManifest;
    rootFiles = {
      "docker-bake.json" = ../fixtures/discover/regular-file.txt;
    };
  };

  # Child uses list-form contentFiles.
  courseChildListContentFiles = mkCourse {
    name = "khtw";
    manifest = sampleManifest;
    children = {
      "01-intro" = {
        manifest = {
          kind = "lesson";
          title = "Intro";
        };
        contentFiles = [ ../fixtures/discover/regular-file.txt ];
      };
    };
  };

  # Child with a Nix-path cover, the cover should land in the child's
  # own __static__/ (not the root's), and the child's manifest cover
  # rewritten accordingly.
  courseChildCoverPath = mkCourse {
    name = "khtw";
    manifest = sampleManifest;
    children = {
      "01-intro" = {
        manifest = {
          kind = "lesson";
          title = "Intro";
          cover = ../fixtures/discover/regular-file.txt;
        };
      };
    };
  };

  scriptMatches = pattern: s: builtins.match pattern s != null;
in
{
  testMkCourseName = {
    expr = courseMinimal.name;
    expected = "khtw";
  };

  testMkCourseRootUsesIndex = {
    expr = scriptMatches ".*cp .* \\$out/content/index\\.md.*" courseMinimal.script;
    expected = true;
  };

  testMkCourseRootDoesNotUseNumberedIndex = {
    expr = scriptMatches ".*00-index\\.md.*" courseMinimal.script;
    expected = false;
  };

  testMkCourseChildDirIntro = {
    expr = scriptMatches ".*mkdir -p \\$out/content/01-intro.*" courseWithChildren.script;
    expected = true;
  };

  testMkCourseChildDirBody = {
    expr = scriptMatches ".*mkdir -p \\$out/content/02-body.*" courseWithChildren.script;
    expected = true;
  };

  testMkCourseChildIntroUsesNumberedIndex = {
    expr = scriptMatches ".*cp .* \\$out/content/01-intro/00-index\\.md.*" courseWithChildren.script;
    expected = true;
  };

  testMkCourseChildBodyUsesNumberedIndex = {
    expr = scriptMatches ".*cp .* \\$out/content/02-body/00-index\\.md.*" courseWithChildren.script;
    expected = true;
  };

  testMkCourseNestedLessonIndex = {
    expr = scriptMatches ".*cp .* \\$out/content/03-control-plane/02-kube-apiserver/00-index\\.md.*" courseThreeDeep.script;
    expected = true;
  };

  testMkCourseNestedLessonOverviewFile = {
    expr = scriptMatches ".*cp .* \\$out/content/03-control-plane/02-kube-apiserver/01-overview\\.md.*" courseThreeDeep.script;
    expected = true;
  };

  testMkCourseNestedLessonIntroFile = {
    expr = scriptMatches ".*cp .* \\$out/content/03-control-plane/02-kube-apiserver/02-intro\\.md.*" courseThreeDeep.script;
    expected = true;
  };

  testMkCourseRootStatic = {
    expr = scriptMatches ".*mkdir -p \\$out/content/__static__.*" courseNestedStatic.script;
    expected = true;
  };

  testMkCourseChildStatic = {
    expr = scriptMatches ".*mkdir -p \\$out/content/01-intro/__static__.*" courseNestedStatic.script;
    expected = true;
  };

  testMkCourseRootFile = {
    expr = scriptMatches ".*cp .* \\$out/docker-bake\\.json.*" courseWithRootFiles.script;
    expected = true;
  };

  testMkCourseRootFileNotInsideContent = {
    expr = scriptMatches ".*\\$out/content/docker-bake\\.json.*" courseWithRootFiles.script;
    expected = false;
  };

  # Child with list-form contentFiles copies with basename.
  testMkCourseChildContentFilesList = {
    expr = scriptMatches ".*cp .* \\$out/content/01-intro/regular-file\\.txt.*" courseChildListContentFiles.script;
    expected = true;
  };

  # Child cover file lands in the child's __static__/ (not the root's).
  testMkCourseChildCoverInChildStatic = {
    expr = scriptMatches ".*regular-file\\.txt.*\\$out/content/01-intro/__static__/.*" courseChildCoverPath.script;
    expected = true;
  };

  # Child cover does NOT leak into the root __static__/.
  testMkCourseChildCoverNotInRootStatic = {
    expr = scriptMatches ".*\\$out/content/__static__/regular-file\\.txt.*" courseChildCoverPath.script;
    expected = false;
  };

  # --- checkCourseManifest ---
  testCheckCourseManifestPasses = {
    expr = checkCourseManifest validFullManifest;
    expected = validFullManifest;
  };

  testCheckCourseManifestThrowsWrongKind = {
    expr =
      (builtins.tryEval (checkCourseManifest (validFullManifest // { kind = "tutorial"; }))).success;
    expected = false;
  };

  testCheckCourseManifestThrowsMissingName = {
    expr =
      (builtins.tryEval (checkCourseManifest (builtins.removeAttrs validFullManifest [ "name" ])))
      .success;
    expected = false;
  };

  testCheckCourseManifestThrowsMissingTitle = {
    expr =
      (builtins.tryEval (checkCourseManifest (builtins.removeAttrs validFullManifest [ "title" ])))
      .success;
    expected = false;
  };

  testCheckCourseManifestThrowsEmptyName = {
    expr = (builtins.tryEval (checkCourseManifest (validFullManifest // { name = ""; }))).success;
    expected = false;
  };
}
