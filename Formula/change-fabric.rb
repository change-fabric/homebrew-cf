# Formula/change-fabric.rb
#
# Homebrew tap formula for the change-fabric ("cf") Claude Code skills-and-
# hooks toolkit. This formula stages the toolkit's source tree (skills/,
# scripts/, install.rb) under the Cellar/opt prefix. It deliberately does
# NOT run install.rb during `brew install` - see caveats below and the
# repo's homebrew-cf README for why.
#
# sha256 below was computed by hand against the real GitHub Release tarball
# for skills/v0.36.1, the latest skills/v* tag in change-fabric/change-fabric
# as of this writing (2026-08-03):
#   curl -sL -o cf.tar.gz \
#     https://github.com/change-fabric/change-fabric/archive/refs/tags/skills/v0.36.1.tar.gz
#   shasum -a 256 cf.tar.gz
# -> 3cc421466fb96a3869e0f447667b4aa9c824f8929d01357c2282b826aa93d654
#
# NOTE (see openQuestionsForHuman): this repo carries no LICENSE file at the
# tagged commit, so no `license` line is set below. Do not guess a license;
# either add one, or explicitly set `license :cannot_specify` once the
# maintainer decides. Homebrew's own audit (`brew audit --strict`) will flag
# a formula with neither.

class ChangeFabric < Formula
  desc "Claude Code skills-and-hooks toolkit (cf shim) installer"
  homepage "https://changefabric.org"
  url "https://github.com/change-fabric/change-fabric/archive/refs/tags/skills/v0.36.1.tar.gz"
  sha256 "3cc421466fb96a3869e0f447667b4aa9c824f8929d01357c2282b826aa93d654"
  # license "TBD" -- see NOTE above; do not set until the maintainer confirms.

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
  end

  def caveats
    <<~EOS
      change-fabric has been staged at:
        #{opt_prefix}

      `brew install` does NOT modify your ~/.claude, ~/.pi, or
      ~/.config/opencode directories on its own - installing the toolkit
      into your live Claude Code / pi / opencode setup means running its
      installer once, deliberately, against your real home directory:

        ruby #{opt_prefix}/install.rb

      This symlinks skills into ~/.claude/skills, wires hooks into
      ~/.claude/settings.json (backed up alongside it as settings.json.bak),
      and mirrors into ~/.pi and ~/.config/opencode if present.

      Re-run the same command after every `brew upgrade change-fabric` to
      pick up new or renamed skills and hooks - the installer is idempotent
      and safe to run again.
    EOS
  end

  test do
    # Does not invoke install.rb's real behavior (which mutates the live
    # user home) - `brew test` must never touch ~/.claude. Instead this
    # verifies the staged installer is present and syntactically valid
    # under the depended-on Ruby.
    installer = opt_prefix/"install.rb"
    assert_path_exists installer
    system formula_opt_bin("ruby")/"ruby", "-c", installer.to_s
  end
end
