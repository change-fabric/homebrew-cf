# homebrew-cf

The Homebrew tap for [change-fabric](https://changefabric.org), the `cf` Claude Code skills-and-hooks toolkit.

## Install

```sh
brew tap change-fabric/cf
brew install change-fabric
change-fabric-install
```

`brew install` stages the toolkit's source (skills, hooks, and its `install.rb`) under Homebrew's prefix and installs one command, `change-fabric-install`. Running it symlinks the skills into `~/.claude/skills`, wires the hooks into `~/.claude/settings.json` (a backup is written alongside it), and mirrors into `~/.pi` and `~/.config/opencode` when present. It reads no input and is idempotent, so it is safe to run again at any time.

`change-fabric-install` is the whole second step. It takes no arguments, asks nothing, and prints what it wired when it finishes.

## Verify it worked

The installer's own last lines are the first check. It prints the hook directory, every skill it linked, and the settings file it wrote:

```
cf shim installed:
  hooks    -> /Users/you/.claude/cf/bin (SessionStart, PreToolUse, ...)
  skills   -> /Users/you/.claude/skills (cf, cf:change, cf:drive, ...)
  settings -> /Users/you/.claude/settings.json (backup at .../settings.json.bak)
```

Two shell checks confirm it from the outside:

```sh
ls -l ~/.claude/skills | grep -c 'cf:'          # skill symlinks, expect dozens
grep -c '.claude/cf/bin' ~/.claude/settings.json # wired hook commands, expect > 0
```

And one end-to-end check inside the tool itself. Start a new `claude` session in any git repo. Before it answers anything, cf's SessionStart hook makes it ask you to pick a merge mode (Local only, Merge ready, Admin bypass, Yolo). If you get that prompt, the hooks are live. `/cf` and the other `cf:` skills are then invocable by name.

If you see no merge-mode prompt, the session was probably already running when you installed. Hooks are read at session start, so restart `claude`.

## Upgrading

**`brew upgrade change-fabric` does not apply the upgrade. Run `change-fabric-install` again afterwards, every time.**

```sh
brew upgrade change-fabric
change-fabric-install
```

This is not a tidiness step, and the cost of skipping it is worse than missing a new skill. `brew upgrade` installs the new version into a fresh, version-numbered Cellar directory and deletes the old one. The skill symlinks in `~/.claude/skills` point at the old directory by its real path, so after the upgrade every one of them dangles until the installer relinks them. The wired hook commands still work, because hooks are copied into `~/.claude/cf/bin` rather than symlinked, but they are the previous version's copies.

The same sandbox restriction that stops `brew install` from wiring the toolkit for you (below) applies to `brew upgrade`, which runs the identical formula hooks. No formula can close this gap; only running the command can.

Re-run it after `brew upgrade ruby` too. The hook commands wired into `settings.json` name a Ruby interpreter by path, and a Ruby upgrade moves it.

## Uninstalling

`brew uninstall change-fabric` removes the staged source and the `change-fabric-install` command. It does **not** undo anything the installer did to your home directory, and Homebrew has no way to: those files are outside the Cellar, which is the same boundary that made the install a second step.

After a bare `brew uninstall`, the hooks in `~/.claude/settings.json` keep firing on every Claude Code session, now pointing at a `~/.claude/cf/bin` whose scripts are still there, and every `cf:` skill symlink dangles. To remove the toolkit properly, undo the wiring first:

```sh
# 1. Drop every cf hook from settings.json (they all name ~/.claude/cf/bin)
ruby -rjson -e 'p=File.expand_path("~/.claude/settings.json"); d=JSON.parse(File.read(p));
  d["hooks"]&.each_value { |s| s.each { |g| g["hooks"]&.reject! { |h| h["command"].to_s.include?("/.claude/cf/bin/") } } };
  d["hooks"]&.each_value { |s| s.reject! { |g| (g["hooks"] || []).empty? } };
  File.write(p, JSON.pretty_generate(d) + "\n")'

# 2. Remove the skill symlinks and the hook scripts
rm -f ~/.claude/skills/cf ~/.claude/skills/cf:*
rm -rf ~/.claude/cf/bin

# 3. Mirrors, if you had Pi or OpenCode installed
rm -f ~/.pi/agent/extensions/cf-hooks
rm -rf ~/.config/opencode/skills/cf-*

# 4. Then remove the package
brew uninstall change-fabric
brew untap change-fabric/cf
```

Two things deliberately survive that: `~/.claude/cf` minus `bin` holds your own state (recorded contexts, session and gate records), and the `skills` path entries added to `~/.pi/agent/settings.json` and `~/.config/opencode/opencode.jsonc` are inert once the skills are gone. Remove them by hand if you want them gone.

Do not treat `~/.claude/settings.json.bak` as a clean pre-cf settings file. The installer rewrites it on every run, so it is the state from just before the most recent install, which already had cf hooks in it.

## Troubleshooting

**Every Claude Code session errors on a hook, or the hooks stopped firing, after `brew upgrade ruby`.** The wired hook commands name a Ruby interpreter by path. Run `change-fabric-install`.

**A `cf:` skill is not found, or `ls -l ~/.claude/skills` shows red or broken links.** The symlinks point into a Cellar directory that a `brew upgrade change-fabric` removed. Run `change-fabric-install`. To see which are broken:

```sh
find ~/.claude/skills -maxdepth 1 -type l ! -exec test -e {} \; -print
```

**A new skill or a rename from a release never showed up.** Same cause, same fix: the upgrade staged it, nothing linked it. Run `change-fabric-install`.

**You already had a hand-rolled `~/.claude` setup.** The installer only ever touches what it owns. In `settings.json` it removes and rewrites hook entries whose command names `~/.claude/cf/bin` (or the pre-rename `~/.claude/pst/bin`) and leaves every other hook, and every other key, alone. In `~/.claude/skills` it prunes only symlinks that point into its own `skills/` tree, leaving real directories and links into other repos untouched. It backs `settings.json` up to `settings.json.bak` before writing.

**You installed from a git clone before, and now from Homebrew.** Run `change-fabric-install` once. It relinks every skill at the Homebrew copy and rewrites the hook commands, so the clone stops being consulted. The clone itself is left on disk for you to delete.

**`change-fabric-install: command not found`.** Homebrew's `bin` is not on your `PATH` for this shell. Check `brew --prefix`, then use `$(brew --prefix)/bin/change-fabric-install` or fix the `PATH`.

## Why `brew install` does not wire it for you

Not a style preference: Homebrew makes it impossible on purpose, and the same limit applies to `install` and `post_install` alike.

Homebrew runs both hooks with `$HOME` reassigned to a throwaway temp directory it deletes afterwards, inside a `sandbox-exec` profile that denies writes outside the Cellar. `~/.claude` and `~/.claude.json` are on Homebrew's own deny-read list by name, alongside `~/.ssh` and `~/.aws`. A `post_install` that ran the installer would either write the whole toolkit into a directory that is about to be removed, or fail with `EPERM`. Verified against Homebrew 6.0.15 in `Library/Homebrew/formula.rb` (`run_post_install`), `formula_installer.rb` (`post_install`), and `sandbox.rb` (`deny_read_home`), and confirmed by running a throwaway formula through a real `brew install`.

So the toolkit gets as close to one-shot as a formula can: `brew install` puts a single command on your `PATH`, and that command does the whole job with no arguments and no prompts. It is the same shape as `chezmoi init`, `direnv hook`, `mise activate`, and `starship init`, which reach outside the Cellar for the same reason and hit the same wall.

`brew test change-fabric` runs the real installer end to end. Homebrew points `$HOME` at a scratch directory for tests, so the test proves the wiring works without touching the tester's own `~/.claude`.

## What you get

The toolkit is a set of Claude Code skills under the `cf:` namespace plus the hooks that surface them. Some are commands you invoke (`cf:change`, the dockerized release-gate sweep; `cf:drive`, which drives a PR to green and approved; `cf:code-review`; `cf:prune`). Most are rubrics that fire on their own when you edit a matching file. The full inventory, and which kind each skill is, is in [`skills/README.md`](https://github.com/change-fabric/change-fabric/blob/main/skills/README.md) in the toolkit repo.

## Updating the formula

`change-fabric/change-fabric`'s `bump-tap-formula` GitHub Actions workflow runs on every `skills/vX.Y.Z` tag push and opens a PR here via `brew bump-formula-pr`, bumping `url`, `version`, and `sha256` on the existing `Formula/change-fabric.rb`. It does not create the formula and does not touch anything else in this repo - review and merge those PRs like any other. Nothing reaches a user's `brew upgrade` until one of those PRs is merged by a human.

## License

See [change-fabric/change-fabric](https://github.com/change-fabric/change-fabric) for the toolkit's own license.
