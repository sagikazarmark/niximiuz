# End-to-end integration: realize the content builders with real nixpkgs,
# assert that the per-channel transforms actually land in the generated
# YAML / frontmatter.
#
# Only checks content-specific behavior (channel split, name lift, title
# prefix, __CHANNEL__ substitution, accessControl placement). Core's own
# integration check already covers generic builder behavior.
{ pkgs, content }:
let
  playground = content.mkPlayground {
    name = "int-content-pg";
    manifest = {
      name = "";
      title = "Etcd";
      channels = {
        live = {
          name = "etcd-live";
          public = true;
        };
        dev = {
          name = "etcd-dev";
        };
      };
      playground = {
        machines = [
          {
            name = "etcd";
            drives = [ { source = "oci://ghcr.io/example/etcd:__CHANNEL__"; } ];
          }
        ];
      };
    };
  };

  tutorial = content.mkTutorial {
    name = "int-content-tut";
    manifest = {
      name = "";
      title = "Load Balancing";
      channels = {
        live = {
          name = "lb-live";
          public = true;
        };
        dev = {
          name = "lb-dev";
        };
      };
    };
    body = "# Body";
  };

  course = content.mkCourse {
    name = "int-content-course";
    manifest = {
      name = "";
      title = "K8s the Hard Way";
      channels = {
        live = {
          name = "khtw-live";
          public = true;
        };
        dev = {
          name = "khtw-dev";
        };
      };
    };
    children = {
      "01-module" = {
        manifest = {
          kind = "module";
          title = "Module One";
        };
        children = {
          "01-lesson" = {
            manifest = {
              kind = "lesson";
              title = "Lesson One";
            };
            body = "ref: oci://x:__CHANNEL__";
          };
        };
      };
    };
  };
in
pkgs.runCommand "niximiuz-integration-content"
  {
    pgLive = playground.live;
    pgDev = playground.dev;
    tutLive = tutorial.live;
    tutDev = tutorial.dev;
    courseLive = course.live;
    courseDev = course.dev;
    nativeBuildInputs = [ pkgs.gnugrep ];
  }
  ''
    fail() { echo "content-integration: $1" >&2; exit 1; }

    # =====================================================================
    # Playground: channel split + __CHANNEL__ sub + accessControl placement
    # =====================================================================

    # Name is lifted from channels.<ch>.name.
    grep -q '^name: etcd-live$' "$pgLive/content/manifest.yaml" \
      || fail "playground live: name not lifted from channel config"
    grep -q '^name: etcd-dev$' "$pgDev/content/manifest.yaml" \
      || fail "playground dev: name not lifted from channel config"

    # Title unchanged for live, DEV-prefixed for dev.
    grep -q '^title: Etcd$' "$pgLive/content/manifest.yaml" \
      || fail "playground live: title should be unprefixed"
    grep -q '^title: .DEV: Etcd.$' "$pgDev/content/manifest.yaml" \
      || fail "playground dev: title should be prefixed with DEV:"

    # channels key stripped from output.
    grep -q '^channels:' "$pgLive/content/manifest.yaml" \
      && fail "playground live: channels key leaked into output"
    :

    # __CHANNEL__ substitution reached the nested drive source.
    grep -q 'oci://ghcr.io/example/etcd:live' "$pgLive/content/manifest.yaml" \
      || fail "playground live: __CHANNEL__ not substituted in drive source"
    grep -q 'oci://ghcr.io/example/etcd:dev' "$pgDev/content/manifest.yaml" \
      || fail "playground dev: __CHANNEL__ not substituted in drive source"

    # accessControl: public → anyone, non-public → defaults to owner.
    grep -q 'canList:' "$pgLive/content/manifest.yaml" \
      || fail "playground live: public accessControl not injected"
    grep -q 'anyone' "$pgLive/content/manifest.yaml" \
      || fail "playground live: accessControl should be 'anyone'"
    grep -q 'owner' "$pgDev/content/manifest.yaml" \
      || fail "playground dev: accessControl should default to 'owner'"

    # =====================================================================
    # Tutorial: content-kind accessControl at top level
    # =====================================================================

    grep -q '^name: lb-live$' "$tutLive/content/index.md" \
      || fail "tutorial live: name not lifted"
    grep -q '^title: .DEV: Load Balancing.$' "$tutDev/content/index.md" \
      || fail "tutorial dev: title should be prefixed"

    # Tutorials don't have accessControl (playground-only concept).

    # =====================================================================
    # Course: root transforms + recursive children substitution
    # =====================================================================

    grep -q '^name: khtw-live$' "$courseLive/content/index.md" \
      || fail "course live: name not lifted"
    grep -q '^title: K8s the Hard Way$' "$courseLive/content/index.md" \
      || fail "course live: title should be unprefixed"
    grep -q '^title: .DEV: K8s the Hard Way.$' "$courseDev/content/index.md" \
      || fail "course dev: title should be prefixed"

    # Child titles pass through as-authored (no DEV: prefix on modules).
    grep -q '^title: Module One$' \
      "$courseDev/content/01-module/00-index.md" \
      || fail "course dev: child module title should NOT be DEV-prefixed"

    # __CHANNEL__ substitution reached into deeply-nested lesson body.
    grep -q 'ref: oci://x:dev' \
      "$courseDev/content/01-module/01-lesson/00-index.md" \
      || fail "course dev: __CHANNEL__ not substituted in nested lesson body"
    grep -q 'ref: oci://x:live' \
      "$courseLive/content/01-module/01-lesson/00-index.md" \
      || fail "course live: __CHANNEL__ not substituted in nested lesson body"

    echo "content-integration: all assertions passed"
    touch $out
  ''
