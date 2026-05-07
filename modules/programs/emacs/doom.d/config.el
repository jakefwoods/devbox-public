;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Jake Woods")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))

;; Make all the fonts bigger by default
(setq doom-font (font-spec :family "Source Code Pro" :size 16 :weight 'normal)
      doom-variable-pitch-font (font-spec :family "ETBembo" :size 20 :weight 'normal))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; (setq doom-theme 'leuven)
(setq doom-theme 'doom-one)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Local variables are nice sometimes
(setq-default enable-local-variables t)

;; Spacemacs bindings, they're not all bad!
(map! :leader
      :desc "Run command" "SPC" #'counsel-M-x
      "w/" #'evil-window-vsplit)

(defun personal/find-nix-binary (package-name binary-path)
  "Find the `binary-path` binary inside the nixpkg `package-name` using the local <nixpkgs> definition

   Assumes that nix-build is on the path and that <nixpkgs> exists under the
   NIX_PATH environment variable"
  (interactive "sPackage name: \nsBinary Path: ")
  (print
   (concat
    (string-trim
     (shell-command-to-string
      (concat "nix-build '<nixpkgs>' --quiet --attr " package-name " --no-out-link")))
    binary-path)))

(setq
  lsp-signature-render-documentation nil
  lsp-ui-doc-enable nil
  lsp-ui-sideline-show-code-actions nil
  lsp-ui-sideline-show-hover nil
  lsp-ui-sideline-show-symbol nil)

(setq projectile-files-cache-expire 5)

(use-package! treemacs
  :config
  (setq treemacs-collapse-dirs 5
        doom-themes-treemacs-enable-variable-pitch nil))

;; WORKAROUND: Prevent lsp-treemacs from misaligning treemacs icons
;;
;; This forces treemacs to use the doom icons, not `all-the-icons` provided
;; by lsp. We can't use the lsp icons because they don't align properly and look
;; terrible.
;;
;; Reference: https://github.com/emacs-lsp/lsp-treemacs/issues/89
(after! lsp-treemacs
  (load-library "doom-themes-ext-treemacs"))

(use-package! plantuml-mode
  :config
  (setq plantuml-jar-path (expand-file-name "~/.nix-profile/lib/plantuml.jar")))

(use-package! typespec-ts-mode
  :mode "\\.tsp\\'"
  :hook (typespec-ts-mode . lsp-deferred))

(load! "modules/org/init")
(load! "modules/scala")
(load! "modules/csharp")
