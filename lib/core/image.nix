# OCI image ref tooling. Two complementary strategies for cache-correct
# image references:
#
#   1. Content-addressed tags: derive a short SHA-256 from a bake target's
#      build-relevant fields. `tagTarget` stamps both the hashed tag and a
#      `passthru.imageRef` on the target so manifests can consume the ref
#      directly off the target attrset.
#
#   2. Digest pinning: append an externally-collected `@sha256:...` digest
#      to a moving-tag `oci://` ref. Reads a digests.json file mapping
#      `repo:tag` to digest string (populated by `docker buildx bake --push
#      --metadata-file`). Backwards-compatible path for consumers that stay
#      on moving tags.
#
# Both strategies live here because they solve the same problem: producing
# image refs that actually change when image content changes.
#
# `tagTarget` writes to `target.passthru.imageRef`. `passthru` is a documented
# extension point on nix-docker-bake targets (v0.2.0+); the library serializer
# strips it from the final bake JSON. See the upstream README for details.
#
# See docs/specs/2026-04-17-content-addressed-image-tags-design.md.
let
  # ---------- content-addressed tagging ----------

  hashContextValue =
    value:
    if builtins.isAttrs value then
      hashTarget value
    else if builtins.isPath value then
      toString value
    else if builtins.isString value then
      value
    else
      throw "hashContextValue: unsupported type (got ${builtins.typeOf value})";

  # Compute a stable content hash for a target attrset. Lowercase hex
  # SHA-256. Excludes `tags` and `passthru` (both would create self-reference
  # cycles with content-addressed tagging).
  hashTarget =
    target:
    let
      normalized = {
        context = if builtins.isPath target.context then toString target.context else target.context;
        dockerfile = target.dockerfile or "Dockerfile";
        target = target.target or null;
        args = target.args or { };
        contexts = builtins.mapAttrs (_: hashContextValue) (target.contexts or { });
        platforms = target.platforms or [ ];
      };
    in
    builtins.hashString "sha256" (builtins.toJSON normalized);

  shortHash = target: builtins.substring 0 12 (hashTarget target);

  # Attach a content-addressed tag and a matching `passthru.imageRef` to a
  # target. Purely content-addressed: this helper does NOT emit a moving tag
  # or any channel-specific string. Projects that want to combine this with
  # a moving-tag strategy wrap this helper in their scope config.
  #
  # Usage:
  #   tagTarget { repository = "ghcr.io/..."; path = "playgrounds/foo"; target = base; }
  #
  # Produces a target with:
  #   - `tags` extended with `${repository}/${path}:${hash}`
  #   - `passthru.imageRef` set to `oci://${repository}/${path}:${hash}`
  tagTarget =
    {
      repository,
      path,
      target,
    }:
    let
      h = shortHash target;
      ref = "oci://${repository}/${path}:${h}";
    in
    target
    // {
      tags = (target.tags or [ ]) ++ [ "${repository}/${path}:${h}" ];
      passthru = (target.passthru or { }) // {
        imageRef = ref;
      };
    };

  # Produce a content-addressed `oci://` ref for a target without mutating
  # the target. Useful when composing refs outside a `tagTarget` call.
  mkRef =
    {
      repository,
      path,
      target,
    }:
    "oci://${repository}/${path}:${shortHash target}";

  # ---------- digest pinning (legacy moving-tag workflow) ----------

  # Create a `pinDigest` function closed over a digest map.
  #
  # Parameters:
  #   digests  attrset mapping "REPO:TAG" to "sha256:..." strings.
  #            Loaded from digests.json (or empty {}).
  #   strict   if true, throw when a ref has no digest in the map.
  #            if false, return the ref unchanged.
  #            Default: false.
  #
  # Returns: a function `ref -> ref-with-digest`.
  mkPinDigest =
    {
      digests ? { },
      strict ? false,
    }:
    ref:
    let
      dockerRef = builtins.replaceStrings [ "oci://" ] [ "" ] ref;
      alreadyPinned = builtins.match ".*@sha256:.*" ref != null;
      digest = digests.${dockerRef} or null;
    in
    if alreadyPinned then
      ref
    else if digest != null then
      "${ref}@${digest}"
    else if strict then
      throw "pinDigest: no digest found for '${dockerRef}' (strict mode). Run the digest resolution script or set strict = false."
    else
      ref;

  # Read a digests.json file if it exists, else return {}.
  # Use with `--impure` if the file is gitignored.
  loadDigests =
    path: if builtins.pathExists path then builtins.fromJSON (builtins.readFile path) else { };
in
{
  inherit
    hashTarget
    shortHash
    tagTarget
    mkRef
    mkPinDigest
    loadDigests
    ;
}
