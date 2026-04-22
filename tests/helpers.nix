# Shared test helpers. mockPkgs includes a real nixpkgs `lib` so helpers
# that need string utilities (toUpper, etc.) work, but overrides the
# derivation-producing attrs with mocks that capture their inputs so tests
# can inspect them without realizing anything.
let
  realPkgs = import <nixpkgs> { };
  mockPkgs = realPkgs // {
    formats = realPkgs.formats // {
      yaml = _opts: {
        generate = name: attrs: {
          inherit name attrs;
          _kind = "yaml-file";
          outPath = "/mock/${name}";
        };
      };
    };
    runCommand = name: _env: script: {
      inherit name script;
      _kind = "run-command";
      outPath = "/mock/${name}";
    };
    writeText = name: _content: {
      inherit name;
      _kind = "text-file";
      outPath = "/mock/${name}";
    };
  };

  lib = import ../lib/core { pkgs = mockPkgs; };
  core = lib; # top-level IS the core surface
  content = lib.content;
in
{
  inherit
    mockPkgs
    core
    content
    lib
    ;
}
