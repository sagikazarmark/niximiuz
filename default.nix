# Top-level entrypoint. Composes core + content + loaders with the
# iximiuz conventions baked in (amd64-only platforms, ubuntu rootfs,
# channel-tag pattern, standard content-directory layout). A consumer's
# flake.nix typically only needs to set registry, vars, and root.
{
  mkContentPipeline =
    {
      # Required inputs
      pkgs,
      bake,
      root,
      registry,

      # Optional knobs
      defaultRoot ? "docker-image://ghcr.io/iximiuz/labs/rootfs:ubuntu-24-04",
      channels ? [ "dev" ], # extra channels beyond "live"; empty = live-only
      vars ? { }, # moduleArgs pass-through (kubeVersion, ...)

      # Per-entry data exposed to labx templates. Called with bakeScope
      # curried in so repo-level wiring can reach module passthru. Each
      # returned attribute becomes a `<key>.json` file; templates read
      # them as `.Extra.<key>.*`. Repo-specific conventions (e.g. a
      # `bake` key merging repo config with sibling vars.nix) live in
      # the caller's flake.nix; compose `loaders.content.mkEntryData` if
      # that pattern fits.
      data ?
        _scopeArgs: _name: _path:
        { },

      # Extra roots to scan for bake.nix modules beyond playgroundsDir.
      extraImageRoots ? [ ],

      # Path overrides (defaults mirror the iximiuz-repo layout)
      playgroundsDir ? root + "/playgrounds",
      tutorialsDir ? root + "/tutorials",
      challengesDir ? root + "/challenges",
      trainingsDir ? root + "/trainings",
      coursesDir ? root + "/courses",
      templatesDir ? root + "/_templates",

      # Escape hatches
      extraBakeModuleArgs ? _channel: { },
      extraBakeLibExtensions ?
        _channel: _final: _prev:
        { },
      extraManifestArgs ?
        _name: _path: _channel:
        { },

      # Per-kind post-resolve hooks. Run AFTER the library's built-in
      # transforms (e.g. access-control injection on playgrounds). Use
      # these to layer repo-specific defaults like drive-size budgets
      # without forking the content builders. Currently wired for
      # `playgrounds`; other kinds accept the knob but no-op today.
      extraPostResolve ? { },
    }:
    let
      platforms = [ "linux/amd64" ]; # iximiuz convention
      allChannels = [ "live" ] ++ channels;

      loaders = import ./lib/loaders;
      core = import ./lib/core { inherit pkgs; };
      content = core.content;

      imageRoots = extraImageRoots ++ [ playgroundsDir ];
      modules = builtins.foldl' (acc: dir: acc // loaders.bake.discoverBakeModules dir) { } imageRoots;

      moduleArgs =
        channel:
        {
          inherit
            channel
            registry
            defaultRoot
            platforms
            ;
        }
        // vars
        // (extraBakeModuleArgs channel);

      # scope-for-channel closure. The lib extensions are constructed
      # inline so channel-dependent helpers close over `channel`
      # naturally; modules call `lib.tag "path"` without threading the
      # channel themselves.
      mkBakeScope =
        channel:
        loaders.bake.mkScope {
          inherit bake modules;
          moduleArgs = moduleArgs channel;
          lib =
            final: prev:
            {
              # Moving-tag builder: `lib.tag "path"` →
              # "<registry>/<path>:<channel>". Used on simple moving-tag
              # targets and by `tagTarget` for the companion tag it appends
              # next to the content-addressed hash tag.
              tag = path: "${registry}/${path}:${channel}";

              # Filter that excludes Nix tooling files from an imported
              # Docker context, so edits to those files do not invalidate
              # the context store-path hash. Consumed via
              # `lib.mkContextWith { path = ./.; filter = lib.nixFileFilter; }`.
              nixFileFilter =
                p: _t:
                !(builtins.elem (baseNameOf p) [
                  "bake.nix"
                  "default.nix"
                  "manifest.nix"
                ]);

              # Shorthand for `lib.mkTarget` with the iximiuz defaults:
              # single-arch, rooted on the shared base rootfs. Targets
              # whose root is a chained image should call `lib.mkTarget`
              # directly and pass their own `contexts.root`.
              mkRootTarget =
                args:
                prev.mkTarget (
                  {
                    inherit platforms;
                    contexts.root = defaultRoot;
                  }
                  // args
                );

              # Content-addressed tag helper. Wraps the pure library
              # helper and additionally appends the moving companion tag
              # for this channel.
              tagTarget =
                path: target:
                let
                  hashed = core.lib.image.tagTarget {
                    inherit path target;
                    repository = registry;
                  };
                in
                hashed
                // {
                  tags = hashed.tags ++ [ "${registry}/${path}:${channel}" ];
                };

              # camelCase → UPPER_SNAKE attrset transform for Dockerfile
              # ARGs.
              toBuildArgs = core.lib.toBuildArgs;
            }
            // (extraBakeLibExtensions channel final prev);
        };

      # "live" is always present; read channel-invariant scope fields from
      # it.
      bakeScope = mkBakeScope "live";

      bakeFiles = loaders.bake.collectBakeFiles {
        inherit bake modules;
        channels = allChannels;
        scopeFor = mkBakeScope;
      };

      manifestArgs = loaders.content.mkManifestArgs {
        inherit pkgs bakeScope;
        extras = extraManifestArgs;
      };

      templateDirs = loaders.content.mkTemplateDirs { globals = [ templatesDir ]; };

      dataFn = data { inherit bakeScope; };

      noopPostResolve = _channelConfig: resolved: resolved;

      collectors = loaders.content.mkCollectors {
        perKind = {
          playgrounds =
            args:
            content.mkPlayground (args // { postResolve = extraPostResolve.playgrounds or noopPostResolve; });
          tutorials = content.mkTutorial;
          challenges = content.mkChallenge;
          trainings = content.mkTraining;
          courses = content.mkCourse;
        };
        inherit
          core
          manifestArgs
          templateDirs
          ;
        data = dataFn;
      };

      playgrounds = collectors.playgrounds playgroundsDir;
      tutorials = collectors.tutorials tutorialsDir;
      challenges = collectors.challenges challengesDir;
      trainings = collectors.trainings trainingsDir;
      courses = collectors.courses coursesDir;
    in
    {
      inherit
        bakeScope
        bakeFiles
        playgrounds
        tutorials
        challenges
        trainings
        courses
        ;
    };
}
