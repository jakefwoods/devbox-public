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
            aliases.reb = ["rebase" "-s" "all:wiproot" "-d" "trunk()"];
            aliases.tug = ["bookmark" "move" "--from" "heads(::@ & bookmarks())" "--to" "@"];

            revsets.log = "@ | ancestors(wip, 2) | trunk()";

            revset-aliases.wip = "trunk()..(visible_heads() & mine() & mutable())";
            revset-aliases.wiproot = "roots(trunk()..(visible_heads() & mine() & mutable()))";
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
