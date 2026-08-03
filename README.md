# homebrew-cf

The Homebrew tap for [change-fabric](https://changefabric.org), the `cf` Claude Code skills-and-hooks toolkit.

## Usage

```
brew tap change-fabric/cf
brew install change-fabric
```

`brew install` stages the toolkit's source (skills, hooks, and its `install.rb`) under Homebrew's prefix - it does **not** touch your `~/.claude`, `~/.pi`, or `~/.config/opencode` on its own. After installing, run the command `brew install` prints in its caveats:

```
ruby "$(brew --prefix change-fabric)"/install.rb
```

That symlinks the skills into `~/.claude/skills`, wires the hooks into `~/.claude/settings.json` (a backup is written alongside it), and mirrors into `~/.pi` and `~/.config/opencode` when present. Re-run the same command after every `brew upgrade change-fabric` to pick up new or renamed skills and hooks; it is idempotent.

## Why a separate step

Homebrew formulas are expected to stay inside the Cellar during `brew install`; this toolkit's real job is mutating dotfiles outside it. Rather than have `brew install` silently reach into your home directory, the formula only stages the release and prints the exact command to run when you're ready - the same shape as `chezmoi init`, `direnv hook`, `mise activate`, and `starship init`.

## Updating the formula

`change-fabric/change-fabric`'s `bump-tap-formula` GitHub Actions workflow runs on every `skills/vX.Y.Z` tag push and opens a PR here via `brew bump-formula-pr`, bumping `url`, `version`, and `sha256` on the existing `Formula/change-fabric.rb`. It does not create the formula and does not touch anything else in this repo - review and merge those PRs like any other.

## License

See [change-fabric/change-fabric](https://github.com/change-fabric/change-fabric) for the toolkit's own license.
