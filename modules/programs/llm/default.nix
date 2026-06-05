{ ... }:

# Reusable LLM/opencode tooling aspect.
#
# Provides:
# - ~/.opencode/bin on PATH (bash + zsh)
# - Agent skills (linked via linkChildren into ~/.agents/skills/)
#
# Host-specific config (registry, auth, opencode.jsonc) is layered on by
# defining `flake.aspects.llm` in the host repo — they merge.
{
  flake.aspects = { aspects, ... }: {
    llm = {
      description = "LLM/opencode tooling: PATH, agent skills";

      homeManager = { config, pkgs, lib, ... }: {
        # ~/.opencode/bin on PATH (bash + zsh).
        programs.bash.profileExtra = ''
          export PATH=$HOME/.opencode/bin:$PATH
        '';
        programs.zsh.initContent = ''
          export PATH=$HOME/.opencode/bin:$PATH
        '';

        # Agent skills linked individually (linkChildren) so unmanaged
        # siblings under ~/.agents/skills/ (e.g. ast-grep) are preserved.
        home.file = config.lib.mutableInputs.linkChildren ".agents/skills" ./skills;
      };
    };
  };
}
