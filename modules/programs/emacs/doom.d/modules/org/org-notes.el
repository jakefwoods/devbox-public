;;; programs/emacs/doom.d/modules/org/org-notes.el -*- lexical-binding: t; -*-
;;;
;;; References:
;;; - https://d12frosted.io/posts/2020-06-24-task-management-with-roam-vol2.html
;;; - https://d12frosted.io/posts/2021-01-16-task-management-with-roam-vol5.html

(defun +org-notes-agenda-update-all ()
  "Update the agenda tag for all note files"
  (interactive)
  (dolist (file (org-roam--list-all-files))
    (message "processing %s" file)
    (with-current-buffer (or (find-buffer-visiting file)
                             (find-file-noselect file))
      (+org-notes-agenda-update-tag)
      (save-buffer))))

(defun +org-notes-has-todo-p ()
  "Return non-nil if current buffer has any TODO entry.

TODO entries marked as done are ignored, meaning this function returns nil if
current buffer only contains completed tasks."
  (interactive)
  (seq-find
   (lambda (type)
     (eq type 'todo))
   (org-element-map
       (org-element-parse-buffer 'headline)
       'headline
     (lambda (h)
       (org-element-property :todo-type h)))))

(defun +org-notes-agenda-update-tag ()
  "Update `agenda' tag in the current buffer."
  (when (and (not (active-minibuffer-window))
             (+org-notes-buffer-p))
    (if (+org-notes-has-todo-p)
        (+org-roam-tag-add-noninteractive "agenda")
      (+org-roam-tag-delete-noninteractive "agenda"))))

(add-hook 'find-file-hook #'+org-notes-agenda-update-tag)
(add-hook 'before-save-hook #'+org-notes-agenda-update-tag)

(defun +org-notes-buffer-p ()
  "Return non-nil if the currently visited buffer is a note."
  (and buffer-file-name
       (string-prefix-p
        (expand-file-name (file-name-as-directory org-roam-directory))
        (file-name-directory buffer-file-name))))

(defun +org-notes-agenda-files ()
  "Return a list of note files containing the agenda tag"
  (seq-map
   #'car
   (org-roam-db-query
    [:select file
     :from tags
     :where (like tags '"%agenda%")])))
