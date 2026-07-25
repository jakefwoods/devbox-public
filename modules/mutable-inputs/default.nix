{ inputs, ... }:

# Live-editable flake inputs.
#
# ── Problem ──────────────────────────────────────────────────────────
#
# Nix flake inputs are immutable. This is great for reproducibility but is
# annoying when iterating on config: editing a dotfile means a commit,
# push and rebuild.
#
# Similarly, working on a flake's upstream dependency is annoying, if you
# change your local copy of nixpkgs you need to remember to `--override-input`
# every time.
#
# home-manager's mkOutOfStoreSymlink solves the symlink half, but it's annoying
# to work with: You have to provide absolute paths, and you have to clone the
# repository yourself, breaking `nix run github:you/your-flake`.
#
# ── Approach ─────────────────────────────────────────────────────────
#
# The core idea of mutableInputs is to define your mutable inputs declaratively in nix,
# and have nix manage them. If we can guarantee that working copies of our flake inputs exist
# in a known location, then we can provide much more ergonomic symlink definitions for
# config and in-progress changes to our inputs.
#
# Also, if a specific target doesn't want mutability it shouldn't be a problem: The system will automatically
# do normal /nix/store read-only symlinks and call it a day.
#
# ── Usage (symlinked config) ─────────────────────────────────────────
#
# Register mutable inputs:
#
#   local.mutableInputs.inputs.devbox-private.flakeInput = inputs.self;      # self-mutability
#   local.mutableInputs.inputs.devbox-public.flakeInput = inputs.devbox-public;
#
# Enable mutability:
#
#   local.mutableInputs.enable = true;
#   local.mutableInputs.root = "${config.home.homeDirectory}/src";
#
# In any aspect, use `link` as a replacement for `mkOutOfStoreSymlink`:
#
#   xdg.configFile."doom".source = config.lib.mutableInputs.link ./doom.d;
#
# If mutableInputs is enabled and ./doom.d lives inside a registered input, link returns a symlink to the mutable working copy.
# Otherwise it returns a normal read-only store path.
#
# ── Usage (input development) ─────────────────────────────────────────
#
# Say you change `devbox-public` and want to test those changes in `devbox-private`, `mutableInputs` generates
# a `.mutable` sub-flake on activation in the local working copy. `.mutable` is automatically generated to be the same
# as your root flake, except its dependencies are routed to your local working copies. So in `devbox-private` you could run:
#
#   home-manager switch --flake .mutable    # eval devbox-private using the local copies of devbox-public including your changes
#
# ── How it works ─────────────────────────────────────────────────────
#
# On each activation:
#   1. Each registered input is cloned (or rebased) to `${local.mutableInputs.root}/<name>/` using
#      the URL and rev from the top-level flake's flake.lock.
#   2. For each registered input, we inspect its resolved dependencies (flakeInput.inputs)
#      and compare each dep's identity against the mutable set. If any dep matches another
#      registered mutable input, a `.mutable/` sub-flake is generated in that repo.
#   3. Each `.mutable/flake.nix` uses git+file:// overrides pointing at sibling working
#      copies, then re-exports the repo's own outputs unchanged.
#
# The `.mutable/` directories have their own .git (so nix treats them as separate source trees)
# and should be added to each repo's .gitignore.
#
# Identity matching uses `toString` on resolved flake inputs — two inputs match only if they
# resolve to the same store path. This means inputs unified via `follows` are detected
# automatically, while independently-pinned copies of the same upstream are left alone.
#
# ── Bootstrapping ────────────────────────────────────────────────────
#
# Say you run one of these for the first time:
#
#    home-manager switch --flake .
#    home-manager switch --flake github:<you>/<your-flake>
#
# This will work fine even if nothing has been cloned. On first run mutableInputs will activate, clone the repos per your configuration
# and set up the `.mutable` sub-flake in any repos that have overlapping mutable dependencies. Ready for dev!
{
  flake.aspects = { aspects, ... }: {
    mutableInputs = {
      description = "Mutable working copies of flake inputs for live-edit dotfiles";

      homeManager = { config, lib, pkgs, ... }:
      let
        cfg = config.local.mutableInputs;

        # Resolve the working copy path for a registered input.
        # Uses the per-input path override if set, otherwise ${root}/<name>.
        pathFor = name:
          let p = cfg.inputs.${name}.path;
          in if p != null then p else "${cfg.root}/${name}";

        # The root flake whose flake.lock we read for clone URLs and pinned
        # revs. This must be the *consuming* flake, not inputs.self: when these
        # aspects are pulled in as another flake's output (e.g. `flake.aspects =
        # inputs.devbox-public.aspects`), inputs.self resolves to the flake that
        # *defines* the aspect, whose lock knows nothing about the consumer's
        # inputs. Hosts pass their own `self` via local.mutableInputs.rootFlake.
        topFlake = cfg.rootFlake;

        # Read the top-level flake's lock file to derive clone URLs and pinned revs.
        lockPath = topFlake.outPath + "/flake.lock";
        lockData =
          if builtins.pathExists lockPath
          then builtins.fromJSON (builtins.readFile lockPath)
          else throw ''
            mutableInputs: No flake.lock found at ${lockPath}.
            Run 'nix flake lock' to generate a lock file before enabling mutableInputs.
          '';

        # Resolve an input name to its lock file node, following the root
        # input mapping (handles renamed nodes like "nixpkgs_2").
        lockNodeFor = name:
          let
            rootInputs = lockData.nodes.root.inputs or {};
            nodeName = rootInputs.${name} or name;
          in
            if builtins.isString nodeName
            then lockData.nodes.${nodeName} or null
            else null;

        # Derive a flake ref string from the lock file's "original" entry.
        # Used as the argument to `nix flake clone` for initial clones.
        cloneUrlFor = name:
          let
            node = lockNodeFor name;
            original = if node != null then (node.original or null) else null;
          in
            if original != null
            then builtins.flakeRefToString original
            else null;

        # Get the pinned rev from the lock file's "locked" entry.
        pinnedRevFor = name:
          let
            node = lockNodeFor name;
          in
            if node != null then (node.locked.rev or null) else null;

        # The sync script with git/nix paths substituted in.
        syncScript = pkgs.replaceVars ./sync.sh {
          git = "${pkgs.git}/bin/git";
          nix = "${pkgs.nix}/bin/nix";
        };

        # For a given registered input, compute the set of overrides needed
        # for its .mutable/flake.nix. An override is needed when one of the
        # input's resolved dependencies matches (by identity) another
        # registered mutable input.
        #
        # Returns an attrset: { <depName> = <mutableName>; ... }
        # where depName is the name the repo uses for that input internally,
        # and mutableName is the key in our mutable set (= directory name under root).
        overridesFor = name:
          let
            flake = cfg.inputs.${name}.flakeInput;
            flakeInputs = flake.inputs or {};
            mutableNames = lib.attrNames cfg.inputs;
          in
            lib.foldlAttrs (acc: depName: depFlake:
              let
                # Find the mutable input whose identity matches this dep.
                matchingMutable = lib.findFirst
                  (mutableName:
                    mutableName != name &&
                    toString cfg.inputs.${mutableName}.flakeInput == toString depFlake)
                  null
                  mutableNames;
              in
                if matchingMutable != null
                then acc // { ${depName} = matchingMutable; }
                else acc
            ) {} flakeInputs;

        # Generate .mutable/flake.nix content for a given repo.
        # overrides: { <depName> = <mutableName>; ... }
        mutableFlakeContentFor = name: overrides:
          let
            inputDecls = lib.concatMapStringsSep "\n"
              (depName:
                let mutableName = overrides.${depName};
                in "    ${depName}.url = \"git+file://${pathFor mutableName}?ref=${cfg.inputs.${mutableName}.ref}\";")
              (lib.attrNames overrides);
            followsDecls = lib.concatMapStringsSep "\n"
              (depName: "    real.inputs.${depName}.follows = \"${depName}\";")
              (lib.attrNames overrides);
          in ''
# Auto-generated by mutableInputs. Do not edit manually.
# Regenerated on each home-manager activation.
{
  inputs = {
    real.url = "git+file://${pathFor name}?ref=${cfg.inputs.${name}.ref}";
${inputDecls}
${followsDecls}
  };
  outputs = { real, ... }: real.outputs;
}
'';

        # Compute which repos need .mutable/ generation.
        # Result: { <name> = { overrides = {...}; content = "..."; }; ... }
        reposNeedingMutable = lib.filterAttrs (_: v: v.overrides != {})
          (lib.mapAttrs (name: _: let
            overrides = overridesFor name;
          in {
            inherit overrides;
            content = mutableFlakeContentFor name overrides;
          }) cfg.inputs);

        # Given a target prefix (relative to $HOME) and a source directory,
        # returns an attrset of home.file entries — one per child of srcDir —
        # each linked via `link` (mutable when enabled, store path otherwise).
        # This manages individual children without claiming the parent directory,
        # so unmanaged siblings (e.g. externally-managed symlinks) are preserved.
        #
        # Usage:
        #   home.file = config.lib.mutableInputs.linkChildren ".agents/skills" ./skills;
        #
        linkChildren = destPrefix: srcDir:
          lib.mapAttrs'
            (child: _: lib.nameValuePair
              "${destPrefix}/${child}"
              { source = link (srcDir + "/${child}"); })
            (builtins.readDir srcDir);

        # The link function: given a nix path, determines which registered
        # input it belongs to and returns either a mutable symlink or the
        # store path.
        link = path:
          let
            pathStr = toString path;
            # Find which registered input this path belongs to by checking
            # which flakeInput's toString is a prefix of the path.
            matchingInput = lib.findFirst
              (name:
                let inputStr = toString cfg.inputs.${name}.flakeInput;
                in lib.hasPrefix inputStr pathStr)
              null
              (lib.attrNames cfg.inputs);
          in
            if !cfg.enable then path
            else if matchingInput == null then path
            else
              let
                relativePath = lib.removePrefix
                  (toString cfg.inputs.${matchingInput}.flakeInput)
                  pathStr;
              in
                config.lib.file.mkOutOfStoreSymlink
                  "${pathFor matchingInput}${relativePath}";

      in {
        options.local.mutableInputs = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether to enable mutable working copies for dotfile sources.
              When false, all mutableInputs config is inert: link returns
              store paths, no repos are cloned, no .mutable/ is generated.
              Upstream repos can declare optional mutable deps which are
              harmlessly ignored when this is false.
            '';
          };

          root = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Absolute path to the directory containing mutable repo clones.
              Each registered input is expected at <root>/<inputName>/.
              Required when enable = true.
            '';
            example = "/home/user/work";
          };

          rootFlake = lib.mkOption {
            type = lib.types.raw;
            default = inputs.self;
            description = ''
              The top-level (consuming) flake whose flake.lock is read to derive
              clone URLs and pinned revs. Pass your own `self`.

              The default (inputs.self) is only correct when these aspects live
              in the same flake you build. When they are consumed as another
              flake's output, inputs.self is the defining flake and its lock has
              no entry for your inputs, so clone URL derivation silently fails.
            '';
            example = lib.literalExpression "self";
          };

          inputs = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
              options = {
                flakeInput = lib.mkOption {
                  type = lib.types.raw;
                  description = ''
                    The flake input this entry corresponds to. Used for:
                    - link function prefix matching (toString gives store path)
                    - Identity comparison for .mutable/ overlap detection
                    - Clone URL derivation from the top-level flake.lock
                  '';
                };

                path = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Override the working copy path for this input.
                    Defaults to <root>/<name> when null.
                  '';
                  example = "/home/coder/.dotfiles";
                };

                ref = lib.mkOption {
                  type = lib.types.str;
                  default = "main";
                  description = ''
                    Git ref to use in generated git+file:// URLs for .mutable/.
                    Required for jj-colocated repos where HEAD is a detached
                    bare SHA that Nix cannot resolve. Defaults to "main".
                  '';
                  example = "master";
                };
              };
            }));
            default = {};
            description = ''
              Flake inputs to make available as mutable working copies.
              The attrset key is used as the directory name under root
              (unless overridden by path).
            '';
          };
        };

        config = {
          assertions = [
            {
              assertion = cfg.enable -> lib.all
                (name: cfg.inputs.${name}.path != null || cfg.root != "")
                (lib.attrNames cfg.inputs);
              message = let
                unresolved = lib.filter
                  (name: cfg.inputs.${name}.path == null && cfg.root == "")
                  (lib.attrNames cfg.inputs);
              in ''
                mutableInputs: the following inputs have no resolvable path:
                  ${lib.concatStringsSep ", " unresolved}

                Either set local.mutableInputs.root (applies to all inputs) or set
                a per-input path, e.g.:
                  local.mutableInputs.inputs.${lib.head unresolved}.path = "/path/to/clone";
              '';
            }
          ];

          # Expose the link function unconditionally so aspects can call it
          # regardless of whether mutableInputs is enabled on the current host.
          lib.mutableInputs = { inherit link linkChildren; };

          # Clone/sync repos + generate .mutable/flake.nix on activation.
          home.activation.mutableInputsSync = lib.mkIf cfg.enable
            (lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
              (let
                git = "${pkgs.git}/bin/git";

                # Clone/sync commands for each registered input.
                syncCommands = lib.concatStringsSep "\n"
                  (lib.mapAttrsToList (name: _inputCfg:
                    let
                      cloneUrl = cloneUrlFor name;
                      rev = pinnedRevFor name;
                      dest = pathFor name;
                    in
                      if cloneUrl == null then ''
                        # --- ${name}: no clone URL available ---
                        if [ ! -d ${lib.escapeShellArg dest} ]; then
                          echo "mutableInputs: WARNING: ${name} not found at ${dest} and no clone URL derivable from flake.lock. Skipping."
                        fi
                      ''
                      else ''
                        # --- ${name}: sync ---
                        ${pkgs.bash}/bin/bash ${syncScript} ${lib.escapeShellArg dest} ${lib.escapeShellArg cloneUrl} ${lib.optionalString (rev != null) (lib.escapeShellArg rev)}
                      ''
                  ) cfg.inputs);

                # Generate .mutable/ for each repo that has overlapping mutable deps.
                mutableGenCommands = lib.concatStringsSep "\n"
                  (lib.mapAttrsToList (name: { content, ... }:
                    let
                      mutableDir = "${pathFor name}/.mutable";
                    in ''
                      # --- ${name}: generate .mutable/ ---
                      mkdir -p ${lib.escapeShellArg mutableDir}
                      if [ ! -d ${lib.escapeShellArg "${mutableDir}/.git"} ]; then
                        ${git} -C ${lib.escapeShellArg mutableDir} init --quiet 2>/dev/null
                      fi

                      # Gitignore flake.lock so Nix's source-tree filter excludes it
                      # from evaluation. This means Nix never reuses a stale lock —
                      # every eval resolves ?ref=main to current HEAD. Nix still
                      # writes a lock to disk as a side effect, but it's harmless
                      # (ignored on next read, invisible to git).
                      if ! grep -qxF 'flake.lock' ${lib.escapeShellArg "${mutableDir}/.gitignore"} 2>/dev/null; then
                        echo 'flake.lock' >> ${lib.escapeShellArg "${mutableDir}/.gitignore"}
                      fi

                      cat > ${lib.escapeShellArg "${mutableDir}/flake.nix"} << 'MUTABLE_FLAKE_EOF'
${content}
MUTABLE_FLAKE_EOF

                      ${git} -C ${lib.escapeShellArg mutableDir} add flake.nix .gitignore
                      # Untrack flake.lock if previously committed (one-time migration).
                      ${git} -C ${lib.escapeShellArg mutableDir} rm --cached flake.lock 2>/dev/null || true
                      ${git} -C ${lib.escapeShellArg mutableDir} diff --cached --quiet 2>/dev/null \
                        || ${git} -C ${lib.escapeShellArg mutableDir} commit -m "mutableInputs: update overrides" --quiet 2>/dev/null || true
                    ''
                  ) reposNeedingMutable);

                # Remove stale .mutable/ from repos that no longer have overlapping deps.
                staleRepos = lib.filterAttrs (name: _: !(reposNeedingMutable ? ${name})) cfg.inputs;
                cleanupCommands = lib.concatStringsSep "\n"
                  (lib.mapAttrsToList (name: _:
                    let mutableDir = "${pathFor name}/.mutable";
                    in ''
                      if [ -d ${lib.escapeShellArg mutableDir} ]; then
                        echo "mutableInputs: removing stale .mutable/ from ${name}"
                        rm -rf ${lib.escapeShellArg mutableDir}
                      fi
                    ''
                  ) staleRepos);
              in
                syncCommands + "\n" + mutableGenCommands + "\n" + cleanupCommands));
        };
      };
    };
  };
}
