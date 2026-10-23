# motionmaxxing: brew install subh05sus/tap/motionmaxxing (scripts/release.sh in the repo updates url and sha256)
class Motionmaxxing < Formula
  desc "Raw talking-head take in, finished short-form video out, on your own Claude plan"
  homepage "https://github.com/subh05sus/motionmaxxing"
  url "https://github.com/subh05sus/motionmaxxing/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "530966fef4adf874516f7997684f54c479d3d499e2f91fc30064b16983169c57"
  license "MIT"
  head "https://github.com/subh05sus/motionmaxxing.git", branch: "main"

  depends_on "ffmpeg"
  depends_on :macos
  depends_on "node"
  depends_on "python@3.12"
  depends_on "whisper-cpp"

  def install
    libexec.install Dir["*"]
    cd libexec do
      system "npm", "ci", "--no-audit", "--no-fund"
      system "npm", "run", "build"
    end
    bin.install_symlink libexec/"bin/mm"
  end

  def caveats
    <<~EOS
      Sign in to Claude once (a Claude plan with Claude Code; never an API key):
        mm login
      Then open the studio. Its setup page installs the editing tools the first time (3.3 GB):
        mm
      For the Dock:
        mm app
    EOS
  end

  test do
    assert_match "mm login", shell_output("#{bin}/mm help 2>&1", 2)
  end
end
