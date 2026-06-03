;;; modules/org/org-roam-links-section.el -*- lexical-binding: t; -*-
;;;
;;; Custom org-roam buffer section: "Annotated Links"
;;;
;;; Shows only outgoing external URLs that have a matching annotation
;;; node in org-roam (bound via :ROAM_REFS:).
;;; - The URL line is a real org link (mouse-clickable, opens in browser)
;;; - The annotation sub-item is a text button that opens the annotation
;;;   node in the source window (the window the roam buffer is "about")
;;;
;;; Design: Option C — first description as label, ×N for duplicates.

(require 'org-roam)
(require 'org-element)
(require 'magit-section)

;; ── Data extraction ──────────────────────────────────────────────────

(defun jw/roam-links--extract-urls (buffer)
  "Extract all outgoing http/https links from BUFFER.
Returns a list of plists (:target URL :description DESC :position POS)
in document order."
  (with-current-buffer buffer
    (org-with-wide-buffer
     (let ((links nil))
       (org-element-map (org-element-parse-buffer) 'link
         (lambda (link)
           (let ((type (org-element-property :type link)))
             (when (member type '("http" "https"))
               (let* ((raw-link (org-element-property :raw-link link))
                      (begin (org-element-property :begin link))
                      (desc (when-let ((cb (org-element-property :contents-begin link))
                                       (ce (org-element-property :contents-end link)))
                              ;; Collapse internal whitespace/newlines
                              (replace-regexp-in-string
                               "[ \t\n]+" " "
                               (string-trim
                                (buffer-substring-no-properties cb ce))))))
                 (push (list :target raw-link :description desc :position begin)
                       links))))))
       (nreverse links)))))

(defun jw/roam-links--deduplicate (links)
  "Deduplicate LINKS by :target, preserving document order.
Returns alist of (URL . (:label DESC :count N))."
  (let ((seen (make-hash-table :test #'equal))
        (order nil))
    (dolist (link links)
      (let* ((target (plist-get link :target))
             (desc (plist-get link :description))
             (existing (gethash target seen)))
        (if existing
            (puthash target
                     (plist-put existing :count (1+ (plist-get existing :count)))
                     seen)
          (puthash target (list :label desc :count 1) seen)
          (push target order))))
    (mapcar (lambda (target)
              (cons target (gethash target seen)))
            (nreverse order))))

;; ── Annotation lookup ────────────────────────────────────────────────

(defun jw/roam-links--url-to-ref (url)
  "Convert a full URL to org-roam's refs storage format.
Org-roam strips the scheme and stores e.g. \"//host/path\"."
  (if (string-match "^https?:\\(//.*\\)" url)
      (match-string 1 url)
    url))

(defun jw/roam-links--find-annotation-nodes (url)
  "Find all org-roam nodes whose :ROAM_REFS: contains URL.
Returns a list of (id title file), or nil if none."
  (let ((ref (jw/roam-links--url-to-ref url)))
    (org-roam-db-query
     [:select [nodes:id nodes:title nodes:file]
      :from refs
      :left-join nodes
      :on (= refs:node-id nodes:id)
      :where (= refs:ref $s1)]
     ref)))

;; ── Annotation button action ─────────────────────────────────────────

(defun jw/roam-links--visit-annotation (button)
  "Visit the annotation node for BUTTON in the source node's window.
If the source node's buffer is visible, select that window first.
Otherwise fall back to `org-roam-node-visit' default behaviour."
  (let* ((ann-id (button-get button 'annotation-id))
         (source-file (org-roam-node-file org-roam-buffer-current-node))
         (target-win (get-buffer-window (find-file-noselect source-file))))
    (when target-win (select-window target-win))
    (org-roam-node-visit (org-roam-node-from-id ann-id))))

;; ── Magit section class ──────────────────────────────────────────────

(defclass jw/roam-annotated-links-section (magit-section) ()
  "Top-level section for annotated links.")

;; ── Section renderer ─────────────────────────────────────────────────

(defun jw/org-roam-annotated-links-section (node)
  "Insert an \"Annotated Links\" section into the org-roam buffer for NODE.
Only shows external URLs that have a matching annotation node (via :ROAM_REFS:).
URL lines are real org links (mouse-clickable, open in browser).
Annotation lines are buttons that open the node in the source window."
  (when-let* ((file (org-roam-node-file node))
              (buffer (find-file-noselect file)))
    (let* ((raw-links (jw/roam-links--extract-urls buffer))
           (deduped (jw/roam-links--deduplicate raw-links))
           ;; Pair each entry with its annotation nodes (nil if none)
           (with-annotations
            (mapcar (lambda (entry)
                      (cons entry (jw/roam-links--find-annotation-nodes (car entry))))
                    deduped))
           ;; Keep only those with at least one annotation
           (annotated (seq-filter #'cdr with-annotations)))
      (when annotated
        (magit-insert-section (jw/roam-annotated-links-section)
          (magit-insert-heading
            (format "Annotated Links (%d)" (length annotated)))
          (dolist (pair annotated)
            (let* ((entry (car pair))
                   (annotations (cdr pair))
                   (url (car entry))
                   (props (cdr entry))
                   (label (plist-get props :label))
                   (count (plist-get props :count))
                   (display-label (or label url))
                   (count-str (if (> count 1) (format " (×%d)" count) ""))
                   ;; Build org link markup for the URL
                   (url-link (format "[[%s][%s%s]]" url display-label count-str)))
              ;; URL line: real org link (clickable, opens browser)
              (insert (org-roam-fontify-like-in-org-mode
                       (concat "  " url-link))
                      "\n")
              ;; Annotation lines: one button per annotation node
              (dolist (annotation annotations)
                (let ((ann-id (nth 0 annotation))
                      (ann-title (nth 1 annotation)))
                  (insert "    ")
                  (insert-text-button
                   (concat "↳ " (or ann-title "annotations"))
                   'face 'shadow
                   'annotation-id ann-id
                   'action #'jw/roam-links--visit-annotation
                   'mouse-face 'highlight
                   'help-echo (format "Visit annotation: %s" (or ann-title ann-id)))
                  (insert "\n"))))))))))

;; ── Registration ─────────────────────────────────────────────────────

(with-eval-after-load 'org-roam-mode
  (add-to-list 'org-roam-mode-sections #'jw/org-roam-annotated-links-section t))

(provide 'org-roam-links-section)
;;; org-roam-links-section.el ends here
