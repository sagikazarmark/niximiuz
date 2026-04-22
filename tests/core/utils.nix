{ core, ... }:
let
  inherit (core.lib) readBlock;
  install = ../fixtures/utils/install.sh;
  unterminated = ../fixtures/utils/unterminated.sh;
in
{
  # Extracts the content between @block:install and @endblock.
  testReadBlockInstall = {
    expr = readBlock install "install";
    expected = ''
      curl -fsSL https://example.com | sh
      apt-get install -y foo
    '';
  };

  # A second block in the same file is addressable by name.
  testReadBlockCleanup = {
    expr = readBlock install "cleanup";
    expected = ''
      rm -rf /tmp/work
    '';
  };

  # Missing block → throws.
  testReadBlockMissingThrows = {
    expr = (builtins.tryEval (readBlock install "nope")).success;
    expected = false;
  };

  # Unterminated block (no @endblock) → throws.
  testReadBlockUnterminatedThrows = {
    expr = (builtins.tryEval (readBlock unterminated "oops")).success;
    expected = false;
  };

  # toBuildArgs: single-word camelCase is just uppercased.
  testToBuildArgsSingleWord = {
    expr = core.lib.toBuildArgs { version = "1.0.0"; };
    expected = {
      VERSION = "1.0.0";
    };
  };

  # toBuildArgs: multi-word camelCase splits at lowercase→uppercase and joins with "_".
  testToBuildArgsMultiWord = {
    expr = core.lib.toBuildArgs { runcVersion = "v1.4.0"; };
    expected = {
      RUNC_VERSION = "v1.4.0";
    };
  };

  # toBuildArgs: handles multiple keys in one call.
  testToBuildArgsMultipleKeys = {
    expr = core.lib.toBuildArgs {
      runcVersion = "v1.4.0";
      cniPluginsVersion = "v1.9.0";
    };
    expected = {
      RUNC_VERSION = "v1.4.0";
      CNI_PLUGINS_VERSION = "v1.9.0";
    };
  };

  # toBuildArgs: triple-word camelCase (xxYyZz → XX_YY_ZZ).
  testToBuildArgsTripleWord = {
    expr = core.lib.toBuildArgs { cniPluginsVersion = "v1.9.0"; };
    expected = {
      CNI_PLUGINS_VERSION = "v1.9.0";
    };
  };

  # toBuildArgs: already-upper keys are left alone (no double-underscoring).
  testToBuildArgsAlreadyUpper = {
    expr = core.lib.toBuildArgs { DEBUG = "true"; };
    expected = {
      DEBUG = "true";
    };
  };

  # toBuildArgs: already-UPPER_SNAKE keys pass through unchanged (no double
  # underscore). Important because consumers might legitimately pass a
  # pre-formed ARG attrset alongside camelCase inputs.
  testToBuildArgsAlreadyUpperSnake = {
    expr = core.lib.toBuildArgs { RUNC_VERSION = "v1"; };
    expected = {
      RUNC_VERSION = "v1";
    };
  };

  # toBuildArgs: empty input returns empty attrset.
  testToBuildArgsEmpty = {
    expr = core.lib.toBuildArgs { };
    expected = { };
  };

  # toBuildArgs: preserves non-string values (though rare in build-args use).
  testToBuildArgsPreservesValues = {
    expr = core.lib.toBuildArgs { fooBar = 42; };
    expected = {
      FOO_BAR = 42;
    };
  };
}
