{
  mockPkgs,
  core,
  ...
}:
let
  # Recording-core captures args to every core builder.
  recordingCore = core // {
    mkPlayground = args: {
      _args = args;
      _kind = "rec-playground";
    };
    mkTutorial = args: {
      _args = args;
      _kind = "rec-tutorial";
    };
    mkChallenge = args: {
      _args = args;
      _kind = "rec-challenge";
    };
    mkTraining = args: {
      _args = args;
      _kind = "rec-training";
    };
    mkCourse = args: {
      _args = args;
      _kind = "rec-course";
    };
  };

  # Stub labx rendering: return the source dir so readFile can hit fixture
  # files (index.md, solution.md, README.md).
  stubRender = { source, ... }: source;

  # Build a content with the stubbed renderWithLabx; content builders close
  # over this at import time.
  realContent = import ../../lib/content {
    pkgs = mockPkgs;
    core = recordingCore;
  };
  stubContent = realContent // {
    renderWithLabx = stubRender;
  };

  # Re-import each content builder with the stubbed content so orchestrating
  # mode actually exercises our stub.
  builderDeps = {
    core = recordingCore;
    content = stubContent;
    pkgs = mockPkgs;
  };
  playgroundBuilder = import ../../lib/content/builders/playground.nix builderDeps;
  tutorialBuilder = import ../../lib/content/builders/tutorial.nix builderDeps;
  challengeBuilder = import ../../lib/content/builders/challenge.nix builderDeps;
  trainingBuilder = import ../../lib/content/builders/training.nix builderDeps;
  courseBuilder = import ../../lib/content/builders/course.nix builderDeps;

  presets = import ../../lib/loaders;

  manifestArgs = name: _path: channel: {
    inherit name channel;
  };

  collectors = presets.content.mkCollectors {
    perKind = {
      playgrounds = playgroundBuilder.mkPlayground;
      tutorials = tutorialBuilder.mkTutorial;
      challenges = challengeBuilder.mkChallenge;
      trainings = trainingBuilder.mkTraining;
      courses = courseBuilder.mkCourse;
    };
    core = recordingCore;
    inherit manifestArgs;
    templateDirs = _path: [ ];
    data = _name: _path: { };
  };

  root = ../fixtures/content;

  playgrounds = collectors.playgrounds (root + "/playgrounds");
  tutorials = collectors.tutorials (root + "/tutorials");
  challenges = collectors.challenges (root + "/challenges");
  trainings = collectors.trainings (root + "/trainings");
  courses = collectors.courses (root + "/courses");
in
{
  # ---------- mkPlaygrounds ----------

  testMkPlaygroundsDiscoversEntries = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames playgrounds);
    expected = [ "etcd" ];
  };

  testMkPlaygroundsProducesChannels = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames playgrounds.etcd);
    expected = [
      "dev"
      "live"
    ];
  };

  testMkPlaygroundsCallsCoreBuilder = {
    expr = playgrounds.etcd.dev._kind;
    expected = "rec-playground";
  };

  testMkPlaygroundsLivePublicAccessControl = {
    expr = playgrounds.etcd.live._args.manifest.playground.accessControl.canList;
    expected = [ "anyone" ];
  };

  testMkPlaygroundsDevDefaultAccessControl = {
    expr = playgrounds.etcd.dev._args.manifest.playground.accessControl.canList;
    expected = [ "owner" ];
  };

  testMkPlaygroundsReadsReadme = {
    expr = playgrounds.etcd.dev._args.manifest ? markdown;
    expected = true;
  };

  # ---------- mkTutorials ----------

  testMkTutorialsDiscoversEntries = {
    expr = builtins.attrNames tutorials;
    expected = [ "lb" ];
  };

  testMkTutorialsProducesChannels = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames tutorials.lb);
    expected = [
      "dev"
      "live"
    ];
  };

  testMkTutorialsCallsCoreBuilder = {
    expr = tutorials.lb.dev._kind;
    expected = "rec-tutorial";
  };

  testMkTutorialsPassesBody = {
    expr = tutorials.lb.dev._args.body != null;
    expected = true;
  };

  testMkTutorialsBodyIsString = {
    expr = builtins.isString tutorials.lb.dev._args.body;
    expected = true;
  };

  testMkTutorialsHasContentNameRootFile = {
    expr = tutorials.lb.dev._args.rootFiles ? ".content-name";
    expected = true;
  };

  testMkTutorialsDevTitlePrefixed = {
    expr = tutorials.lb.dev._args.manifest.title;
    expected = "DEV: Load Balancing";
  };

  testMkTutorialsManifestStrippedOfName = {
    expr = tutorials.lb.dev._args.manifest ? name;
    expected = false;
  };

  # ---------- mkChallenges ----------

  testMkChallengesDiscoversEntries = {
    expr = builtins.attrNames challenges;
    expected = [ "invisible-pod" ];
  };

  testMkChallengesCallsCoreBuilder = {
    expr = challenges."invisible-pod".dev._kind;
    expected = "rec-challenge";
  };

  testMkChallengesPassesBody = {
    expr = challenges."invisible-pod".dev._args.body != null;
    expected = true;
  };

  testMkChallengesPassesSolution = {
    expr = challenges."invisible-pod".dev._args.solution != null;
    expected = true;
  };

  testMkChallengesSolutionIsString = {
    expr = builtins.isString challenges."invisible-pod".dev._args.solution;
    expected = true;
  };

  testMkChallengesHasContentNameRootFile = {
    expr = challenges."invisible-pod".dev._args.rootFiles ? ".content-name";
    expected = true;
  };

  # ---------- mkTrainings ----------

  testMkTrainingsDiscoversEntries = {
    expr = builtins.attrNames trainings;
    expected = [ "workshop" ];
  };

  testMkTrainingsCallsCoreBuilder = {
    expr = trainings.workshop.dev._kind;
    expected = "rec-training";
  };

  testMkTrainingsPassesBody = {
    expr = trainings.workshop.dev._args.body != null;
    expected = true;
  };

  testMkTrainingsHasContentNameRootFile = {
    expr = trainings.workshop.dev._args.rootFiles ? ".content-name";
    expected = true;
  };

  # ---------- mkCourses ----------
  # Course is static-only (no labx orchestration). The collector walks the
  # directory and each course's manifest.nix is loaded once; channel
  # iteration happens inside content.mkCourse from the manifest's channels.

  testMkCoursesDiscoversEntries = {
    expr = builtins.attrNames courses;
    expected = [ "khtw" ];
  };

  testMkCoursesProducesChannels = {
    expr = builtins.sort builtins.lessThan (builtins.attrNames courses.khtw);
    expected = [
      "dev"
      "live"
    ];
  };

  testMkCoursesCallsCoreBuilder = {
    expr = courses.khtw.dev._kind;
    expected = "rec-course";
  };
}
