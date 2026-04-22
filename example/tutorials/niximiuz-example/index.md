This tutorial ships with the `niximiuz` example flake and exists to
exercise the full content pipeline: `manifest.nix`, body markdown, labx
template rendering, per-channel output, and integration testing via
`labctl`.

You are on the **`{{ .Channel }}`** channel, threaded through labx by
the pipeline before this body was rendered.

## The task

Create the marker file the verifier looks for:

```bash
touch /tmp/niximiuz-tutorial-done
```

::simple-task
---
:tasks: tasks
:name: verify_marker_file
---
#active
Waiting for `/tmp/niximiuz-tutorial-done` to appear...

#completed
Marker file created.
::

Once the task passes, you have confirmed the full round trip works:
`manifest.nix` evaluated, labx rendered this body with your channel and
registry variables, `labctl` pushed the result, and the verifier ran on
the playground machine the manifest references.
