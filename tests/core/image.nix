{ core, ... }:
let
  inherit (core.lib.image)
    hashTarget
    shortHash
    tagTarget
    mkRef
    mkPinDigest
    ;

  # ---------- content-addressed tagging fixtures ----------

  # Use `builtins.path` so the stringified result embeds a content hash,
  # matching how `lib.mkContext` produces context paths in real modules.
  ctxA = builtins.path {
    path = ../fixtures/image/ctx-a;
    name = "ctx-a-context";
  };
  ctxB = builtins.path {
    path = ../fixtures/image/ctx-b;
    name = "ctx-b-context";
  };

  minimalTarget = {
    context = ctxA;
    dockerfile = "Dockerfile";
  };

  otherContextTarget = {
    context = ctxB;
    dockerfile = "Dockerfile";
  };

  targetWithArgs = minimalTarget // {
    args = {
      FOO = "1";
    };
  };

  targetWithDifferentArgs = minimalTarget // {
    args = {
      FOO = "2";
    };
  };

  child = minimalTarget;
  parent = minimalTarget // {
    contexts = {
      root = child;
    };
  };
  parentWithDifferentChild = minimalTarget // {
    contexts = {
      root = otherContextTarget;
    };
  };

  withImageString = minimalTarget // {
    contexts = {
      root = "docker-image://example:latest";
    };
  };

  # ---------- digest fixtures ----------

  digests = {
    "ghcr.io/example/kubeadm:dev" = "sha256:abc123";
    "ghcr.io/example/kubeadm:live" = "sha256:def456";
  };
  pinLenient = mkPinDigest { inherit digests; };
  pinStrict = mkPinDigest {
    inherit digests;
    strict = true;
  };
  pinEmpty = mkPinDigest { };
