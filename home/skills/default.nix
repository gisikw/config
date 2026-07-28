{ lib, pkgs, ... }:

# Agent skills, fetched from their source repos and pinned by rev +
# content hash. Each skill folder is linked into every discovery path the
# installed harnesses read:
#   ~/.claude/skills  — claude-code, opencode
#   ~/.agents/skills  — codex, opencode (cross-tool convention)
# pi has no skill discovery; it's the known exception.
#
# To bump a skill: update rev, clear hash, rebuild, copy the real hash
# from the mismatch error (or `nix flake prefetch github:<owner>/<repo>`).

let
  allium = pkgs.fetchFromGitHub {
    owner = "juxt";
    repo = "allium";
    rev = "899cb05e1418e001bf0cdbc7b542877859d138b0"; # v3.8.0
    hash = "sha256-UjikkCL9OiIqMCY07+8GreBOILYJwC+W8QNP/CLwLEM=";
  };

  # The allium CLI: the skills fall back to the language reference
  # without it, but with it on PATH every spec edit is formally checked.
  # (allium-tools also ships allium-lsp, a Node package; only the
  # marketplace plugin install uses it, so we skip it.)
  alliumTools = pkgs.fetchFromGitHub {
    owner = "juxt";
    repo = "allium-tools";
    rev = "7fa6247e1789490738f94a233e83c71d3c3c57d4"; # v3.5.0
    hash = "sha256-+nugpYD4mVgZqNmpYAwEGsu4dr0ZTP9TrLjqKNB2m9o=";
  };

  alliumCli = pkgs.rustPlatform.buildRustPackage {
    pname = "allium-cli";
    version = "3.5.0";
    src = alliumTools;
    cargoHash = "sha256-rJUy14i2KqKFqWCrThP+3ubRrWG7Ol1z280NPOeITKg=";
    buildAndTestSubdir = "crates/allium";
  };

  anthropicSkills = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "b29e7cf65e5cb78a5ac33d582270551bc74a14eb";
    hash = "sha256-RH2B03gj4kzw1j5LORezgUZPPu8mW+mWb+Kl2U7WUbY=";
  };

  # skill name -> source directory containing its SKILL.md
  skills =
    lib.genAttrs [ "allium" "distill" "elicit" "propagate" "tend" "weed" ]
      (name: "${allium}/skills/${name}")
    // {
      frontend-design = "${anthropicSkills}/skills/frontend-design";
    };

  targets = [ ".claude/skills" ".agents/skills" ];
in {
  home.packages = [ alliumCli ];

  home.file = lib.mkMerge (map
    (target:
      lib.mapAttrs' (name: src: lib.nameValuePair "${target}/${name}" { source = src; })
        skills)
    targets
  ++ [{
    # tend/weed as autonomous subagents (claude-code only).
    ".claude/agents/tend.md".source = "${allium}/agents/tend.md";
    ".claude/agents/weed.md".source = "${allium}/agents/weed.md";
  }]);
}
