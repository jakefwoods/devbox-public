;;; programs/emacs/doom.d/modules/org/init.el -*- lexical-binding: t; -*-

;; ── org-modern ───────────────────────────────────────────────────────

;; Doom's +pretty already loads org-modern. Override fold-stars to avoid
;; U+2BC6/U+2BC8 (level 3) which many fonts lack glyphs for.
(after! org-modern
  (setq org-modern-fold-stars
        '(("▶" . "▼") ("▷" . "▽") ("▸" . "▾") ("▹" . "▿") ("►" . "▾"))))

;; ── org-agenda ───────────────────────────────────────────────────────

(after! org
  (setq org-agenda-files (directory-files-recursively "~/org/" "\\.org$")
        ;; Use Doom's defaults for span/start (week view, -3d)
        ;; SPC o a a shows rolling week with 3 days context behind
        org-agenda-todo-ignore-scheduled 'future
        org-agenda-skip-deadline-prewarning-if-scheduled 'pre-scheduled
        ;; Cleaner prefix: just time, no category/filename
        org-agenda-prefix-format '((agenda . "  %t ") (todo . " %i ") (tags . " %i ") (search . " %i "))
        ;; Include org-journal formatted files in the agenda
        org-agenda-file-regexp "\\`\\([^.].*\\.org\\|[0-9]\\{8\\}\\(\\.gpg\\)?\\)\\'"
        ;; TODO keywords for goal tracking
        org-todo-keywords '((sequence "TODO" "ACTIVE" "BLOCKED" "|" "DONE" "CANCELLED"))
        ;; Custom agenda views
        org-agenda-custom-commands
        '(("A" "Active goals (scope overview)" todo "ACTIVE")
          ("a" "Agenda + actionable"
           ((agenda "" nil)
            (todo "TODO|ACTIVE"
                  ((org-agenda-overriding-header "Actionable next steps")
                   (org-agenda-skip-function 'jw/skip-non-actionable)))))
          ("t" "Actionable TODOs" todo "TODO|ACTIVE"
           ((org-agenda-skip-function 'jw/skip-non-actionable)))
          ("T" "All TODOs (full tree)" todo "TODO|ACTIVE|BLOCKED"))))

;; ── actionable goals ─────────────────────────────────────────────────

(defun jw/has-active-ancestor-p ()
  "Return non-nil if current heading or any ancestor has ACTIVE state."
  (or (string= (org-get-todo-state) "ACTIVE")
      (save-excursion
        (while (and (org-up-heading-safe)
                    (not (string= (org-get-todo-state) "ACTIVE"))))
        (string= (org-get-todo-state) "ACTIVE"))))

(defun jw/skip-non-actionable ()
  "Skip entries that aren't actionable.
An entry is actionable if:
  1. It has no incomplete TODO/ACTIVE/BLOCKED children (leaf or all-done parent)
  2. It has at least one ACTIVE ancestor (or is itself ACTIVE)"
  (let ((subtree-end (save-excursion (org-end-of-subtree t))))
    (cond
     ;; Has undone children → blocked by subtasks, skip
     ((save-excursion
        (forward-line 1)
        (re-search-forward org-not-done-heading-regexp subtree-end t))
      subtree-end)
     ;; No ACTIVE ancestor (and not itself ACTIVE) → not on frontier, skip
     ((not (jw/has-active-ancestor-p))
      subtree-end)
     ;; Actionable
     (t nil))))

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
        org-roam-dailies-directory "journal/"
        org-roam-completion-everywhere t))

;; ── org-journal ──────────────────────────────────────────────────────

(after! org-journal
  (setq org-journal-dir "~/org/journal/"
        org-journal-file-type 'daily
        org-journal-file-format "%Y%m%d.org"
        org-journal-carryover-items ""))

;; ── org-wiki ─────────────────────────────────────────────────────────

(load! "org-wiki-publish")
