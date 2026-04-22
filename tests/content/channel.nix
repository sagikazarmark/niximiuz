{ content, ... }:
let
  inherit (content)
    substituteChannel
    prefixTitle
    resolveChannelFields
    publicAccessControl
    isChannelPublic
    ;

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
in
{
  # ---------- substituteChannel ----------

  testSubstituteChannelString = {
    expr = substituteChannel "dev" "oci://foo:__CHANNEL__";
    expected = "oci://foo:dev";
  };

  testSubstituteChannelPassthrough = {
    expr = substituteChannel "dev" "no placeholder here";
    expected = "no placeholder here";
  };

  testSubstituteChannelInList = {
    expr = substituteChannel "live" [
      "oci://a:__CHANNEL__"
      "oci://b:__CHANNEL__"
    ];
    expected = [
      "oci://a:live"
      "oci://b:live"
    ];
  };

  testSubstituteChannelInAttrs = {
    expr =
      (substituteChannel "dev" {
        source = "oci://x:__CHANNEL__";
        nested = {
          foo = "oci://y:__CHANNEL__";
        };
      }).nested.foo;
    expected = "oci://y:dev";
  };

  # Non-strings pass through.
  testSubstituteChannelInt = {
    expr = substituteChannel "dev" 42;
    expected = 42;
  };

  testSubstituteChannelBool = {
    expr = substituteChannel "dev" true;
    expected = true;
  };

  # ---------- prefixTitle ----------

  testPrefixTitleLive = {
    expr = prefixTitle "live" "Etcd";
    expected = "Etcd";
  };

  testPrefixTitleDev = {
    expr = prefixTitle "dev" "Etcd";
    expected = "DEV: Etcd";
  };

  testPrefixTitleBeta = {
    expr = prefixTitle "beta" "My Content";
    expected = "BETA: My Content";
  };

  # ---------- resolveChannelFields ----------

  # For `dev`: title prefixed, name lifted, __CHANNEL__ substituted,
  # channels stripped.
  testResolveChannelFieldsDevName = {
    expr = (resolveChannelFields "dev" authored).name;
    expected = "etcd-io-d6418264.dev";
  };

  testResolveChannelFieldsDevTitle = {
    expr = (resolveChannelFields "dev" authored).title;
    expected = "DEV: Etcd";
  };

  testResolveChannelFieldsLiveTitleUnchanged = {
    expr = (resolveChannelFields "live" authored).title;
    expected = "Etcd";
  };

  testResolveChannelFieldsLiveName = {
    expr = (resolveChannelFields "live" authored).name;
    expected = "etcd-io-d6418264";
  };

  testResolveChannelFieldsStripsChannels = {
    expr = (resolveChannelFields "dev" authored) ? channels;
    expected = false;
  };

  # __CHANNEL__ substitution reaches nested strings.
  testResolveChannelFieldsSubstitutesNested = {
    expr =
      let
        resolved = resolveChannelFields "dev" authored;
      in
      (builtins.head resolved.playground.machines).drives;
    expected = [ { source = "oci://ghcr.io/.../etcd:dev"; } ];
  };

  # Other fields (description, playground.*, etc.) pass through unchanged.
  testResolveChannelFieldsPreservesDescription = {
    expr = (resolveChannelFields "dev" authored).description;
    expected = "A key-value store.";
  };

  # Missing channels → throws. Force deep evaluation so the deferred
  # throw fires (tryEval only forces WHNF; the attrset itself is WHNF).
  testResolveChannelFieldsMissingChannelsThrows = {
    expr =
      (builtins.tryEval (builtins.deepSeq (resolveChannelFields "dev" { title = "x"; }) null)).success;
    expected = false;
  };

  testResolveChannelFieldsUnknownChannelThrows = {
    expr = (builtins.tryEval (builtins.deepSeq (resolveChannelFields "prod" authored) null)).success;
    expected = false;
  };

  testResolveChannelFieldsMissingNameThrows = {
    expr =
      (builtins.tryEval (
        builtins.deepSeq (resolveChannelFields "dev" {
          title = "x";
          channels = {
            dev = { };
          };
        }) null
      )).success;
    expected = false;
  };

  testResolveChannelFieldsEmptyNameThrows = {
    expr =
      (builtins.tryEval (
        builtins.deepSeq (resolveChannelFields "dev" {
          title = "x";
          channels = {
            dev = {
              name = "";
            };
          };
        }) null
      )).success;
    expected = false;
  };

  # ---------- public / accessControl ----------

  testIsChannelPublicTrue = {
    expr = isChannelPublic { public = true; };
    expected = true;
  };

  testIsChannelPublicFalse = {
    expr = isChannelPublic { public = false; };
    expected = false;
  };

  # Default (no public attr) is false.
  testIsChannelPublicAbsent = {
    expr = isChannelPublic { name = "foo"; };
    expected = false;
  };

  testPublicAccessControlShape = {
    expr = publicAccessControl;
    expected = {
      canList = [ "anyone" ];
      canRead = [ "anyone" ];
      canStart = [ "anyone" ];
    };
  };
}
