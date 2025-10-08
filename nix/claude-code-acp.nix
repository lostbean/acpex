{
  lib,
  buildNpmPackage,
  fetchgit,
  nodejs_20,
}:

buildNpmPackage rec {
  pname = "claude-code-acp";
  version = "0.5.3";

  nodejs = nodejs_20; # required for sandboxed Nix builds on Darwin

  src = fetchgit {
    url = "https://github.com/zed-industries/claude-code-acp.git";
    rev = "v${version}"; # Or a specific commit hash, e.g., "abcdef1234567890abcdef1234567890abcdef12"
    sha256 = "sha256-QUCUteZlJXlNC0rqVfvYphRaTCl0yVPVYirVC93664E="; # Replace with the actual SHA256 hash of the fetched content
  };

  npmDepsHash = "sha256-8/Tf+aB2uziqhcJEYa2awdRJRSvLCTjpuOB54+9zBeU=";

}
