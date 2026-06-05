;;; programs/emacs/doom.d/modules/org/capture.el -*- lexical-binding: t; -*-
;;;
;;; SPC X capture prefix (which-key), flat single-file journal capture,
;;; bookmark→ref/external, refile, and slug-based ID generation.
;;;
;;; Design: ~/org/journal.org is one flat file — one top-level heading per
;;; day (newest-first), entries as level-2 subheadings.  Each day heading
;;; carries :ID: journal:YYYY-MM-DD (org-roam heading node).  Capture files
;;; new entries under today's heading via a custom locator; if today doesn't
;;; exist yet, it's created at the top of the file.  Completed tasks stay
;;; in-place with a CLOSED: timestamp (org-log-done).  The agenda surfaces
;;; open TODOs across journal.org + all other org files.

;; ── slug-based ID generation ─────────────────────────────────────────
;;
;; Convention: IDs are <category>:<hyphen-slug> (e.g. "ref:my-tool",
;; "ext:tool-admin-console", "journal:2026-06-03").  Slugs are derived
;; from titles, lowercased, hyphenated, de-duped against the org-roam
;; DB.  The org-id-locations cache is updated automatically by
;; org-roam's capture finalization.

(defun jw/slugify (title)
  "Slugify TITLE using org-roam's unicode-aware slugifier, but with
hyphens instead of underscores (matching our existing node conventions)."
  (replace-regexp-in-string
   "_" "-"
   (org-roam-node-slugify title)))

