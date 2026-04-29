# Notes for fixture 03

This fixture exercises the session-picker path. The test harness must inject a `recent-sessions.json` containing an older session with `gitBranch: "auth"` and a `firstUserPrompt` mentioning "deploy". The skill should infer `session_pointer == "older"` and prompt the user to pick.
