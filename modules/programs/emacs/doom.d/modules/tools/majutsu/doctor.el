;;; tools/majutsu/doctor.el -*- lexical-binding: t; -*-

(defadvice! +majutsu--doctor-jj-a (&rest _)
  :after #'doom-health-check
  (let ((jj (executable-find (or (bound-and-true-p majutsu-executable)
                                 "jj"))))
    (print! (if jj
                (success "Found jj executable: %s" jj)
              (warn "jj executable not found in PATH. Majutsu will not work.")))))
