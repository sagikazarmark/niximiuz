# End-to-end integration check: realizes one of each kind with real nixpkgs
# and asserts the output shape + contents. Catches things the unit suite
# can't (YAML serialization, path interpolation, cover hashing, etc.).
#
# Produces a single derivation that succeeds iff all assertions pass.
{ pkgs, core }:
let
  fixturesDir = ./fixtures/discover;

  tutorial = core.mkTutorial {
    name = "int-tutorial";
    manifest = {
      name = "int-tutorial";
      title = "Tutorial";
      description = "a tutorial for testing";
      updatedAt = core.lib.buildTime; # substituted at build time
      cover = ./fixtures/discover/regular-file.txt; # plain path: basename preserved
    };
    body = "# Hello";
    contentFiles = [ ./fixtures/discover/regular-file.txt ]; # list: basename
  };

  playground = core.mkPlayground {
    name = "int-playground";
    manifest = {
      name = "int-playground";
      title = "Playground";
      playground = {
        machines = [ ];
      };
    };
    rootFiles = {
      "docker-bake.json" = pkgs.writeText "bake.json" "{}";
    };
  };

  challenge = core.mkChallenge {
    name = "int-challenge";
    manifest = {
      name = "int-challenge";
      title = "Challenge";
    };
    body = "# Problem";
    solution = "# Answer";
  };

  hashed = core.mkTutorial {
    name = "int-hashed";
    manifest = {
      name = "int-hashed";
      title = "Hashed";
      cover = core.hashedCover ./fixtures/discover/regular-file.txt;
    };
  };

  course = core.mkCourse {
    name = "int-course";
    manifest = {
      name = "int-course";
      title = "Course";
    };
    children = {
      "01-module" = {
        manifest = {
          kind = "module";
          title = "Mod";
        };
        children = {
          "01-lesson" = {
            manifest = {
              kind = "lesson";
              title = "Lesson";
            };
            contentFiles = {
              "01-overview.md" = pkgs.writeText "overview" "# Overview";
            };
          };
        };
      };
    };
  };
in
pkgs.runCommand "niximiuz-integration"
  {
    inherit
      tutorial
      playground
      challenge
      hashed
      course
      ;
    nativeBuildInputs = [ pkgs.gnugrep ];
  }
  ''
    fail() { echo "integration: $1" >&2; exit 1; }

    # --- tutorial: plain cover, list-form contentFiles ----------------------
    [ -f "$tutorial/content/index.md" ] || fail "tutorial: content/index.md missing"
    grep -q '^kind: tutorial$' "$tutorial/content/index.md" \
      || fail "tutorial: kind not injected into frontmatter"
    grep -q '^name: int-tutorial$' "$tutorial/content/index.md" \
      || fail "tutorial: name missing from frontmatter"
    grep -q '^cover: __static__/regular-file\.txt$' "$tutorial/content/index.md" \
      || fail "tutorial: plain cover path not rewritten correctly"
    [ -f "$tutorial/content/__static__/regular-file.txt" ] \
      || fail "tutorial: cover file not copied into __static__/"
    [ -f "$tutorial/content/regular-file.txt" ] \
      || fail "tutorial: list-form contentFile missing"
    # buildTime marker substituted with an ISO 8601 UTC timestamp
    grep -qE '^updatedAt: "?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"?$' \
      "$tutorial/content/index.md" \
      || fail "tutorial: updatedAt not substituted with a real timestamp"
    grep -q '__CONTENT_CORE_BUILD_TIME__' "$tutorial/content/index.md" \
      && fail "tutorial: buildTime marker leaked into output"
    :

    # --- playground: manifest.yaml, rootFiles sibling -----------------------
    [ -f "$playground/content/manifest.yaml" ] || fail "playground: manifest.yaml missing"
    grep -q '^kind: playground$' "$playground/content/manifest.yaml" \
      || fail "playground: kind not injected"
    [ -f "$playground/docker-bake.json" ] \
      || fail "playground: rootFiles did not land at \$out/"
    [ -e "$playground/content/docker-bake.json" ] \
      && fail "playground: rootFiles leaked into content/"
    :

    # --- challenge: solution.md present, no frontmatter --------------------
    [ -f "$challenge/content/index.md" ] || fail "challenge: index.md missing"
    [ -f "$challenge/content/solution.md" ] || fail "challenge: solution.md missing"
    head -1 "$challenge/content/solution.md" | grep -q '^# Answer$' \
      || fail "challenge: solution.md does not start with body"
    head -1 "$challenge/content/solution.md" | grep -q '^---$' \
      && fail "challenge: solution.md unexpectedly has frontmatter"
    :

    # --- hashed cover -------------------------------------------------------
    hashed_files=$(ls "$hashed/content/__static__/")
    echo "$hashed_files" | grep -qE '^regular-file\.[0-9a-f]{8}\.txt$' \
      || fail "hashed: __static__ filename not hashed (got: $hashed_files)"
    grep -qE '^cover: __static__/regular-file\.[0-9a-f]{8}\.txt$' "$hashed/content/index.md" \
      || fail "hashed: manifest cover does not reference hashed name"

    # --- course: nested tree, kind per level --------------------------------
    [ -f "$course/content/index.md" ] || fail "course: root index.md missing"
    grep -q '^kind: course$' "$course/content/index.md" \
      || fail "course: root kind not injected"
    [ -f "$course/content/01-module/00-index.md" ] \
      || fail "course: module 00-index.md missing"
    grep -q '^kind: module$' "$course/content/01-module/00-index.md" \
      || fail "course: module kind not carried through"
    [ -f "$course/content/01-module/01-lesson/00-index.md" ] \
      || fail "course: lesson 00-index.md missing"
    [ -f "$course/content/01-module/01-lesson/01-overview.md" ] \
      || fail "course: lesson contentFile missing"

    echo "integration: all assertions passed"
    touch $out
  ''
