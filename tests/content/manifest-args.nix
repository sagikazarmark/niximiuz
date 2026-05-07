{
  mockPkgs,
  core,
  ...
}:
let
  loaders = import ../../lib/loaders;

  manifestArgs = loaders.content.mkManifestArgs {
    pkgs = mockPkgs;
    libFor = _name: _path: _channel: {
      inherit (core) hashedCover;
      custom = "helper";
    };
    extras = name: _path: channel: {
      passthru = "${name}-${channel}";
    };
  };

  args = manifestArgs "demo" ./. "dev";
in
{
  testMkManifestArgsInjectsLib = {
    expr = builtins.attrNames args.lib;
    expected = [
      "custom"
      "hashedCover"
    ];
  };

  testMkManifestArgsLibCarriesHelpers = {
    expr = builtins.isFunction args.lib.hashedCover && args.lib.custom == "helper";
    expected = true;
  };

  testMkManifestArgsStillMergesExtras = {
    expr = args.passthru;
    expected = "demo-dev";
  };
}
