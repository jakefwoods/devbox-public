;;; programs/emacs/doom.d/modules/org/init.el -*- lexical-binding: t; -*-

;; ── org-agenda ───────────────────────────────────────────────────────

(after! org
  (setq org-agenda-files '("~/org/events/" "~/org/journal/")
        ;; Use Doom's defaults for span/start (week view, -3d)
        ;; SPC o a a shows rolling week with 3 days context behind
        org-agenda-todo-ignore-scheduled 'future
        org-agenda-skip-deadline-prewarning-if-scheduled 'pre-scheduled
        ;; Cleaner prefix: just time, no category/filename
        org-agenda-prefix-format '((agenda . "  %t ") (todo . " %i ") (tags . " %i ") (search . " %i "))
        ;; Include org-journal formatted files in the agenda
        org-agenda-file-regexp "\\`\\([^.].*\\.org\\|[0-9]\\{8\\}\\(\\.gpg\\)?\\)\\'"))

;; Silently revert org buffers before building agenda (external tools write files)
(defun jw/revert-org-buffers ()
  "Revert all unmodified Org buffers from disk without prompting."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and (derived-mode-p 'org-mode)
                 (buffer-file-name)
                 (not (buffer-modified-p))
                 (file-exists-p (buffer-file-name)))
        (revert-buffer t t t)))))

(advice-add 'org-agenda :before
            (lambda (&rest _)
              (jw/revert-org-buffers)))

;; Disable org-lint flycheck checker (noisy on machine-generated files)
(after! flycheck
  (setq-default flycheck-disabled-checkers '(org-lint)))

;; ── org-roam ─────────────────────────────────────────────────────────

(after! org-roam
  (setq org-roam-directory "~/org/"
        org-roam-dailies-directory "journal/"))

;; ── org-journal ──────────────────────────────────────────────────────

(after! org-journal
  (setq org-journal-dir "~/org/journal/"
        org-journal-file-type 'daily
        org-journal-file-format "%Y%m%d.org"
        org-journal-carryover-items ""))
