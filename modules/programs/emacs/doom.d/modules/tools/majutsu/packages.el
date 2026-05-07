;; -*- no-byte-compile: t; -*-
;;; tools/majutsu/packages.el

(package! vc-jj :recipe (:host github :repo "emacsmirror/vc-jj"))

;; Ensure magit (and its dependency transient) are available, since majutsu
;; relies on magit-section and transient UIs.
(package! magit)

;; Use the main repo: https://github.com/0WD0/majutsu/
(package! majutsu :recipe (:host github :repo "0WD0/majutsu"))
