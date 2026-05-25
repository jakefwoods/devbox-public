;;; modules/org/org-wiki-publish.el -*- lexical-binding: t; -*-
;;;
;;; Publish ~/org/ as a local HTML wiki with org-roam link resolution.
;;; Usage: M-x org-wiki-publish!
;;;
;;; Requires: ~/org/.gitignore to contain:
;;;   .wiki-html/
;;;   index.org

(require 'ox-html)
(require 'ox-publish)

;; ── Configuration ────────────────────────────────────────────────────

(defvar org-wiki-source-dir (expand-file-name "~/org/")
  "Root directory of org-roam source files.")

(defvar org-wiki-publish-dir (expand-file-name "~/org/.wiki-html/")
  "Output directory for published HTML.")

(defvar org-wiki-static-dir
  (expand-file-name "org-wiki-static/" doom-user-dir)
  "Directory containing static assets (CSS, fonts).")

(defvar org-wiki-index-file "index.org"
  "Filename for the generated wiki index (relative to source dir).")

;; Exclude the generated index from org-roam's DB
(after! org-roam
  (setq org-roam-file-exclude-regexp
        (rx (or "index.org" ".wiki-html"))))

;; ── Path Helpers (for file:/// compatibility) ────────────────────────

(defun org-wiki--relative-root (file)
  "Compute the relative path from FILE to the wiki source root.
Returns e.g. \"../..\" for a file two directories deep."
  (let* ((rel (file-relative-name file org-wiki-source-dir))
         (dir (file-name-directory rel)))
    (if (or (null dir) (string= dir "./") (string= dir ""))
        "."
      (directory-file-name (file-relative-name "." dir)))))

;; ── ID Link Resolver ─────────────────────────────────────────────────

(defvar org-wiki--id-map nil
  "Hash-table mapping org-roam node IDs to (file . level) cons cells.")

(defun org-wiki--build-id-map ()
  "Build a hash-table of id → (file . level) from org-roam DB."
  (require 'org-roam)
  (let ((map (make-hash-table :test #'equal)))
    (dolist (row (org-roam-db-query
                  [:select [id file level] :from nodes]))
      (puthash (nth 0 row)
               (cons (nth 1 row) (nth 2 row))
               map))
    (setq org-wiki--id-map map)))

(defun org-wiki--file-to-html-path (file)
  "Convert an absolute org FILE path to a relative HTML path."
  (concat (file-name-sans-extension
           (file-relative-name file org-wiki-source-dir))
          ".html"))

(defun org-wiki--resolve-id-link (original-fn link desc info)
  "Advice around `org-html-link' to resolve org-roam id: links.
Falls back to ORIGINAL-FN for non-id links."
  (let ((type (org-element-property :type link))
        (path (org-element-property :path link)))
    (if (and (string= type "id") org-wiki--id-map)
        (let ((entry (gethash path org-wiki--id-map)))
          (if entry
              (let* ((file (car entry))
                     (level (cdr entry))
                     (html-path (org-wiki--file-to-html-path file))
                     ;; For heading-level nodes, append #ID-uuid anchor
                     (href (if (> level 0)
                               (concat html-path "#ID-" path)
                             html-path))
                     ;; Compute relative path from current file being exported
                     (current-file (plist-get info :input-file))
                     (current-dir (file-name-directory
                                   (org-wiki--file-to-html-path current-file)))
                     (relative-href (file-relative-name href current-dir))
                     (label (or desc path)))
                (format "<a href=\"%s\">%s</a>" relative-href label))
            ;; ID not found in roam DB — render as plain text
            (format "<span class=\"broken-link\">%s</span>" (or desc path))))
      ;; Not an id: link — use default handler
      (funcall original-fn link desc info))))

;; ── Custom Publishing Function ───────────────────────────────────────

(defun org-wiki--publish-to-html (plist filename pub-dir)
  "Publish an org file to HTML with correct relative paths for assets.
Wraps `org-html-publish-to-html', dynamically setting :html-head
to use relative paths so file:/// browsing works from subdirectories."
  (let* ((root-rel (org-wiki--relative-root filename))
         (css-path (concat root-rel "/style.css"))
         (index-path (concat root-rel "/index.html"))
         (head (format "<link rel=\"stylesheet\" href=\"%s\">" css-path))
         (preamble (format "<nav><a href=\"%s\">&larr; Index</a></nav>" index-path)))
    (org-html-publish-to-html
     (plist-put (plist-put plist :html-head head)
                :html-preamble preamble)
     filename pub-dir)))

;; ── Index Generator ──────────────────────────────────────────────────

(defun org-wiki--extract-title (file)
  "Extract #+TITLE from an org FILE, or nil if none."
  (with-temp-buffer
    (insert-file-contents file nil 0 1024) ; only read first 1KB
    (goto-char (point-min))
    (when (re-search-forward "^#\\+[Tt][Ii][Tt][Ll][Ee]:\\s-*\\(.+\\)" nil t)
      (string-trim (match-string 1)))))

(defun org-wiki--scan-files-for-index ()
  "Scan org files in source dir for titles. Returns alist of (title . file)."
  (let ((files (directory-files-recursively org-wiki-source-dir "\\.org$"))
        (entries nil))
    (dolist (file files)
      ;; Skip the index file itself and hidden dirs
      (unless (or (string= (file-name-nondirectory file) org-wiki-index-file)
                  (string-match-p "/\\." (file-relative-name file org-wiki-source-dir)))
        (let ((title (org-wiki--extract-title file)))
          (when title
            (push (cons title file) entries)))))
    (sort entries (lambda (a b) (string< (car a) (car b))))))

(defun org-wiki--generate-index ()
  "Generate index.org listing all wiki pages.
Uses org-roam DB if populated, otherwise falls back to scanning
files for #+TITLE headers."
  (require 'org-roam)
  (let ((roam-nodes (org-roam-db-query
                     [:select [id title file]
                      :from nodes
                      :where (= level 0)
                      :order-by (asc title)]))
        (index-path (expand-file-name org-wiki-index-file org-wiki-source-dir)))
    (with-temp-file index-path
      (insert "#+TITLE: Index\n")
      (insert "#+OPTIONS: toc:nil num:nil\n\n")
      (insert "* All Notes\n\n")
      (if roam-nodes
          ;; Org-roam is populated — use id: links
          (dolist (node roam-nodes)
            (let ((id (nth 0 node))
                  (title (nth 1 node)))
              (when title
                (insert (format "- [[id:%s][%s]]\n" id title)))))
        ;; Fallback: scan files for #+title, use file: links
        (let ((entries (org-wiki--scan-files-for-index)))
          (dolist (entry entries)
            (let ((title (car entry))
                  (file (cdr entry)))
              (insert (format "- [[file:%s][%s]]\n" file title)))))))))

;; ── Publish Project Definition ───────────────────────────────────────

(after! ox-publish
  (setq org-publish-project-alist
        (append
         org-publish-project-alist
         `(("org-wiki-pages"
            :base-directory ,org-wiki-source-dir
            :base-extension "org"
            :publishing-directory ,org-wiki-publish-dir
            :publishing-function org-wiki--publish-to-html
            :recursive t

            ;; HTML output settings
            :html-doctype "html5"
            :html-html5-fancy t
            :html-head-include-default-style nil
            :html-head-include-scripts nil
            :html-postamble "<footer><hr><p class=\"postamble\">Published with org-wiki</p></footer>"

            ;; Content settings
            :with-toc nil
            :section-numbers nil
            :with-author nil
            :with-date t)

           ("org-wiki-static"
            :base-directory ,org-wiki-static-dir
            :base-extension "css\\|woff2\\|woff\\|ttf"
            :publishing-directory ,org-wiki-publish-dir
            :publishing-function org-publish-attachment
            :recursive t)

           ("org-wiki"
            :components ("org-wiki-pages" "org-wiki-static"))))))

;; ── Entry Point ──────────────────────────────────────────────────────

;;;###autoload
(defun org-wiki-publish! ()
  "Publish ~/org/ as a local HTML wiki with org-roam link resolution."
  (interactive)
  (require 'org-roam)
  ;; Sync the roam DB to pick up any changes
  (org-roam-db-sync)
  ;; Build the ID resolution map
  (org-wiki--build-id-map)
  ;; Generate the index page
  (org-wiki--generate-index)
  ;; Install the link resolver advice
  (advice-add #'org-html-link :around #'org-wiki--resolve-id-link)
  (unwind-protect
      (org-publish "org-wiki" t)
    ;; Remove advice after publish to avoid affecting normal exports
    (advice-remove #'org-html-link #'org-wiki--resolve-id-link))
  (message "org-wiki: published to %s" org-wiki-publish-dir))
