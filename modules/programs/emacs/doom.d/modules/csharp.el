;;; csharp.el -*- lexical-binding: t; -*-

;; Prefer Microsoft.CodeAnalysis.LanguageServer (the "Roslyn" LSP) over
;; OmniSharp and csharp-ls. The Roslyn server tracks the current C#
;; compiler, so it understands C# 14 features like extension members
;; (`extension(X x) { ... }` blocks) and the `field` keyword which
;; OmniSharp does not.
;;
;; lsp-mode ships `lsp-roslyn.el`, but its `lsp-roslyn--connect` is
;; pinned to an obsolete handshake: it expects the server to allocate a
;; named pipe and print `{"pipeName":"..."}` on stdout. Roslyn LSP 5.x
;; dropped that default — `--pipe <name>` now means "connect to this
;; pipe as a client" and the only auto-bootstrap mode is `--stdio`.
;;
;; Rather than registering a parallel client and losing lsp-roslyn's
;; nice bits (non-hexifying URI helpers, `solution/open` initialized-fn,
;; `workspace/projectInitializationComplete` handler), we just override
;; the one broken function to use stdio. Per-project flake.nix exposes
;; the binary and dll via $ROSLYN_LS_EXE / $ROSLYN_LS_DLL (see e.g.
;; ~/Code/<project>/flake.nix); envrc/direnv carries them into Emacs's
;; buffer environment.

(after! lsp-mode
  (setq lsp-disabled-clients '(omnisharp csharp-ls)))

(after! lsp-roslyn
  (setq lsp-roslyn-dotnet-executable (or (getenv "ROSLYN_LS_EXE")
                                         lsp-roslyn-dotnet-executable))
  (setq lsp-roslyn-server-dll-override-path (getenv "ROSLYN_LS_DLL"))

  ;; Replace the pipe-handshake connect with a plain stdio one. The
  ;; nix-provided `Microsoft.CodeAnalysis.LanguageServer` wrapper has
  ;; the dll baked in and ignores the dll path we'd otherwise pass, so
  ;; we just invoke it directly with --stdio. Applied as :override
  ;; advice (rather than a `defun` shadow) so it shows up in
  ;; `C-h f lsp-roslyn--connect' and can be removed with
  ;; `advice-remove' once upstream supports stdio natively.
  (defun +csharp/roslyn-connect-stdio (filter sentinel name environment-fn _workspace)
    "Start the Roslyn language server in --stdio mode.
:override advice for `lsp-roslyn--connect'; bypasses the obsolete
named-pipe handshake that upstream still ships."
    (let* ((process-environment
            (lsp--compute-process-environment environment-fn))
           (default-directory (lsp--default-directory-for-connection))
           (stderr-buf (format "*%s::stderr*" name))
           (proc (make-process
                  :name name
                  :buffer (generate-new-buffer-name name)
                  :coding 'no-conversion
                  :connection-type 'pipe
                  :filter filter
                  :sentinel sentinel
                  :stderr stderr-buf
                  :noquery t
                  :command (lsp-resolve-final-command
                            `(,lsp-roslyn-dotnet-executable
                              "--stdio"
                              ,(format "--logLevel=%s" lsp-roslyn-server-log-level)
                              ,(format "--extensionLogDirectory=%s"
                                       lsp-roslyn-server-log-directory)
                              ,@lsp-roslyn-server-extra-args)))))
      (when-let* ((b (get-buffer stderr-buf)))
        (with-current-buffer b (special-mode))
        (set-process-query-on-exit-flag (get-buffer-process b) nil))
      ;; lsp-mode expects (communication . command). With stdio they're
      ;; the same process.
      (cons proc proc)))

  (advice-add 'lsp-roslyn--connect :override #'+csharp/roslyn-connect-stdio))
