class KeenEyes < Formula
    desc "AI-powered code review tool"
    homepage "https://github.com/tg1482/keen-eyes"
    url "https://github.com/tg1482/keen-eyes/archive/v1.0.0.tar.gz"
    sha256 "the_sha256_of_your_tarball"
    license "MIT"
  
    depends_on "jq"
    depends_on "gh"
  
    def install
      bin.install "bin/keen-eyes"
      libexec.install Dir["lib/*"]
      (bin/"keen-eyes").write_env_script libexec/"keen-eyes",
        KEEN_EYES_LIBEXEC: libexec
    end
  
    test do
      assert_match "Usage: keen-eyes", shell_output("#{bin}/keen-eyes --help")
    end
  end