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
        ;; Today only — no rolling week
        org-agenda-span 'day
        org-agenda-start-day nil
        org-agenda-todo-ignore-scheduled 'future
        org-agenda-skip-deadline-prewarning-if-scheduled 'pre-scheduled
        ;; Disable built-in dependency enforcement — our skip functions handle it
        org-enforce-todo-dependencies nil
        org-agenda-dim-blocked-tasks nil
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
                   (org-agenda-skip-function 'jw/skip-non-actionable)))
            (todo "BLOCKED"
                  ((org-agenda-overriding-header "Waiting on...")
                   (org-agenda-skip-function 'jw/skip-non-blocked)))))
          ("t" "Actionable TODOs" todo "TODO|ACTIVE"
           ((org-agenda-skip-function 'jw/skip-non-actionable)))
          ("T" "All TODOs (full tree)" todo "TODO|ACTIVE|BLOCKED"))))

;; ── actionable goals ─────────────────────────────────────────────────
;;
;; Mental model:
;;   - ACTIVE defines a "scope" — each scope surfaces at most 1 TODO in
;;     the agenda ("Actionable next steps").
;;   - A nested ACTIVE with incomplete children carves out its own scope.
;;   - A nested ACTIVE with all-DONE (or no) children is a leaf and can
;;     be the parent scope's actionable item.
;;   - BLOCKED encountered as the first reachable item blocks the scope
;;     (0 actionable items).  BLOCKED items appear in "Waiting on..."
;;   - "First leaf TODO" = depth-first walk, first TODO with no
;;     incomplete children, skipping sub-ACTIVE subtrees.

(defun jw/has-active-ancestor-p ()
  "Return non-nil if current heading or any ancestor has ACTIVE state."
  (save-restriction
    (widen)
    (or (string= (org-get-todo-state) "ACTIVE")
        (save-excursion
          (while (and (org-up-heading-safe)
                      (not (string= (org-get-todo-state) "ACTIVE"))))
          (string= (org-get-todo-state) "ACTIVE")))))

(defun jw/nearest-active-ancestor-pos ()
  "Return the buffer position of the nearest ACTIVE ancestor, or nil.
If the current heading is ACTIVE, returns its own position."
  (save-restriction
    (widen)
    (save-excursion
      (cond
       ((string= (org-get-todo-state) "ACTIVE")
        (point))
       (t
        (while (and (org-up-heading-safe)
                    (not (string= (org-get-todo-state) "ACTIVE"))))
        (when (string= (org-get-todo-state) "ACTIVE")
          (point)))))))

(defun jw/heading-has-incomplete-children-p ()
  "Non-nil if heading at point has any child with a non-done TODO state.
Sub-ACTIVE children with incomplete children are ignored (own scope)."
  (let ((has-incomplete nil))
    (save-excursion
      (when (org-goto-first-child)
        (catch 'done
          (while t
            (let ((state (org-get-todo-state)))
              (cond
               ;; ACTIVE child with incomplete children = own scope, skip it
               ((and (string= state "ACTIVE")
                     (jw/heading-has-incomplete-children-p))
                nil)
               ;; Any non-done TODO state = incomplete child
               ((and state (not (member state '("DONE" "CANCELLED"))))
                (setq has-incomplete t)
                (throw 'done t))))
            (unless (org-get-next-sibling)
              (throw 'done nil))))))
    has-incomplete))

(defun jw/scope-first-actionable (scope-pos)
  "Return the buffer position of the first actionable leaf TODO within
the ACTIVE scope rooted at SCOPE-POS, or nil if blocked/empty.

A leaf is a TODO heading with no incomplete children (ignoring sub-ACTIVE
subtrees that have their own scope).  Walks depth-first in document order.
Returns nil if the scope is fully done or blocked.
Returns the symbol `blocked' if a BLOCKED item was encountered first."
  (save-restriction
    (widen)
    (save-excursion
      (goto-char scope-pos)
      (jw/--walk-children-for-actionable))))

(defun jw/--walk-children-for-actionable ()
  "Walk immediate children of heading at point, returning the first
actionable leaf position, `blocked', or nil."
  (save-excursion
    (when (org-goto-first-child)
      (catch 'result
        (while t
          (let ((state (org-get-todo-state)))
            (cond
             ;; Done/cancelled — skip
             ((member state '("DONE" "CANCELLED" nil))
              nil)
             ;; Blocked — scope is stuck
             ((string= state "BLOCKED")
              (throw 'result 'blocked))
             ;; ACTIVE child — check if it's a leaf (all children done)
             ;; If so, it's actionable for the parent scope.
             ;; If it has incomplete children, it's its own scope — skip.
             ((string= state "ACTIVE")
              (unless (jw/heading-has-incomplete-children-p)
                (throw 'result (point))))
             ;; TODO — either descend (has incomplete children) or it's a leaf
             ((string= state "TODO")
              (if (jw/heading-has-incomplete-children-p)
                  ;; Descend into this branch
                  (let ((result (jw/--walk-children-for-actionable)))
                    (cond
                     ((eq result 'blocked) (throw 'result 'blocked))
                     (result (throw 'result result))
                     ;; nil = branch exhausted, continue to next sibling
                     (t nil)))
                ;; Leaf TODO — this is our winner
                (throw 'result (point))))))
          (unless (org-get-next-sibling)
            (throw 'result nil)))))))

(defun jw/skip-non-actionable ()
  "Skip entries that are not THE chosen actionable leaf for their
nearest ACTIVE scope.  Each ACTIVE scope contributes at most one
entry to the agenda."
  (save-restriction
    (widen)
    (let ((scope-pos (jw/nearest-active-ancestor-pos)))
      (cond
       ;; Not under any ACTIVE scope — skip entire subtree
       ((not scope-pos)
        (save-excursion (org-end-of-subtree t)))
       ;; This entry IS an ACTIVE scope-definer (has incomplete children) —
       ;; skip just this heading, let agenda visit children
       ((and (= (point) scope-pos)
             (jw/heading-has-incomplete-children-p))
        (save-excursion (outline-next-heading) (point)))
       ;; Under an ACTIVE scope — check if we're the chosen one
       (t
        (let ((actionable (jw/scope-first-actionable scope-pos)))
          (unless (and actionable
                       (not (eq actionable 'blocked))
                       (= (point) actionable))
            (save-excursion (org-end-of-subtree t)))))))))

(defun jw/skip-non-blocked ()
  "Skip entries that are not BLOCKED under an ACTIVE scope.
All BLOCKED items under any ACTIVE ancestor are shown."
  (save-restriction
    (widen)
    (unless (and (string= (org-get-todo-state) "BLOCKED")
                 (jw/has-active-ancestor-p))
      (save-excursion (org-end-of-subtree t)))))

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

;; ── org-capture & refile ──────────────────────────────────────────────

(load! "capture")

;; ── org-roam outgoing links section ──────────────────────────────────

(load! "org-roam-links-section")

;; ── org-wiki ─────────────────────────────────────────────────────────

(load! "org-wiki-publish")
