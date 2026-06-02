# Example: Analyzing a failed AIX build

This example shows how the distillation tools dramatically reduce log size while preserving critical error information.

## Scenario

AIX 7.1 build failed with bundler dependency conflicts. Raw log: 11,363 lines.

## Commands

```bash
# Download and distill the failed job
./download_buildkite_log.sh 019e7621-8db2-4d3a-8541-d78b910bd808

# Result: 11,363 lines → 280 lines (97.5% reduction)
```

## Raw Log (excerpt from 11,363 lines)

```
2026-05-29T17:12:34.567Z Starting bundle install
2026-05-29T17:12:34.678Z Fetching gem metadata from https://rubygems.org/
2026-05-29T17:12:35.789Z Fetching gem metadata from https://rubygems.org/
2026-05-29T17:12:36.890Z Fetching gem metadata from https://rubygems.org/
2026-05-29T17:12:37.901Z Fetching gem metadata from https://rubygems.org/
[                         ] 0%
[==>                      ] 8%
[====>                    ] 16%
[======>                  ] 24%
[========>                ] 32%
[==========>              ] 40%
[============>            ] 48%
[==============>          ] 56%
[================>        ] 64%
[==================>      ] 72%
[====================>    ] 80%
[======================> ] 88%
[========================] 96%
2026-05-29T17:14:12.345Z Resolving dependencies....
2026-05-29T17:14:13.456Z Resolving dependencies.....
2026-05-29T17:14:14.567Z Resolving dependencies......
... 10,000 more lines of timestamps and progress bars ...
```

## Distilled Log (280 lines total)

```
Starting bundle install
Fetching gem metadata from https://rubygems.org/
Resolving dependencies
Error:
Bundler found conflicting requirements for the Ruby version:
  In Gemfile:
    Ruby 
        Ruby  (>= 2.6)
    cookstyle (~> 8.6) was resolved to 8.6.10, which depends on
      Ruby  (>= 2.7)

Bundler could not find compatible versions for gem "pry":
  In Gemfile:
    pry (= 0.15.2)
    pry-byebug (< 3.11) was resolved to 3.8.0, which depends on
      pry (~> 0.10)
    pry-stack_explorer was resolved to 0.6.3, which depends on
      pry (~> 0.13)

🚨 Error: The command exited with status 1
```

## Analysis

From the distilled log, we immediately see:
1. **Pry version conflict:** `pry = 0.15.2` incompatible with `pry-byebug (~> 0.10)` and `pry-stack_explorer (~> 0.13)`
2. **Ruby version mismatch:** Some gems require Ruby >= 2.7 but AIX uses Ruby 3.0.3

## Fix Applied

Updated `Gemfile-aix` to match main Gemfile pry constraints:
- Changed `byebug < 12` → `byebug < 13`
- Changed `pry-byebug < 3.11` → `pry-byebug < 3.12`

This resolved the version conflict and build passed.

## Time Saved

- **Without distillation:** Scroll through 11,363 lines looking for errors
- **With distillation:** Scan 280 focused lines, find root cause in seconds
- **Token efficiency:** ~97% fewer tokens for AI analysis
