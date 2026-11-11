# motionmaxxing: installed with the line in the invite email (curl -fsSL https://motionmaxxing.thatdevguy.in/install |
# bash -s <code>), which runs brew install subh05sus/tap/motionmaxxing with that code; then the studio's update card, or
# mm update, brings new versions. scripts/release.sh in the (private) source repo sets url, version and sha256.
require "etc"
require "net/http"

# The package comes from motionmaxxing.thatdevguy.in, which hands it out only for a key: the invite code (the installer
# passes it as HOMEBREW_MOTIONMAXXING_KEY), or the key the studio keeps once it is signed in
# (~/.motionmaxxing/download-key). A key that works gets a redirect to a short-lived link to the private release, and
# Homebrew drops the key on that redirect.
class MotionmaxxingDownloadStrategy < CurlDownloadStrategy
  SITE = "motionmaxxing.thatdevguy.in"
  LINE = "curl -fsSL https://#{SITE}/install | bash -s YOUR-CODE".freeze

  def self.key
    given = ENV.fetch("HOMEBREW_MOTIONMAXXING_KEY", "").strip
    return given unless given.empty?

    file = File.join(Etc.getpwuid.dir, ".motionmaxxing", "download-key")
    File.exist?(file) ? File.read(file).strip : ""
  rescue
    ""
  end

  def fetch(timeout: nil)
    key = self.class.key
    stop!("motionmaxxing needs your invite code to download. Install it with the line from your invite email:\n  #{LINE}") if key.empty?
    # asked first, so a code that doesn't work gets a plain answer instead of curl's
    status = begin
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
        http.head(uri.path, "Authorization" => "Bearer #{key}", "User-Agent" => "motionmaxxing-formula").code.to_i
      end
    rescue => e
      stop!("Couldn't reach #{SITE} (#{e.class.name.split("::").last}). Check the internet connection and try again.")
    end
    case status
    when 200..399 then nil
    when 401 then stop!("Your code doesn't work for this download. Check it in your invite email, or ask for an invite at #{SITE}. " \
                        "Signed in to the studio already? Open it once (it brings this Mac's own key), then update again.")
    when 404 then stop!("This version isn't there yet. Try again in a few minutes.")
    when 429 then stop!("Too many tries. Wait a few minutes and try again.")
    else stop!("#{SITE} couldn't hand out the download right now (#{status}). Try again in a few minutes.")
    end
    meta[:headers] = ["Authorization: Bearer #{key}"]
    super
  end

  private

  def stop!(why)
    raise CurlDownloadStrategyError.new(url, why)
  end
end

class Motionmaxxing < Formula
  desc "Raw talking-head take in, finished short-form video out, on your own Claude plan"
  homepage "https://github.com/subh05sus/motionmaxxing-releases"
  url "https://motionmaxxing.thatdevguy.in/api/download/0.79.1/motionmaxxing-0.79.1-macos-arm64.tar.gz",
      using: MotionmaxxingDownloadStrategy
  version "0.79.1" # said, not read from the url: brew takes the 64 of arm64 for the version
  sha256 "3fe8369e89caa9f1068388aa72ee1d50439e1d50fe6d9e1f8471996bff018233"
  license :cannot_represent

  depends_on arch: :arm64
  depends_on "ffmpeg"
  depends_on :macos
  depends_on "node@24"
  depends_on "python@3.12"
  depends_on "whisper.cpp"

  def install
    # Dir["*"] skips top-level dotfiles, so name the agent-barrier .re-deny too (the one under plugin/ comes with the dir)
    libexec.install Dir["*"] + Dir[".re-deny"]
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
      The studio asks you to sign in to your motionmaxxing account; a new account needs an invitation code.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mm --version")
    system bin/"mm", "check"
  end
end
