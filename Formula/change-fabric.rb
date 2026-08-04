# Formula/change-fabric.rb
#
# Homebrew tap formula for the change-fabric ("cf") Claude Code skills-and-
# hooks toolkit. This formula stages the toolkit's source tree (skills/,
# scripts/, install.rb) under the Cellar/opt prefix and installs one
# `change-fabric-install` command that wires it into the caller's real home.
#
# Why the wiring is not done for you during `brew install`: Homebrew runs
# both `install` and `post_install` with $HOME reassigned to a throwaway
# temp directory, inside a `sandbox-exec` profile that denies writes outside
# the Cellar and denies reads of ~/.claude by name. Verified against
# Homebrew 6.0.15 on macOS:
#   Library/Homebrew/formula.rb            `run_post_install` -> Dir.mktmpdir,
#                                          new_env[:HOME] = that temp dir
#   Library/Homebrew/formula_installer.rb  `post_install` -> Sandbox with
#                                          deny_read_home and no home write
#                                          path
#   Library/Homebrew/sandbox.rb            deny_read_home list includes
#                                          ".claude" and ".claude.json"
# A `post_install` hook here would install the toolkit into a directory
# Homebrew then deletes, or fail outright with EPERM. The single
# `change-fabric-install` command below is the closest a formula can get to
# a one-shot install, and it is the same shape chezmoi, direnv, mise and
# starship use for their own "this touches your dotfiles" step.
#
# sha256 below was computed by hand against the real GitHub Release tarball
# for skills/v0.36.1, the latest skills/v* tag in change-fabric/change-fabric
# as of this writing (2026-08-03):
#   curl -sL -o cf.tar.gz \
#     https://github.com/change-fabric/change-fabric/archive/refs/tags/skills/v0.36.1.tar.gz
#   shasum -a 256 cf.tar.gz
# -> 3cc421466fb96a3869e0f447667b4aa9c824f8929d01357c2282b826aa93d654

class ChangeFabric < Formula
  desc "Claude Code skills-and-hooks toolkit (cf shim) installer"
  homepage "https://changefabric.org"
  url "https://github.com/change-fabric/change-fabric/archive/refs/tags/skills/v0.36.1.tar.gz"
  sha256 "3cc421466fb96a3869e0f447667b4aa9c824f8929d01357c2282b826aa93d654"
  license "MIT"
  revision 1

  # install.rb uses endless method definitions (`def bin = File.join(...)`),
  # which require Ruby >= 3.0. macOS's bundled system Ruby is 2.6 on many
  # supported OS versions, so this cannot rely on `/usr/bin/ruby` and must
  # depend on Homebrew's own ruby formula.
  depends_on "ruby"

  # No compiled artifact: this is a script bundle. Stage the whole release
  # tree as-is so install.rb's own relative-path resolution (require_relative
  # 'scripts/skill_registry', Dir.glob against skills/, etc, all rooted at
  # __dir__) keeps working unmodified once symlinked under opt_prefix.
  def install
    prefix.install Dir["*"]

    # install.rb resolves its source tree from __dir__ and its target tree
    # from Dir.home, so the wrapper needs no cwd and no arguments. It pins
    # the depended-on Ruby by opt path rather than trusting whatever `ruby`
    # the caller's PATH resolves to, which on macOS is often the system 2.6
    # that cannot parse install.rb at all.
    (bin/"change-fabric-install").write <<~SH
      #!/bin/bash
      set -euo pipefail
      exec "#{formula_opt_bin("ruby")}/ruby" "#{opt_prefix}/install.rb" "$@"
    SH
  end

  def caveats
    <<~EOS
      One command finishes the install:

        change-fabric-install

      It symlinks the skills into ~/.claude/skills, wires the hooks into
      ~/.claude/settings.json (backed up alongside it as settings.json.bak),
      and mirrors into ~/.pi and ~/.config/opencode when present. It reads
      no input, is idempotent, and is safe to run again at any time.

      `brew install` cannot do this for you. Homebrew runs formula install
      and post-install steps with $HOME pointed at a temp directory, inside
      a sandbox that denies writes to your real home and denies reads of
      ~/.claude by name, so any wiring done there would land in a directory
      Homebrew immediately deletes.

      Run change-fabric-install again after EVERY `brew upgrade
      change-fabric`. The upgrade cannot apply itself, for the same reason
      the install cannot, and it is not only new skills you would miss:
      `brew upgrade` deletes the old versioned Cellar directory that every
      ~/.claude/skills symlink points at, so the skills stay broken until
      you re-run it.

      Run it again after `brew upgrade ruby` too, which moves the
      interpreter path baked into the wired hook commands.

      To check the install: start a new `claude` session and confirm it
      asks you to pick a merge mode before it answers anything.
    EOS
  end

  test do
    # `brew test` is the one lifecycle step where running the real installer
    # proves something safely: Homebrew points $HOME at testpath, so this is
    # a genuine end-to-end install into a throwaway home that never touches
    # the tester's own ~/.claude.
    system bin/"change-fabric-install"

    settings = testpath/".claude/settings.json"
    assert_path_exists settings
    assert_path_exists testpath/".claude/cf/bin/session_start.rb"

    hooks = JSON.parse(settings.read).fetch("hooks")
    assert_includes hooks.keys, "PreToolUse"
    wired = hooks.values.flatten.flat_map { |group| group.fetch("hooks") }
    commands = wired.map { |hook| hook.fetch("command") }.join("\n")
    assert_match "#{testpath}/.claude/cf/bin/", commands

    skills = Dir[testpath/".claude/skills/*"]
    refute_empty skills
    assert skills.any? { |skill| File.symlink?(skill) },
           "expected skills to be symlinked out of the staged prefix"

    # Idempotent: a second run must leave the same settings behind, since
    # every `brew upgrade change-fabric` asks the user to run it again.
    before = settings.read
    system bin/"change-fabric-install"
    assert_equal before, settings.read
  end
end
