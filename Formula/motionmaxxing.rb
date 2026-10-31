# motionmaxxing: brew install subh05sus/tap/motionmaxxing (naming the tap trusts it; then brew update && brew upgrade motionmaxxing)
# The built package from the public releases repo; scripts/release.sh in the (private) source repo updates url and
# sha256 for every release.
class Motionmaxxing < Formula
  desc "Raw talking-head take in, finished short-form video out, on your own Claude plan"
  homepage "https://github.com/subh05sus/motionmaxxing-releases"
  url "https://github.com/subh05sus/motionmaxxing-releases/releases/download/v0.30.1/motionmaxxing-0.30.1-macos-arm64.tar.gz"
  version "0.30.1" # said, not read from the url: brew takes the 64 of arm64 for the version
  sha256 "644f562cfae9692b6b8f4ad2558864bcb2dad58f569c5e04b7e5a97d90a93709"
  license :cannot_represent

  depends_on arch: :arm64
  depends_on "ffmpeg"
  depends_on :macos
  depends_on "node@24"
  depends_on "python@3.12"
  depends_on "whisper.cpp"

  def install
    libexec.install Dir["*"]
    node = formula_opt_bin("node@24")
    # the Agent SDK (Claude Code, which the studio runs on the user's own login) and puppeteer-core (the demo
    # recorder), at the versions the package pins
    cd libexec do
      system node/"npm", "ci", "--omit=dev", "--no-audit", "--no-fund", "--loglevel=error"
    end
    (bin/"mm").write_env_script libexec/"bin/mm", MM_PATH: "#{node}:#{formula_opt_libexec("python@3.12")}/bin"
  end

  # motionmaxxing.app (the studio in a window of its own) is not made here: Homebrew's sandbox keeps post_install out
  # of ~/Applications (tried with Homebrew 7.0), so mm makes it the first time it runs, and again after every upgrade
  def caveats
    <<~EOS
      Sign in to Claude once (a Claude plan with Claude Code; never an API key):
        mm login
      That also puts motionmaxxing.app in ~/Applications, if it is not there yet: the studio in its
      own window, for Spotlight and the Dock. Open it, or from a terminal:
        mm
      Its setup page installs the editing tools the first time (3.3 GB).
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mm --version")
    system bin/"mm", "check"
  end
end
