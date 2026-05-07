;;; programs/emacs/doom.d/modules/org/init.el -*- lexical-binding: t; -*-

;; (load! "org-notes")

;; (defun +org-notes-include-in-agenda (&rest _)
;;   "Update `org-agenda-file` to include agenda notes"
;;   (setq org-agenda-files (append (list (concat org-directory "journal"))
;;                                  (+org-notes-agenda-files))))

;; (advice-add 'org-agenda :before #'+org-notes-include-in-agenda)

;; ;; Include org-journal formatted files in the agenda
;; (setq org-agenda-file-regexp "\\`\\\([^.].*\\.org\\\|[0-9]\\\{8\\\}\\\(\\.gpg\\\)?\\\)\\'"
;;       org-agenda-span 'day
;;       org-agenda-todo-ignore-scheduled 'future
;;       org-agenda-skip-deadline-prewarning-if-scheduled 'pre-scheduled)

;; (setq org-agenda-custom-commands
;;       '(("d" "Daily Agenda"
;;         ((agenda "")
;;          (todo "PROG")
;;          (todo "NEXT")
;;          (todo "WAIT")))))

;; (setq org-todo-keywords
;;       '((sequence "TODO(t)" ; A task that needs doing. These are not started, and not planned.
;;                   "NEXT(n)" ; A task that is ready to go and should be done next
;;                   "PROG(p)" ; A task that is in progress
;;                   "WAIT(w)" ; Something external is holding up this task
;;                   "|"
;;                   "DONE(d)"   ; Task successfully completed
;;                   "KILL(k)")) ; Task was cancelled, aborted or is no longer applicable
;;       org-todo-keyword-faces
;;       '(("PROG" . +org-todo-active)
;;         ("WAIT" . +org-todo-onhold)))

;; (setq org-journal-carryover-items ""    ; Don't carry-over journal entries
;;       org-journal-file-header "#+category: journal")
