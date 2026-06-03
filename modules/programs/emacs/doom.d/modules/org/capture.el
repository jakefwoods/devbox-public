;;; programs/emacs/doom.d/modules/org/capture.el -*- lexical-binding: t; -*-
;;;
;;; SPC X capture prefix (which-key), org-roam-dailies journal-as-inbox,
;;; bookmark→ref/external, refile, and slug-based ID generation.
;;;
;;; Design: today's journal page is the universal capture target.  TODOs,
;;; notes, and freeform journal entries all land in the same daily file.
;;; Completed tasks stay in-place with a CLOSED: timestamp (org-log-done).
;;; The agenda surfaces open TODOs across all daily files.

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

;; ── org-roam-dailies (journal as inbox) ──────────────────────────────
;;
;; Daily journal pages as first-class roam nodes.
;; File: ~/org/journal/YYYY-MM-DD.org
;; ID: journal:YYYY-MM-DD (deterministic — one per day, no collision risk)
;;
;; The :ID: is baked into the file+head template so that org-roam reads
;; it from the property drawer on file creation (no UUID ever generated).
;;
;; Three capture templates share the same daily file:
;;   "j" = freeform journal entry (timestamped)
;;   "t" = TODO task (surfaces in agenda)
;;   "n" = plain note

(after! org-roam
  (let ((daily-head (concat ":PROPERTIES:\n"
                            ":ID: journal:%<%Y-%m-%d>\n"
                            ":END:\n"
                            "#+title: %<%Y-%m-%d %A>\n")))
    (setq org-roam-dailies-capture-templates
          `(("j" "journal" entry
             "* %<%H:%M> %?\n"
             :target (file+head "%<%Y-%m-%d>.org" ,daily-head)
             :unnarrowed t
             :empty-lines-before 1)
            ("t" "TODO" entry
             "* TODO %?\n"
             :target (file+head "%<%Y-%m-%d>.org" ,daily-head)
             :unnarrowed t
             :empty-lines-before 1)
            ("n" "note" entry
             "* %?\n"
             :target (file+head "%<%Y-%m-%d>.org" ,daily-head)
             :unnarrowed t
             :empty-lines-before 1))))

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
       :desc "Journal entry"  "j" (cmd! (org-roam-dailies-capture-today nil "j"))
       :desc "TODO → journal" "t" (cmd! (org-roam-dailies-capture-today nil "t"))
       :desc "Note → journal" "n" (cmd! (org-roam-dailies-capture-today nil "n"))
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
