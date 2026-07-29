{ inputs, ... }:

{
  flake.aspects = { aspects, ... }: {
    git = {
      description = "Git version control";

      homeManager = { pkgs, ... }: {
        programs.git = {
          enable = true;
          settings.core.editor = "vim";
          settings.push.default = "simple";
          settings.rebase.autosquash = true;
        };

        programs.jujutsu = {
          enable = true;
          settings = {
            ui.editor = "vim";
            ui.pager = "less -FRX";
            ui.default-command = "log";

            aliases.gpt = ["git" "push" "--tracked"];
            aliases.reb = ["rebase" "-s" "all:reb-command-targets" "-d" "trunk()"];
            aliases.tug = ["bookmark" "move" "--from" "heads(::@ & bookmarks())" "--to" "@"];

            # Escape hatch: mutable work of mine that `wip` no longer surfaces because it has
            # no bookmark and isn't under @. Without this, such stacks vanish silently.
            aliases.lost = ["log" "-r" "mine() & mutable() & ~::bookmarks() & ~::@"];

            revsets.log = "present(@) | ancestors(wip, 2) | trunk()";

            revset-aliases.tracking = "bookmarks() | tracked_remote_bookmarks()";
            revset-aliases.here = "heads(@::) | working_copies()";
            revset-aliases.attention = "mutable() & (conflicts() | divergent())";
            revset-aliases.wip = "trunk()..((tracking | here | attention) & mutable())";

            # roots of branches that should be auto-rebased
            revset-aliases.reb-command-targets = "roots(trunk()..(visible_heads() & mine() & mutable()))";

            revset-aliases."bookmark_base(rev)" = "latest((::rev ~ rev) & bookmarks())";
          };
        };

        home.packages = [
          pkgs.jjui
        ];
      };
    };
  };
}