in
{
  # ---------- hashTarget / shortHash ----------

  testHashIsStable = {
    expr = hashTarget minimalTarget == hashTarget minimalTarget;
    expected = true;
  };

  testHashDiffersOnContextContent = {
    expr = hashTarget minimalTarget == hashTarget otherContextTarget;
    expected = false;
  };

  testHashDiffersOnArgs = {
    expr = hashTarget targetWithArgs == hashTarget targetWithDifferentArgs;
    expected = false;
  };

  testHashDiffersOnDockerfile = {
    expr = hashTarget minimalTarget == hashTarget (minimalTarget // { dockerfile = "Dockerfile.alt"; });
    expected = false;
  };

  testHashDiffersOnTargetStage = {
    expr = hashTarget minimalTarget == hashTarget (minimalTarget // { target = "defaults"; });
    expected = false;
  };

  testHashDiffersOnPlatforms = {
    expr =
      hashTarget (minimalTarget // { platforms = [ "linux/amd64" ]; })
      == hashTarget (minimalTarget // { platforms = [ "linux/arm64" ]; });
    expected = false;
  };

  testHashRecursesIntoContexts = {
    expr = hashTarget parent == hashTarget parentWithDifferentChild;
    expected = false;
  };

  testHashTreatsStringContextsAsData = {
    expr = builtins.isString (hashTarget withImageString);
    expected = true;
  };

  testHashIgnoresTagsField = {
    expr = hashTarget minimalTarget == hashTarget (minimalTarget // { tags = [ "ghcr.io/some:tag" ]; });
    expected = true;
  };

  # ---------- tagTarget ----------

  testTagTargetAppendsHashTag = {
    expr =
      let
        withExistingTag = minimalTarget // {
          tags = [ "ghcr.io/example/foo:dev" ];
        };
        tagged = tagTarget {
          repository = "ghcr.io/example";
          path = "playgrounds/foo";
          target = withExistingTag;
        };
        last = builtins.elemAt tagged.tags (builtins.length tagged.tags - 1);
      in
      builtins.length tagged.tags == 2
      && builtins.elemAt tagged.tags 0 == "ghcr.io/example/foo:dev"
      && builtins.match "ghcr.io/example/playgrounds/foo:[a-f0-9]{12}" last != null;
    expected = true;
  };

  testTagTargetOnUntaggedTarget = {
    expr =
      let
        tagged = tagTarget {
          repository = "ghcr.io/example";
          path = "playgrounds/foo";
          target = minimalTarget;
        };
      in
      builtins.length tagged.tags == 1
      &&
        builtins.match "ghcr.io/example/playgrounds/foo:[a-f0-9]{12}" (builtins.head tagged.tags) != null;
    expected = true;
  };

  testTagTargetStampsPassthruImageRef = {
    expr =
      let
        tagged = tagTarget {
          repository = "ghcr.io/example";
          path = "playgrounds/foo";
          target = minimalTarget;
        };
      in
      tagged.passthru.imageRef == "oci://ghcr.io/example/playgrounds/foo:${shortHash minimalTarget}";
    expected = true;
  };

  testTagTargetPassthruMatchesLastTag = {
    expr =
      let
        tagged = tagTarget {
          repository = "ghcr.io/example";
          path = "playgrounds/foo";
          target = minimalTarget;
        };
        lastTag = builtins.elemAt tagged.tags (builtins.length tagged.tags - 1);
        # imageRef is "oci://<tag>"  strip the prefix to compare.
        refAsTag = builtins.substring 6 (
          builtins.stringLength tagged.passthru.imageRef - 6
        ) tagged.passthru.imageRef;
      in
      refAsTag == lastTag;
    expected = true;
  };

  testTagTargetPreservesExistingPassthru = {
    expr =
      let
        targetWithPassthru = minimalTarget // {
          passthru = {
            foo = "bar";
          };
        };
        tagged = tagTarget {
          repository = "ghcr.io/example";
          path = "playgrounds/foo";
          target = targetWithPassthru;
        };
      in
      tagged.passthru.foo == "bar" && tagged.passthru ? imageRef;
    expected = true;
  };

  # ---------- mkRef ----------

  testMkRefReturnsOciUri = {
    expr = mkRef {
      repository = "ghcr.io/example";
      path = "playgrounds/foo";
      target = minimalTarget;
    };
    expected = "oci://ghcr.io/example/playgrounds/foo:${
      builtins.substring 0 12 (hashTarget minimalTarget)
    }";
  };

  testMkRefSameHashAsTagTarget = {
    expr =
      let
        ref = mkRef {
          repository = "ghcr.io/example";
          path = "playgrounds/foo";
          target = minimalTarget;
        };
        tagged = tagTarget {
          repository = "ghcr.io/example";
          path = "playgrounds/foo";
          target = minimalTarget;
        };
      in
      ref == tagged.passthru.imageRef;
    expected = true;
  };

  # ---------- mkPinDigest ----------

  testPinDigestAppendsDev = {
    expr = pinLenient "oci://ghcr.io/example/kubeadm:dev";
    expected = "oci://ghcr.io/example/kubeadm:dev@sha256:abc123";
  };

  testPinDigestAppendsLive = {
    expr = pinLenient "oci://ghcr.io/example/kubeadm:live";
    expected = "oci://ghcr.io/example/kubeadm:live@sha256:def456";
  };

  testPinDigestSkipsAlreadyPinned = {
    expr = pinLenient "oci://ghcr.io/example/kubeadm:dev@sha256:existing";
    expected = "oci://ghcr.io/example/kubeadm:dev@sha256:existing";
  };

  testPinDigestLenientMissingReturnsRef = {
    expr = pinLenient "oci://ghcr.io/example/unknown:dev";
    expected = "oci://ghcr.io/example/unknown:dev";
  };

  testPinDigestStrictMissingThrows = {
    expr = (builtins.tryEval (pinStrict "oci://ghcr.io/example/unknown:dev")).success;
    expected = false;
  };

  testPinDigestEmptyMapPassthrough = {
    expr = pinEmpty "oci://ghcr.io/example/kubeadm:dev";
    expected = "oci://ghcr.io/example/kubeadm:dev";
  };

  testPinDigestWorksWithInterpolation = {
    expr =
      let
        channel = "dev";
      in
      pinLenient "oci://ghcr.io/example/kubeadm:${channel}";
    expected = "oci://ghcr.io/example/kubeadm:dev@sha256:abc123";
  };
}
