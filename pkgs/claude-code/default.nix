# Claude Code, vendored from gisikw/fort-nix so version bumps are a
# two-line edit (version + hashes) instead of waiting on the nixpkgs
# registry. Fetches Anthropic's prebuilt platform binaries from npm.
#
# To bump: set `version` to the latest (curl -s
# https://registry.npmjs.org/@anthropic-ai/claude-code/latest | jq -r
# .version), then refresh each hash with
#   nix-prefetch-url --unpack <url>  # then nix hash convert --hash-algo sha256
# or just let the mismatch error report the correct hash.
{ pkgs }:

let
  version = "2.1.293";

  sources = {
    x86_64-linux = {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64/-/claude-code-linux-x64-${version}.tgz";
      hash = "sha256-u9Bsu1ZDx4tu3L7X3Z67hHJ7XvcXXizE2H2t7L6c5fo=";
    };
    aarch64-darwin = {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code-darwin-arm64/-/claude-code-darwin-arm64-${version}.tgz";
      hash = "sha256-E8MUUald0drvZCNiUrVIEMuwlIy+ShzVES2sJoXVA7g=";
    };
  };

  src = pkgs.fetchzip {
    inherit (sources.${pkgs.stdenv.hostPlatform.system}) url hash;
  };
in

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "claude-code";
  inherit version src;

  nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.makeWrapper
    pkgs.patchelf
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 claude $out/bin/claude
  '' + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
    patchelf --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} $out/bin/claude
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --unset DEV
  '' + ''

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Agentic coding tool that lives in your terminal";
    homepage = "https://github.com/anthropics/claude-code";
    license = licenses.unfree;
    platforms = builtins.attrNames sources;
    mainProgram = "claude";
  };
}
