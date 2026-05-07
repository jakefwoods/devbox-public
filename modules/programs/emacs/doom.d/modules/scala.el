;;; programs/emacs/doom.d/lang/scala.el -*- lexical-binding: t; -*-
;;;
;;; Assumptions:
;;;
;;; - scalastyle is available from PATH
;;; - scalafmt is available from PATH
;;; - metals-emacs is available from PATH

(defun personal/scala/sbt-do-test-current-file ()
  "Run all tests for the current file

   Assumes that the corresponding test file will contain the current filename
   without the extension. I.e. the tests for 'Foo.scala' will contain the word 'Foo'
   in the spec name, such as 'FooSpec' or 'FooTest' or 'TestFoo'"

  (interactive)
  (sbt-command
   (concat "testOnly *" (file-name-base buffer-file-name) "*")))

(map! :map scala-mode-map
      :localleader
      (:prefix ("t" . "test")
       :desc "sbt test" "a" #'sbt-do-test
       :desc "sbt test this file" "t" 'personal/sbt-do-test-current-file))
