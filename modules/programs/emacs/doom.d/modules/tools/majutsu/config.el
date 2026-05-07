;;; tools/majutsu/config.el -*- lexical-binding: t; -*-

;;; See: https://github.com/0WD0/doom/blob/main/modules/tools/majutsu

;; Declare autoloaded commands via use-package! for lazy loading
(use-package! majutsu
  :commands (majutsu majutsu-log
                     majutsu-rebase-transient majutsu-bookmark-transient majutsu-git-transient
                     majutsu-commit majutsu-describe majutsu-diff majutsu-diffedit-emacs majutsu-diffedit-smerge
                     majutsu-log-refresh majutsu-dispatch majutsu-squash-transient
                     majutsu-abandon majutsu-undo majutsu-new majutsu-enter-dwim majutsu-log-goto-@))

;; Keybindings: `SPC j` prefix (evil leader)
(when (modulep! :editor evil)
  (map! :leader
        (:prefix ("j" . "Majutsu")
         :desc "Majutsu log"       "j" #'majutsu
         ;; :desc "Rebase menu"       "r" #'majutsu-rebase-transient
         ;; :desc "Bookmark menu"     "b" #'majutsu-bookmark-transient
         ;; :desc "Git menu"          "g" #'majutsu-git-transient
         :desc "Commit"            "c" #'majutsu-commit
         :desc "Describe"          "d" #'majutsu-describe
         :desc "Diff"              "D" #'majutsu-diff)))
