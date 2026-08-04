# homebrew-cf

The Homebrew tap for [change-fabric](https://changefabric.org), the `cf` Claude Code skills-and-hooks toolkit.

## Usage

```sh
brew tap change-fabric/cf
brew install change-fabric
change-fabric-install
```

`brew install` stages the toolkit's source (skills, hooks, and its `install.rb`) under Homebrew's prefix and installs one command, `change-fabric-install`. Running it symlinks the skills into `~/.claude/skills`, wires the hooks into `~/.claude/settings.json` (a backup is written alongside it), and mirrors into `~/.pi` and `~/.config/opencode` when present. It reads no input and is idempotent, so it is safe to run again at any time.

Run `change-fabric-install` again after `brew upgrade change-fabric` to pick up new or renamed skills and hooks, and after `brew upgrade ruby`, which moves the interpreter path baked into the wired hook commands.

## Why `brew install` does not wire it for you

Not a style preference: Homebrew makes it impossible on purpose, and the same limit applies to `install` and `post_install` alike.

Homebrew runs both hooks with `$HOME` reassigned to a throwaway temp directory it deletes afterwards, inside a `sandbox-exec` profile that denies writes outside the Cellar. `~/.claude` and `~/.claude.json` are on Homebrew's own deny-read list by name, alongside `~/.ssh` and `~/.aws`. A `post_install` that ran the installer would either write the whole toolkit into a directory that is about to be removed, or fail with `EPERM`. Verified against Homebrew 6.0.15 in `Library/Homebrew/formula.rb` (`run_post_install`), `formula_installer.rb` (`post_install`), and `sandbox.rb` (`deny_read_home`), and confirmed by running a throwaway formula through a real `brew install`.

So the toolkit gets as close to one-shot as a formula can: `brew install` puts a single command on your `PATH`, and that command does the whole job with no arguments and no prompts. It is the same shape as `chezmoi init`, `direnv hook`, `mise activate`, and `starship init`, which reach outside the Cellar for the same reason and hit the same wall.

`brew test change-fabric` runs the real installer end to end. Homebrew points `$HOME` at a scratch directory for tests, so the test proves the wiring works without touching the tester's own `~/.claude`.

## Updating the formula

`change-fabric/change-fabric`'s `bump-tap-formula` GitHub Actions workflow runs on every `skills/vX.Y.Z` tag push and opens a PR here via `brew bump-formula-pr`, bumping `url`, `version`, and `sha256` on the existing `Formula/change-fabric.rb`. It does not create the formula and does not touch anything else in this repo - review and merge those PRs like any other.

## License

See [change-fabric/change-fabric](https://github.com/change-fabric/change-fabric) for the toolkit's own license.
