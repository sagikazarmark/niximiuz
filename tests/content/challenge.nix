{
  content,
  mockPkgs,
  core,
  ...
}:
let
  recordingCore = core // {
    mkChallenge = args: {
      _mockMkChallengeArgs = args;
      _kind = "recorded-mkChallenge";
    };
  };

  contentR = import ../../lib/content {
    pkgs = mockPkgs;
    core = recordingCore;
  };

  authored = {
    name = "";
    title = "Invisible Pod";
    channels = {
      live = {
        name = "invisible-pod";
        public = true;
      };
      dev = {
        name = "invisible-pod.dev";
      };
    };
  };

  built = contentR.mkChallenge {
    name = "invisible-pod";
    manifest = authored;
    body = "# Problem";
    solution = "# Answer for __CHANNEL__";
  };

  devManifest = built.dev._mockMkChallengeArgs.manifest;
  liveManifest = built.live._mockMkChallengeArgs.manifest;
in
{
  testMkChallengeReturnsAttrsetKeyedByChannel = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames built);
    expected = [
      "dev"
      "live"
    ];
  };

  testMkChallengeEachEntryIsABuilderCall = {
    expr = built.dev._kind;
    expected = "recorded-mkChallenge";
  };

  # solution param flows through without __CHANNEL__ substitution
  # (substitution is manifest-only, matching labx semantics).
  testMkChallengeSolutionPassedThroughUnsubstituted = {
    expr = built.dev._mockMkChallengeArgs.solution;
    expected = "# Answer for __CHANNEL__";
  };

  testMkChallengeBodyPassedThrough = {
    expr = built.dev._mockMkChallengeArgs.body;
    expected = "# Problem";
  };

  testMkChallengeDevNameLifted = {
    expr = devManifest.name;
    expected = "invisible-pod.dev";
  };

  testMkChallengeLiveNameLifted = {
    expr = liveManifest.name;
    expected = "invisible-pod";
  };

  testMkChallengeDevTitlePrefixed = {
    expr = devManifest.title;
    expected = "DEV: Invisible Pod";
  };

  testMkChallengeNoAccessControl = {
    expr = (liveManifest ? accessControl) || (devManifest ? accessControl);
    expected = false;
  };

  testMkChallengeMissingChannelsThrows = {
    expr =
      (builtins.tryEval (
        builtins.deepSeq (contentR.mkChallenge {
          name = "c";
          manifest = {
            title = "x";
          };
        }) null
      )).success;
    expected = false;
  };
}
