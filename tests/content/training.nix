{
  mockPkgs,
  core,
  ...
}:
let
  recordingCore = core // {
    mkTraining = args: {
      _mockMkTrainingArgs = args;
      _kind = "recorded-mkTraining";
    };
  };

  contentR = import ../../lib/content {
    pkgs = mockPkgs;
    core = recordingCore;
  };

  authored = {
    name = "";
    title = "Dagger Workshop";
    channels = {
      live = {
        name = "dagger-workshop";
        public = true;
      };
      dev = {
        name = "dagger-workshop.dev";
      };
    };
  };

  built = contentR.mkTraining {
    name = "dagger-workshop";
    manifest = authored;
    body = "# Welcome";
    program = "# Program";
    units = {
      "unit-01.md" = "# Unit 1 for __CHANNEL__";
    };
  };

  devManifest = built.dev._mockMkTrainingArgs.manifest;
  liveManifest = built.live._mockMkTrainingArgs.manifest;
in
{
  testMkTrainingReturnsAttrsetKeyedByChannel = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames built);
    expected = [
      "dev"
      "live"
    ];
  };

  testMkTrainingEachEntryIsABuilderCall = {
    expr = built.dev._kind;
    expected = "recorded-mkTraining";
  };

  # program and units pass through without __CHANNEL__ substitution.
  testMkTrainingProgramPassedThrough = {
    expr = built.dev._mockMkTrainingArgs.program;
    expected = "# Program";
  };

  testMkTrainingUnitsPassedThroughUnsubstituted = {
    expr = built.dev._mockMkTrainingArgs.units."unit-01.md";
    expected = "# Unit 1 for __CHANNEL__";
  };

  testMkTrainingBodyPassedThrough = {
    expr = built.dev._mockMkTrainingArgs.body;
    expected = "# Welcome";
  };

  testMkTrainingDevNameLifted = {
    expr = devManifest.name;
    expected = "dagger-workshop.dev";
  };

  testMkTrainingLiveNameLifted = {
    expr = liveManifest.name;
    expected = "dagger-workshop";
  };

  testMkTrainingDevTitlePrefixed = {
    expr = devManifest.title;
    expected = "DEV: Dagger Workshop";
  };

  testMkTrainingNoAccessControl = {
    expr = (liveManifest ? accessControl) || (devManifest ? accessControl);
    expected = false;
  };

  testMkTrainingMissingChannelsThrows = {
    expr =
      (builtins.tryEval (
        builtins.deepSeq (contentR.mkTraining {
          name = "t";
          manifest = {
            title = "x";
          };
        }) null
      )).success;
    expected = false;
  };
}
