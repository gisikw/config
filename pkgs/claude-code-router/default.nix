{ lib
, stdenv
, buildNpmPackage
, fetchurl
, nodejs_22
, python3
, cctools
}:

# Built against nodejs_22: the npm 12 bundled with the default nodejs
# drops the nodedir/build-from-source env configs and gates install
# scripts behind approve-scripts, which both silently skips
# better-sqlite3's node-gyp compile and breaks npmInstallHook.
let
  buildNpmPackage' = buildNpmPackage.override { nodejs = nodejs_22; };
in

# claude-code-router v3, packaged from the published npm tarball —
# nixpkgs (2.0.0) lags far behind upstream. The tarball ships prebuilt
# dist/ (CLI + web UI), so the build is just an npm install of the five
# runtime deps; package-lock.json is generated from the tarball and
# vendored next to this file.
#
# To bump: update version, then regenerate lock + hashes:
#   curl -LO https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-<V>.tgz
#   tar xzf claude-code-router-<V>.tgz && cd package
#   npm install --package-lock-only --ignore-scripts
#   cp package-lock.json <this dir>/
#   nix store prefetch-file <tarball-url>                    # → src.hash
#   nix run nixpkgs#prefetch-npm-deps -- package-lock.json   # → npmDepsHash

buildNpmPackage' rec {
  pname = "claude-code-router";
  version = "3.0.17";

  src = fetchurl {
    url = "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-${version}.tgz";
    hash = "sha256-BXXxGtX+YhZBQ+f0uuev33PC9kH4HpvXGOVrMKigTLg=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-4qJIvJ7BovIn0kSO7TE+j9/LM9j1/DwG/f54MZjYRiU=";

  # dist/ is prebuilt in the tarball; there is nothing to compile except
  # dependencies' native bindings during npm install.
  dontNpmBuild = true;

  # The published package keeps its monorepo lifecycle scripts; prepack
  # runs `npm --prefix ../..`, which escapes the tarball and ENOENTs,
  # breaking npmInstallHook's `npm pack --dry-run` file listing.
  npmPackFlags = [ "--ignore-scripts" ];

  # better-sqlite3 publishes no Node 24 prebuilds: skip the
  # prebuild-install network attempt (sandboxed anyway) and compile via
  # node-gyp — python3 drives it; darwin additionally needs Apple
  # libtool from cctools for the static sqlite3.a step.
  env.npm_config_build_from_source = "true";
  nativeBuildInputs = [ python3 ]
    ++ lib.optionals stdenv.isDarwin [ cctools ];

  # Not versionCheckHook: v3 gates --version (and everything but --help)
  # behind having a provider configured. --help proves the CLI loads;
  # reaching the provider gate on --version proves the better-sqlite3
  # native binding works, since ccr creates its sqlite config first.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR"
    $out/bin/ccr --help >/dev/null
    $out/bin/ccr --version >/dev/null 2>&1 || true
    test -f "$TMPDIR/.claude-code-router/config.sqlite"
    runHook postInstallCheck
  '';

  meta = {
    description = "Route Claude Code requests to different models and customize any request";
    homepage = "https://github.com/musistudio/claude-code-router";
    license = lib.licenses.mit;
    mainProgram = "ccr";
  };
}