(defun jw/slug-id-exists-p (id)
  "Return non-nil if ID already exists in the org-roam DB or org-id-locations."
  (or (org-roam-db-query [:select id :from nodes :where (= id $s1)] id)
      (org-id-find id 'marker)))

(defun jw/roam-slug-id (category title)
  "Generate a non-colliding slug ID in the form CATEGORY:slug-from-TITLE.
Appends -2, -3, ... on collision."
  (let* ((base-slug (jw/slugify title))
         (candidate (format "%s:%s" category base-slug))
         (n 2))
    (while (jw/slug-id-exists-p candidate)
      (setq candidate (format "%s:%s-%d" category base-slug n))
      (setq n (1+ n)))
    candidate))

;; ── journal capture (flat single-file, newest-first) ─────────────────
;;
;; ~/org/journal.org structure:
;;   * 2026-06-05 Friday        ← newest day at top
;;   :PROPERTIES:
;;   :ID: journal:2026-06-05
;;   :END:
;;   ** TODO Some task           ← entries as level-2
;;   ** 14:37 Something happened
;;   * 2026-06-04 Thursday      ← older days below
;;   ...
;;
;; Capture locator: find today's * YYYY-MM-DD heading by :ID:; if absent,
;; create it at the top (after #+title preamble).  :prepend puts newest
;; entries first within the day.

(defvar jw/journal-file (expand-file-name "journal.org" org-directory)
  "Path to the single flat journal file.")

(defun jw/journal-today-location ()
  "Position point in `jw/journal-file' under today's day heading.
Creates the heading at the top of the file (newest-first) with
:ID: journal:YYYY-MM-DD if it doesn't exist yet."
  (let* ((today (format-time-string "%Y-%m-%d"))
         (id (concat "journal:" today))
         (title (format-time-string "%Y-%m-%d %A")))
    (set-buffer (org-capture-target-buffer jw/journal-file))
    (widen)
    ;; Try to find today's heading by its :ID: property.
    (goto-char (point-min))
    (unless (org-find-property "ID" id)
      ;; Today doesn't exist yet — insert at the top, after any preamble
      ;; (#+title, blank lines before first heading).
      (goto-char (point-min))
      (if (re-search-forward "^\\*" nil t)
          (goto-char (match-beginning 0))
        (goto-char (point-max))
        (unless (bolp) (insert "\n")))
      (insert (format "* %s\n:PROPERTIES:\n:ID: %s\n:END:\n" title id))
      ;; Register the new ID so links resolve immediately.
      (org-id-add-location id (buffer-file-name)))
    ;; Now position inside today's heading for entry insertion.
    (goto-char (point-min))
    (org-find-property "ID" id)
    (goto-char (org-find-property "ID" id))
    (org-end-of-meta-data t)))

(after! org
  (setq org-capture-templates
        (append org-capture-templates
                `(("j" "Journal entry" entry
                   (function jw/journal-today-location)
                   "* %<%H:%M> %?\n"
                   :prepend t :empty-lines-before 1)
                  ("t" "TODO → journal" entry
                   (function jw/journal-today-location)
                   "* TODO %?\n"
                   :prepend t :empty-lines-before 1)
                  ("n" "Note → journal" entry
                   (function jw/journal-today-location)
                   "* %?\n"
                   :prepend t :empty-lines-before 1)))))

(after! org-roam
  ;; --- roam capture templates (for org-roam-node-find / org-roam-capture) ---
  ;;
  ;; "d" = default (SPC n n style, creating a generic roam note).
  ;;       UUID ID — for rare one-off notes; most notes are created as files.
  ;;
  ;; "b" = bookmark (external ref annotation node).
  ;;       Invoked programmatically via jw/org-roam-capture-bookmark.
  ;;       ID: ext:<slug>, :ROAM_REFS: <url>, feeds Annotated Links section.
  (setq org-roam-capture-templates
        `(("d" "default" plain "%?"
           :target (file+head "${slug}.org"
                              "#+title: ${title}\n")
           :unnarrowed t)
          ("b" "bookmark (external ref)" plain
           "%?"
           :target (file+head
                    ,(concat "ref/external/${slug}.org")
                    ,(concat ":PROPERTIES:\n"
                             ":ID: ext:${slug}\n"
                             ":ROAM_REFS: ${ref}\n"
                             ":END:\n"
                             "#+title: ${title} (annotations)\n"
                             "#+filetags: :external:annotations:\n"))
           :unnarrowed t))))

;; ── bookmark capture command ─────────────────────────────────────────

(defun jw/org-roam-capture-bookmark ()
  "Capture a bookmark/external-ref as an org-roam node in ref/external/."
  (interactive)
  (let* ((url (read-string "URL: "))
         (title (read-string "Title: "))
         (slug (jw/slugify title)))
    (org-roam-capture-
     :keys "b"
     :node (org-roam-node-create :title title)
     :info (list :ref url :slug slug)
     :templates org-roam-capture-templates)))

;; ── capture prefix map (SPC X) ───────────────────────────────────────
;;
;; Replaces Doom's default `SPC X` (org-capture) with a prefix map.
;; which-key shows descriptions automatically when SPC X is held.
;;   j → journal entry (freeform, timestamped)
;;   t → TODO task (into today's journal)
;;   n → note (into today's journal)
;;   b → bookmark (→ ref/external/)

(map! :leader
      (:prefix-map ("X" . "capture")
       :desc "Journal entry"  "j" (cmd! (org-capture nil "j"))
       :desc "TODO → journal" "t" (cmd! (org-capture nil "t"))
       :desc "Note → journal" "n" (cmd! (org-capture nil "n"))
       :desc "Bookmark → ref" "b" #'jw/org-roam-capture-bookmark))

;; ── org-refile ───────────────────────────────────────────────────────
;;
;; Refile = "move a heading from one file/location to another".
;; Use case: move a task from the journal into a goal tree when it
;; needs to live somewhere more permanent.
;;
;; Targets: any heading up to depth 3 in any agenda file.
;; Completion shows full outline path (file/h1/h2/h3) for precision.

(after! org
  (setq org-refile-targets '((org-agenda-files :maxlevel . 3))
        org-refile-use-outline-path 'file
        org-outline-path-complete-in-steps nil
        org-refile-allow-creating-parent-nodes 'confirm))

;; ── rebuild ID cache ─────────────────────────────────────────────────
;;
;; One-shot command to populate ~/org/.orgids from all org-roam nodes.
;; Fixes the case where LLM/memex-generated slug IDs were never added
;; to the org-id-locations cache.  Run once after initial setup, or
;; whenever you notice id: links failing to resolve.

(defun jw/org-roam-rebuild-id-cache ()
  "Walk all org-roam nodes and ensure their IDs are in `org-id-locations'."
  (interactive)
  (let ((nodes (org-roam-db-query [:select [id file] :from nodes])))
    (dolist (row nodes)
      (let ((id (car row))
            (file (cadr row)))
        (when (and id file (file-exists-p file))
          (org-id-add-location id file))))
    (org-id-locations-save)
    (message "Rebuilt org-id-locations: %d nodes cached." (length nodes))))

;;; capture.el ends here
