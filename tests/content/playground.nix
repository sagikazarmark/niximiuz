{
  content,
  mockPkgs,
  core,
  ...
}:
let
  # Wrap core with a recording version of mkPlayground so content tests can
  # inspect exactly what the content hands down (manifest + other args),
  # without having to walk the generated shell script.
  recordingCore = core // {
    mkPlayground = args: {
      _mockMkPlaygroundArgs = args;
      _kind = "recorded-mkPlayground";
    };
  };

  contentR = import ../../lib/content {
    pkgs = mockPkgs;
    core = recordingCore;
  };

  authored = {
    name = "";
    title = "Etcd";
    description = "A key-value store.";
    channels = {
      live = {
        name = "etcd-io-d6418264";
        public = true;
      };
      dev = {
        name = "etcd-io-d6418264.dev";
      };
    };
    playground = {
      machines = [
        {
          name = "etcd";
          drives = [
            { source = "oci://ghcr.io/.../etcd:__CHANNEL__"; }
          ];
        }
      ];
    };
  };

  built = contentR.mkPlayground {
    name = "etcd";
    manifest = authored;
  };

  devManifest = built.dev._mockMkPlaygroundArgs.manifest;
  liveManifest = built.live._mockMkPlaygroundArgs.manifest;

  # Caller-supplied postResolve: stamps a marker on the manifest, and
  # reads a field the library wrote (access-control) to prove it runs
  # AFTER the library's own postResolve.
  hookBuilt = contentR.mkPlayground {
    name = "hook";
    manifest = authored;
    postResolve =
      _channelConfig: resolved:
      resolved
      // {
        playground = resolved.playground // {
          _hookMarker = true;
          _sawAccessControl = resolved.playground ? accessControl;
        };
      };
  };
  hookLive = hookBuilt.live._mockMkPlaygroundArgs.manifest.playground;
in
{
  # ---------- return shape ----------

  testMkPlaygroundReturnsAttrsetKeyedByChannel = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames built);
    expected = [
      "dev"
      "live"
    ];
  };

  testMkPlaygroundEachEntryIsABuilderCall = {
    expr = built.dev._kind;
    expected = "recorded-mkPlayground";
  };

  # ---------- passthrough to core ----------

  # `name` param flows through unchanged to each core call.
  testMkPlaygroundNamePassedThrough = {
    expr = built.dev._mockMkPlaygroundArgs.name;
    expected = "etcd";
  };

  # ---------- channel-level transforms applied to manifest ----------

  testMkPlaygroundDevNameLifted = {
    expr = devManifest.name;
    expected = "etcd-io-d6418264.dev";
  };

  testMkPlaygroundLiveNameLifted = {
    expr = liveManifest.name;
    expected = "etcd-io-d6418264";
  };

  testMkPlaygroundDevTitlePrefixed = {
    expr = devManifest.title;
    expected = "DEV: Etcd";
  };

  testMkPlaygroundLiveTitleUnchanged = {
    expr = liveManifest.title;
    expected = "Etcd";
  };

  testMkPlaygroundChannelsStripped = {
    expr = devManifest ? channels;
    expected = false;
  };

  testMkPlaygroundSubstitutesInMachines = {
    expr = (builtins.head devManifest.playground.machines).drives;
    expected = [ { source = "oci://ghcr.io/.../etcd:dev"; } ];
  };

  # ---------- accessControl ----------

  # live is public → playground.accessControl = anyone.
  testMkPlaygroundLivePublicHasAccessControl = {
    expr = liveManifest.playground.accessControl;
    expected = {
      canList = [ "anyone" ];
      canRead = [ "anyone" ];
      canStart = [ "anyone" ];
    };
  };

  # dev is NOT public, and manifest doesn't set accessControl
  # → defaults to owner.
  testMkPlaygroundDevDefaultsToOwner = {
    expr = devManifest.playground.accessControl;
    expected = {
      canList = [ "owner" ];
      canRead = [ "owner" ];
      canStart = [ "owner" ];
    };
  };

  # ---------- caller postResolve hook ----------

  testMkPlaygroundCallerPostResolveRuns = {
    expr = hookLive._hookMarker or false;
    expected = true;
  };

  # Library's access-control postResolve must run BEFORE the caller's,
  # so the caller sees a manifest that already has accessControl.
  testMkPlaygroundCallerPostResolveComposesAfterLib = {
    expr = hookLive._sawAccessControl;
    expected = true;
  };

  # ---------- error cases ----------

  testMkPlaygroundMissingChannelsThrows = {
    expr =
      (builtins.tryEval (
        builtins.deepSeq (contentR.mkPlayground {
          name = "etcd";
          manifest = {
            title = "x";
            playground = { };
          };
        }) null
      )).success;
    expected = false;
  };
}
