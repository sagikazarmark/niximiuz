{
  content,
  mockPkgs,
  core,
  ...
}:
let
  recordingCore = core // {
    mkTutorial = args: {
      _mockMkTutorialArgs = args;
      _kind = "recorded-mkTutorial";
    };
  };

  contentR = import ../../lib/content {
    pkgs = mockPkgs;
    core = recordingCore;
  };

  authored = {
    name = "";
    title = "Load Balancing 101";
    channels = {
      live = {
        name = "lb-101";
        public = true;
      };
      dev = {
        name = "lb-101.dev";
      };
    };
  };

  built = contentR.mkTutorial {
    name = "lb-101";
    manifest = authored;
    body = "# Intro for __CHANNEL__";
  };

  devManifest = built.dev._mockMkTutorialArgs.manifest;
  liveManifest = built.live._mockMkTutorialArgs.manifest;
in
{
  # ---------- return shape ----------

  testMkTutorialReturnsAttrsetKeyedByChannel = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames built);
    expected = [
      "dev"
      "live"
    ];
  };

  testMkTutorialEachEntryIsABuilderCall = {
    expr = built.dev._kind;
    expected = "recorded-mkTutorial";
  };

  # ---------- passthrough to core ----------

  # `name` and `body` pass through unchanged (body is not channel-substituted;
  # __CHANNEL__ substitution is manifest-only, matching labx semantics).
  testMkTutorialNamePassedThrough = {
    expr = built.dev._mockMkTutorialArgs.name;
    expected = "lb-101";
  };

  testMkTutorialBodyPassedThroughUnsubstituted = {
    expr = built.dev._mockMkTutorialArgs.body;
    expected = "# Intro for __CHANNEL__";
  };

  # ---------- channel-level manifest transforms ----------

  testMkTutorialDevNameLifted = {
    expr = devManifest.name;
    expected = "lb-101.dev";
  };

  testMkTutorialLiveNameLifted = {
    expr = liveManifest.name;
    expected = "lb-101";
  };

  testMkTutorialDevTitlePrefixed = {
    expr = devManifest.title;
    expected = "DEV: Load Balancing 101";
  };

  testMkTutorialLiveTitleUnchanged = {
    expr = liveManifest.title;
    expected = "Load Balancing 101";
  };

  testMkTutorialChannelsStripped = {
    expr = devManifest ? channels;
    expected = false;
  };

  # accessControl is playground-only, not injected for content kinds.
  testMkTutorialNoAccessControl = {
    expr = (liveManifest ? accessControl) || (devManifest ? accessControl);
    expected = false;
  };

  # ---------- error cases ----------

  testMkTutorialMissingChannelsThrows = {
    expr =
      (builtins.tryEval (
        builtins.deepSeq (contentR.mkTutorial {
          name = "t";
          manifest = {
            title = "x";
          };
        }) null
      )).success;
    expected = false;
  };
}
