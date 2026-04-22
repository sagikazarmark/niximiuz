{
  mockPkgs,
  core,
  ...
}:
let
  recordingCore = core // {
    mkCourse = args: {
      _mockMkCourseArgs = args;
      _kind = "recorded-mkCourse";
    };
  };

  contentR = import ../../lib/content {
    pkgs = mockPkgs;
    core = recordingCore;
  };

  authored = {
    name = "";
    title = "Kubernetes the Hard Way";
    channels = {
      live = {
        name = "khtw";
        public = true;
      };
      dev = {
        name = "khtw.dev";
      };
    };
  };

  childrenTree = {
    "01-module" = {
      manifest = {
        kind = "module";
        title = "Module One";
      };
      body = "# Module body for __CHANNEL__";
      children = {
        "01-lesson" = {
          manifest = {
            kind = "lesson";
            title = "Lesson One";
          };
          body = "see oci://x:__CHANNEL__ for details";
          contentFiles = {
            "notes.md" = "notes for __CHANNEL__ channel";
          };
        };
      };
    };
  };

  built = contentR.mkCourse {
    name = "khtw";
    manifest = authored;
    children = childrenTree;
  };

  devArgs = built.dev._mockMkCourseArgs;
  liveArgs = built.live._mockMkCourseArgs;
in
{
  # ---------- return shape ----------

  testMkCourseReturnsAttrsetKeyedByChannel = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames built);
    expected = [
      "dev"
      "live"
    ];
  };

  testMkCourseEachEntryIsABuilderCall = {
    expr = built.dev._kind;
    expected = "recorded-mkCourse";
  };

  # ---------- root manifest: standard channel transforms ----------

  testMkCourseRootDevNameLifted = {
    expr = devArgs.manifest.name;
    expected = "khtw.dev";
  };

  testMkCourseRootLiveNameLifted = {
    expr = liveArgs.manifest.name;
    expected = "khtw";
  };

  testMkCourseRootDevTitlePrefixed = {
    expr = devArgs.manifest.title;
    expected = "DEV: Kubernetes the Hard Way";
  };

  testMkCourseRootLiveTitleUnchanged = {
    expr = liveArgs.manifest.title;
    expected = "Kubernetes the Hard Way";
  };

  testMkCourseRootChannelsStripped = {
    expr = devArgs.manifest ? channels;
    expected = false;
  };

  testMkCourseLivePublicHasTopLevelAccessControl = {
    expr = liveArgs.manifest.accessControl;
    expected = {
      canList = [ "anyone" ];
      canRead = [ "anyone" ];
      canStart = [ "anyone" ];
    };
  };

  testMkCourseDevNoAccessControl = {
    expr = devArgs.manifest ? accessControl;
    expected = false;
  };

  # ---------- children: __CHANNEL__ substitution throughout ----------

  # Module body (one level deep).
  testMkCourseChildModuleBodySubstituted = {
    expr = devArgs.children."01-module".body;
    expected = "# Module body for dev";
  };

  # Lesson body (two levels deep).
  testMkCourseChildLessonBodySubstituted = {
    expr = devArgs.children."01-module".children."01-lesson".body;
    expected = "see oci://x:dev for details";
  };

  # Lesson contentFiles attrset values also walked.
  testMkCourseChildLessonContentFilesSubstituted = {
    expr = devArgs.children."01-module".children."01-lesson".contentFiles."notes.md";
    expected = "notes for dev channel";
  };

  # Children's titles pass through as-authored, labx doesn't prefix
  # module/lesson titles for non-live, only the root course title.
  testMkCourseChildTitleNotPrefixed = {
    expr = devArgs.children."01-module".manifest.title;
    expected = "Module One";
  };

  testMkCourseGrandchildTitleNotPrefixed = {
    expr = devArgs.children."01-module".children."01-lesson".manifest.title;
    expected = "Lesson One";
  };

  # Kind on children is preserved (they author their own; root gets
  # injected by core).
  testMkCourseChildKindPreserved = {
    expr = devArgs.children."01-module".manifest.kind;
    expected = "module";
  };

  # ---------- error cases ----------

  testMkCourseMissingChannelsThrows = {
    expr =
      (builtins.tryEval (
        builtins.deepSeq (contentR.mkCourse {
          name = "c";
          manifest = {
            title = "x";
          };
        }) null
      )).success;
    expected = false;
  };
}
