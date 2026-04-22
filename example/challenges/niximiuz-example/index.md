A minimal challenge that exercises the verifier's content check: write
the marker string `Niximiuz` into a file the verifier reads.

You are on the **`{{ .Channel }}`** channel.

::simple-task
---
:tasks: tasks
:name: verify_challenge_answer
---
#active
Waiting for `/tmp/niximiuz-challenge-answer` with the marker string...

#completed
Marker string found in answer file.
::

The verifier confirms the file exists and contains the expected marker
string. Peek at `solution.md` if you want to see the one-liner.
