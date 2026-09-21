;;; -*- lexical-binding: t -*-

;; TODO:
;; - [ ] split project-specific config out from main emacs config
;;   - nxedit github repo for main flake
;;   - project-local elisp extensions
;; - [ ] configure better highlighting colors
;;   - ex. get rid of yellow for related variables in racket
;; - [ ] bind nx-* structural editing to more specific keymap
;;   - smartparens keymap?
;; - [ ] setup company-mode
;; - [ ] improve on sexp-highlight-mode
;; - [ ] extend keybindings with racket-mode / racket-xp-mode
;; - [ ] fix cursor positioning when using C-u, C-d, C-b, C-f
;; - [ ] figure out how to bind eldoc to a key instead of a delay

;;; Config

;;;; Always ensure use-package forms

(setq use-package-always-ensure t)

;;; Emacs Behavior

;;;; Reduce GC pressure during user interaction

(use-package gcmh
  :init
  (gcmh-mode))

;;;; Don't use in-tree hidden files

(use-package no-littering
  :config
  (no-littering-theme-backups))

;;;; Enable undo persistence

(use-package undo-fu-session
  :config
  (undo-fu-session-global-mode 1))

;;;; Read kitty key sequences

(use-package kkp
  :hook (tty-setup . global-kkp-mode))

;;; Emacs Interface

;;;; Theme

;;;;; Color constants

(defconst dracula-bg         "#282a36")
(defconst dracula-fg         "#f8f8f2")
(defconst dracula-comment    "#6272a4")
(defconst dracula-current    "#353747")

(defconst dracula-cyan       "#8be9fd")
(defconst dracula-green      "#50fa7b")
(defconst dracula-orange     "#ffb86c")
(defconst dracula-pink       "#ff79c6")
(defconst dracula-purple     "#bd93f9")
(defconst dracula-red        "#ff5555")
(defconst dracula-region     "#44475a")
(defconst dracula-yellow     "#f1fa8c")

(defconst dracula-alt-bg     "#565761")
(defconst dracula-fg2        "#e2e2dc")
(defconst dracula-fg3        "#ccccc7")
(defconst dracula-fg4        "#b6b6b2")
(defconst dracula-dark-red   "#880000")
(defconst dracula-dark-green "#037a22")
(defconst dracula-dark-blue  "#0189cc")

;;;;; Dracula theme

(use-package dracula-theme
  :config
  (load-theme 'dracula t)
  (set-face-background 'default "unspecified-bg"))

;;;; Don't show startup screen, GNU info buffer, or info statusline

(setq inhibit-startup-screen t)
(setq initial-buffer-choice t)
(advice-add #'display-startup-echo-area-message :override #'ignore)

;;;; Disable menu bar for terminal sessions

(use-package menu-bar
  :ensure nil
  :if (not (display-graphic-p))
  :config
  (menu-bar-mode -1))

;;;; Use box-drawing characters for window borders

(setq standard-display-table (make-display-table))
(set-display-table-slot standard-display-table
                        'vertical-border
                        (make-glyph-code (string-to-char "│")))

;;;; Fuzzy completion

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  ;; Emacs 31: partial-completion behaves like substring
  (completion-pcm-leading-wildcard t))

;;;; Extended minibuffer interface

(use-package vertico
  :config
  (vertico-mode))

;;;; Rich minibuffer annotations

(use-package marginalia
  :custom
  (marginalia-align 'right)
  :init
  (marginalia-mode))

;;;; Search and navigation

(use-package consult
  :config
  ;; Hide *xyz* buffers by default
  ;; (Show with <SPC>)
  (add-to-list 'consult-buffer-filter "^\\*"))

;;;; Keybind visualizer

(use-package which-key
  :custom
  (which-key-idle-delay 0.001)
  :config
  (which-key-mode))

;;;; Project tree visualizer

(use-package treemacs
  :custom
  (treemacs-display-in-side-window t)
  (treemacs-wrap-around nil)
  :config
  (treemacs-follow-mode t))

(use-package treemacs-evil
  :after (treemacs evil)
  :config
  (treemacs-display-current-project-exclusively))

;;;; Undo tree visualizer

(use-package vundo)

;;;; Buffers

;;;;; Scroll behavior

(setq scroll-conservatively 101
      scroll-margin 1)

;;;;; Don't use tabs for indentation

(setq-default indent-tabs-mode nil)

;;;;; Don't blink cursor

(blink-cursor-mode -1)

;;;;; Clipboard integration

(defvar nxedit-wl-copy-process nil)

(setq interprogram-cut-function
      (lambda (text)
        (when (process-live-p nxedit-wl-copy-process)
          (delete-process nxedit-wl-copy-process))
        (setq nxedit-wl-copy-process
              (make-process
               :name "wl-copy"
               :buffer nil
               :command '("wl-copy" "--type" "text/plain")
               :connection-type 'pipe))
        (process-send-string nxedit-wl-copy-process text)
        (process-send-eof nxedit-wl-copy-process)))

(setq interprogram-paste-function
      (lambda ()
        ;; If an asynchronous copy is still being handed to Wayland,
        ;; let it finish before querying the clipboard.
        (when (process-live-p nxedit-wl-copy-process)
          (accept-process-output nxedit-wl-copy-process nil 0.1)
          (while (process-live-p nxedit-wl-copy-process)
            (accept-process-output nxedit-wl-copy-process nil 0.01)))

        (let ((text (shell-command-to-string
                     "wl-paste --no-newline")))
          (when (> (length text) 0)
            (if (string-suffix-p "\n" text)
                (propertize text
                            'yank-handler
                            '(evil-yank-line-handler))
              text)))))

;;;;; Modal interaction

(setq evil-want-keybinding nil)

(use-package evil
  :custom
  (evil-undo-system 'undo-redo)

  (evil-insert-state-cursor 'bar)
  (evil-kill-on-visual-paste nil)

  :config

  (setq evil-goto-definition-functions
        '(evil-goto-definition-xref
          evil-goto-definition-imenu
          evil-goto-definition-semantic
          evil-goto-definition-search))

  (evil-mode 1))

(use-package evil-collection
  :after (evil treemacs-evil)
  :config
  (evil-collection-init))

(use-package evil-terminal-cursor-changer
  :after evil
  :config
  (etcc-on))

;;;;; Structural editing

(use-package smartparens
  :hook
  (prog-mode . smartparens-strict-mode)
  (text-mode . smartparens-strict-mode)
  :config
  (require 'smartparens-config))

(use-package evil-smartparens
  :after (evil smartparens)
  :hook
  (smartparens-enabled . evil-smartparens-mode))

;;; Languages

;;;; Shared

;;;;; LSP

(use-package lsp-mode
  :custom
  (lsp-enable-indentation nil)
  (lsp-enable-on-type-formatting nil)
  (lsp-enable-xref nil)
  (lsp-auto-guess-root t)
  :hook
  (racket-mode . lsp)
  (racket-hash-lang-mode . lsp))

;;;;; Show line numbers

(setq-default display-line-numbers-type 'relative)
(setq-default display-line-numbers-width 3)

(custom-set-faces
 `(line-number ((t (:foreground ,dracula-comment
                                :background unspecified)))))

(add-hook 'lisp-mode-hook #'display-line-numbers-mode)
(add-hook 'emacs-lisp-mode-hook #'display-line-numbers-mode)
(add-hook 'racket-mode-hook #'display-line-numbers-mode)
(add-hook 'racket-hash-lang-mode-hook #'display-line-numbers-mode)

;;;;; Center 80-column area

(use-package visual-fill-column
  :config
  (setq-default visual-fill-column-width 80
                visual-fill-column-center-text t
                fill-column 80)

  :hook
  (lisp-mode . visual-fill-column-mode)
  (emacs-lisp-mode . visual-fill-column-mode)
  (racket-mode . visual-fill-column-mode)
  (racket-hash-lang-mode . visual-fill-column-mode))

;;; Highlight selected lisp form

(use-package paren
  :ensure nil
  :config
  (show-paren-mode -1))

(use-package highlight-sexp
  :ensure nil

  :custom
  (hl-sexp-background-color dracula-alt-bg)

  :hook
  (lisp-mode . highlight-sexp-mode)
  (emacs-lisp-mode . highlight-sexp-mode)
  (racket-mode . highlight-sexp-mode)
  (racket-hash-lang-mode . highlight-sexp-mode))

;;; Colorize parentheses, brackets, and braces

(use-package rainbow-delimiters
  :config
  (set-face-foreground 'rainbow-delimiters-depth-1-face dracula-purple)
  (set-face-foreground 'rainbow-delimiters-depth-2-face dracula-pink)
  (set-face-foreground 'rainbow-delimiters-depth-3-face dracula-orange)
  (set-face-foreground 'rainbow-delimiters-depth-4-face dracula-green)
  (set-face-foreground 'rainbow-delimiters-depth-5-face dracula-cyan)
  (set-face-foreground 'rainbow-delimiters-depth-6-face dracula-purple)
  (set-face-foreground 'rainbow-delimiters-depth-7-face dracula-pink)
  (set-face-foreground 'rainbow-delimiters-depth-8-face dracula-orange)
  (set-face-foreground 'rainbow-delimiters-depth-9-face dracula-green)
  :hook
  (lisp-mode . rainbow-delimiters-mode)
  (emacs-lisp-mode . rainbow-delimiters-mode)
  (racket-mode . rainbow-delimiters-mode)
  (racket-hash-lang-mode . rainbow-delimiters-mode))

;;;; Nix

(use-package nix-mode
  :mode "\\.nix\\'")

;;;; Racket

(defun nx-disable-lsp-eldoc-hover ()
  (setq-local lsp-eldoc-enable-hover nil))

(use-package racket-mode
  :hook
  (racket-mode . nx-disable-lsp-eldoc-hover)
  (racket-mode . racket-xp-mode)
  (racket-hash-lang-mode . nx-disable-lsp-eldoc-hover)
  (racket-hash-lang-mode . racket-xp-mode)

  :config

  ; Prevent eldoc's pre-command refresh from causing flicker
  (advice-add #'eldoc-pre-command-refresh-echo-area :override #'ignore)

  (evil-set-initial-state 'racket-repl-mode 'normal))

;;;;; LSP support for racket-hash-lang-mode

(with-eval-after-load 'lsp-racket
  (let ((client (gethash 'racket-langserver lsp-clients)))
    (setf (lsp--client-major-modes client)
          '(racket-mode racket-hash-lang-mode))))

(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-language-id-configuration
               '(racket-hash-lang-mode . "racket")))

(add-hook 'racket-hash-lang-mode-hook #'lsp)

;;;;; Open REPL in its own window

(add-to-list
 'display-buffer-alist
 '("^\\*Racket REPL"
   (display-buffer-in-direction)
   (direction . rightmost)
   (window-width . 80)
   (preserve-size . (t . nil))
   (inhibit-same-window . t)))

;; redraw flymake margins on configuration change
;; prevents clobbering by visual-column-mode

(add-hook 'window-configuration-change-hook
          (lambda ()
            (when (bound-and-true-p flymake-mode)
              (flymake--resize-margins)))
          'append)

;;; Keybindings

;;;; Helper functions

(defun nx-form-start (form &optional include-prefix)
  (when form
    (let ((start (sp-get form :beg)))
      (if include-prefix
          (- start (length (sp-get form :prefix)))
        start))))

(defun nx-form-end (form &optional include-suffix)
  (when form
    (let ((end (sp-get form :end)))
      (if include-suffix
          (+ end (length (sp-get form :suffix)))
        end))))

(defun nx-form-prefix (form)
  (when form
    (sp-get form :prefix)))

(defun nx-form-suffix (form)
  (when form
    (sp-get form :suffix)))

(defun nx-goto-form-start (form &optional include-prefix)
  (when form
    (goto-char (nx-form-start form include-prefix))))

(defun nx-goto-form-end (form &optional include-suffix)
  (when form
    (goto-char (- (nx-form-end form include-suffix) 1))))

(defun nx-indent-form (form)
  (when form
    (let ((inhibit-message t))
      (save-excursion
        (indent-region (nx-form-start form t) 
                       (nx-form-end form t))))))

(defun nx-get-parent-form (form)
  (when form 
    (nx-goto-form-start form)
    (save-excursion
      (sp-backward-up-sexp))))

(defun nx-get-form ()
  (let* ((thing (sp-get-thing)))
    (when (and thing
               (<= (nx-form-start thing)
                   (point)))
      thing)))

(defun nx-get-form-or-parent ()
  (or (nx-get-form)
      (save-excursion
        (sp-backward-up-sexp))))

(defun nx-form-contains-p (a b)
  (let ((beg-a (nx-form-start a))
        (beg-b (nx-form-start b))
        (end-a (nx-form-end a))
        (end-b (nx-form-end b)))
    (and (< beg-a beg-b)
         (< end-b end-a))))

(defun nx-form-delimited-p (form)
  (and (not (string-empty-p (sp-get form :op)))
       (not (string-empty-p (sp-get form :cl)))))

(defun nx-get-prev-form (form)
  (when form
    (let ((next (save-excursion
                  (nx-goto-form-start form)
                  (sp-next-sexp -1))))
      (when next
        (and (not (nx-form-contains-p next form))
             next)))))

(defun nx-get-next-form (form)
  (when form
    (let ((next (save-excursion
                  (nx-goto-form-start form)
                  (sp-next-sexp 1))))
      (when next
        (and (not (nx-form-contains-p next form))
             next)))))

(defun nx-get-first-child-form (form)
  (when form
    (let ((child (save-excursion
                   (nx-goto-form-start form)
                   (forward-char 1)
                   (skip-chars-forward " \t\n")
                   (or (nx-get-form)
                       (sp-next-sexp)))))
      (when child
        (and (nx-form-contains-p form child)
             child)))))

(defun nx-get-last-child-form (form)
  (when form
    (let ((child (save-excursion
                   (nx-goto-form-end form)
                   (backward-char 1)
                   (skip-chars-backward " \t\n")
                   (or (nx-get-form)
                       (sp-previous-sexp)))))
      (when child
        (and (nx-form-contains-p form child)
             child)))))

(defun nx-transpose-forms (a b)
  (let* ((a-first (< (nx-form-start a t) (nx-form-start b t)))
         (first (if a-first a b))
         (second (if a-first b a))
         (pref1 (length (nx-form-prefix first)))
         (pref2 (length (nx-form-prefix second)))
         (beg1 (nx-form-start first t))
         (end1 (nx-form-end first t))
         (beg2 (nx-form-start second t))
         (end2 (nx-form-end second t))
         (text1 (buffer-substring beg1 end1))
         (between (buffer-substring end1 beg2))
         (text2 (buffer-substring beg2 end2))
         (target (if a-first
                     (+ beg1 (length text2) (length between) pref1)
                   (+ beg1 pref2))))
    (atomic-change-group
      (delete-region beg1 end2)
      (goto-char beg1)
      (insert text2 between text1)
      (goto-char target)
      (nx-get-form))))

(defun nx-up ()
  (interactive)
  (let ((form (nx-get-form)))
    (if form
        (nx-goto-form-start (nx-get-parent-form form))
      (sp-backward-up-sexp))))

(defun nx-down ()
  (interactive)
  (let ((form (nx-get-form)))
    (when form
      (let ((child (nx-get-first-child-form form)))
        (when child
          (nx-goto-form-start child))))))

(defun nx-prev ()
  (interactive)
  (let ((form (nx-get-form)))
    (if form
        (nx-goto-form-start (nx-get-prev-form form))
      (sp-next-sexp -1))))

(defun nx-next ()
  (interactive)
  (let ((form (nx-get-form)))
    (if form
        (nx-goto-form-start (nx-get-next-form form))
      (sp-next-sexp 1))))

(defun nx-raise ()
  (interactive)
  (let ((form (nx-get-form-or-parent)))
    (when form
      (nx-goto-form-start form)
      (sp-raise-sexp))))

(defun nx-delete-whitespace-around-point ()
  (let ((from (save-excursion
                (skip-chars-backward " \t\n")
                (point)))
        (to (save-excursion
              (skip-chars-forward " \t\n")
              (point))))
    (delete-region from to)))

(defun nx-slurp-backward ()
  (interactive)
  (let ((form (nx-get-form)))
    (when (and form
               (nx-form-delimited-p form))
      (let ((prev (nx-get-prev-form form))
            (child (nx-get-first-child-form form)))
        (when prev
          (if child
              (progn
                (nx-goto-form-start child)
                (sp-backward-slurp-sexp))
            (nx-goto-form-end form)
            (sp-backward-slurp-sexp)
            (nx-delete-whitespace-around-point))
          (sp-backward-up-sexp))))))

(defun nx-barf-backward ()
  (interactive)
  (let* ((form (nx-get-form)))
    (when (and form
               (nx-form-delimited-p form))
      (let ((child (nx-get-first-child-form form)))
        (when child
          (nx-goto-form-start child)
          (sp-backward-barf-sexp)
          (sp-backward-up-sexp)
          (let ((form (nx-get-form)))
            (when (not (nx-get-first-child-form form))
              (print (nx-goto-form-start form t))
              (insert " ")
              (nx-goto-form-end form)
              (nx-goto-current-form-start))))))))

(defun nx-barf-forward ()
  (interactive)
  (let ((form (nx-get-form)))
    (when (and form
               (nx-form-delimited-p form))
      (let ((child (nx-get-first-child-form form)))
        (when child
          (nx-goto-form-start child)
          (sp-forward-barf-sexp)
          (sp-backward-up-sexp)
          (nx-goto-form-end (nx-get-form))
          (let ((form (nx-get-form)))
            (when (not (nx-get-first-child-form form))
              (save-excursion
                (forward-char 1)
                (insert " ")))))))))

(defun nx-slurp-forward ()
  (interactive)
  (let ((form (nx-get-form)))
    (when (and form
               (nx-form-delimited-p form))
      (let ((next (nx-get-next-form form))
            (child (nx-get-last-child-form form)))
        (when next
          (if child
              (progn (nx-goto-form-end child)
                     (sp-forward-slurp-sexp))
            (nx-goto-form-end form)
            (sp-forward-slurp-sexp)
            (nx-delete-whitespace-around-point))
          (sp-backward-up-sexp)
          (nx-goto-form-start form)
          (nx-goto-form-end (nx-get-form)))))))

(defun nx-goto-current-form-start ()
  (interactive)
  (nx-goto-form-start (nx-get-form)))

(defun nx-goto-current-form-end ()
  (interactive)
  (nx-goto-form-end (nx-get-form)))

(defun nx-indent-current-form ()
  (interactive)
  (nx-indent-form (nx-get-form-or-parent)))

(defun nx-transpose-forward ()
  (interactive)
  (let* ((a (nx-get-form))
         (b (nx-get-next-form a)))
    (when (and a b)
      (nx-goto-form-start (nx-transpose-forms a b)))))

(defun nx-transpose-backward ()
  (interactive)
  (let* ((a (nx-get-form))
         (b (nx-get-prev-form a)))
    (when (and a b)
      (nx-goto-form-start (nx-transpose-forms a b)))))

(defun nx-unwrap ()
  (interactive)
  (let ((form (nx-get-form)))
    (when form
     (nx-form-delimited-p form)
     (nx-goto-form-start form)
     (call-interactively #'sp-unwrap-sexp))))

(defun nx-wrap-round ()
  (interactive)
  (sp-wrap-round)
  (nx-up))

(defun nx-wrap-square ()
  (interactive)
  (sp-wrap-square)
  (nx-up))

(defun nx-wrap-curly ()
  (interactive)
  (sp-wrap-curly)
  (nx-up))

(defun nx-wrap-round-and-insert ()
  (interactive)
  (sp-wrap-round)
  (evil-insert 0))

(defun nx-wrap-square-and-insert ()
  (interactive)
  (sp-wrap-square)
  (evil-insert 0))

(defun nx-wrap-curly-and-insert ()
  (interactive)
  (sp-wrap-curly)
  (evil-insert 0))

(defun nx-insert-before ()
  (interactive)
  (let* ((form (nx-get-form)))
    (when form
      (nx-goto-form-start form t)
      (insert " ")
      (backward-char 1)
      (evil-insert 0))))

(defun nx-insert-at-start ()
  (interactive)
  (let ((form (nx-get-form)))
    (when form
      (nx-goto-form-start form t)
      (evil-insert 0))))

(defun nx-insert-at-end ()
  (interactive)
  (let ((form (nx-get-form)))
    (when form
      (nx-goto-form-end form t)
      (forward-char 1)
      (evil-insert 0))))

(defun nx-insert-after ()
  (interactive)
  (let ((form (nx-get-form)))
    (when form
      (nx-goto-form-end form t)
      (forward-char 1)
      (insert " ")
      (evil-insert 0))))

(defun nx-open-before ()
  (interactive)
  (let* ((form (nx-get-form)))
    (when form
      (nx-goto-form-start form t)
      (save-excursion
        (insert "\n")
        (indent-according-to-mode)))))

(defun nx-open-after ()
  (interactive)
  (let* ((form (nx-get-form)))
    (nx-goto-form-end form t)
    (forward-char 1)
    (newline-and-indent)))

(defun nx-move-up ()
  (interactive)
  (let* ((form (nx-get-form-or-parent))
         (prev (nx-get-prev-form form))
         (parent (nx-get-parent-form form)))
    (when form
      (if prev

          (progn
            (nx-goto-form-end prev)
            (when (save-excursion
                    (search-forward "\n" (nx-form-start form) t))
              (join-line t))
            (nx-goto-form-start prev)
            (nx-next)
            (nx-indent-form (or parent
                                (nx-get-form))))

        (when parent
          (progn
            (nx-goto-form-start parent)
            (when (save-excursion
                    (search-forward "\n" (nx-form-start form) t))
              (join-line t))
            (nx-indent-form parent)
            (nx-goto-form-start (nx-get-first-child-form parent))))))))

(defun nx-move-down ()
  (interactive)
  (let* ((form (nx-get-form-or-parent)))
    (when form
      (let ((prev (nx-get-prev-form form))
            (parent (nx-get-parent-form form)))
        (when (and form prev)
          (nx-goto-form-start form t)
          (newline-and-indent)
          (let ((prefix (nx-form-prefix form)))
            (forward-char (length prefix)))
          (nx-indent-form (or parent
                              (nx-get-form))))))))

(defun nx-open-before-and-insert ()
  (interactive)
  (nx-open-before)
  (evil-insert 0))

(defun nx-open-after-and-insert ()
  (interactive)
  (nx-open-after)
  (evil-insert 0))

(defun nx-paste-before ()
  (interactive)
  (nx-open-before)
  (call-interactively #'evil-paste-before)
  (nx-goto-current-form-start))

(defun nx-paste-after ()
  (interactive)
  (nx-open-after)
  (call-interactively #'evil-paste-before)
  (nx-goto-current-form-start))

(evil-define-text-object nx-form (count &optional beg end type)
  (let ((form (or (nx-get-form-or-parent)
                  (save-excursion (sp-next-sexp 1)))))

    (when form
      (let* ((beg (nx-form-start form t))
             (next (nx-get-next-form form))
             (end (if next
                      (nx-form-start next t)
                    (nx-form-end form t))))

        (evil-range beg end type :expanded t)))))

(evil-define-text-object nx-form-outer (count &optional beg end type)
  (let ((form (nx-get-form-or-parent)))
    (when form
      (let ((start (nx-form-start form t))
            (end (nx-form-end form t)))
        (evil-range start end type :expanded t)))))

(evil-define-text-object nx-form-inner (count &optional beg end type)
  (let ((form (nx-get-form-or-parent)))
    (when form
      (let* ((beg (nx-form-start form))
             (end (nx-form-end form))
             (op (sp-get form :op))
             (cl (sp-get form :cl))
             (beg (if (string-empty-p op)
                      beg
                    (+ beg 1)))
             (end (if (string-empty-p cl)
                      end
                    (- end 1))))
        (evil-range beg end type :expanded t)))))

;;;; Use escape as a general 'quit' command instead of meta-key

(global-set-key (kbd "<escape>") #'keyboard-escape-quit)

;;;; Undo tree visualizer

(define-key vundo-mode-map (kbd "j") #'vundo-next)
(define-key vundo-mode-map (kbd "k") #'vundo-previous)
(define-key vundo-mode-map (kbd "h") #'vundo-backward)
(define-key vundo-mode-map (kbd "l") #'vundo-forward)
(define-key vundo-mode-map (kbd "q") #'vundo-quit)
(define-key vundo-mode-map (kbd "RET") #'vundo-confirm)

;;;; Minibuffer

;; (define-key minibuffer-local-map "M-A" #'marginalia-cycle)

;;;; Extended minibuffer

(defun nx-vertico-kill-buffer ()
  (interactive)
  (when-let* ((cand (vertico--candidate))
              (multi-category (get-text-property 0 'multi-category cand))
              (buffer (cdr multi-category)))
    (kill-buffer buffer)
    (abort-recursive-edit)))

(keymap-set vertico-map "C-j" #'vertico-next)
(keymap-set vertico-map "C-k" #'vertico-previous)
(keymap-set vertico-map "C-h" #'vertico-directory-delete-char)
(keymap-set vertico-map "C-l" #'vertico-insert)
(define-key vertico-map (kbd "C-d") #'nx-vertico-kill-buffer)

;;;; Modal interaction

;;;;; Join line

(evil-global-set-key 'normal (kbd "J") nil)
(evil-global-set-key 'normal (kbd "L") #'evil-join)

(evil-global-set-key 'normal (kbd "C-h") #'nx-up)
(evil-global-set-key 'normal (kbd "C-j") #'nx-next)
(evil-global-set-key 'normal (kbd "C-k") #'nx-prev)
(evil-global-set-key 'normal (kbd "C-l") #'nx-down)

(evil-global-set-key 'normal (kbd "H") #'nx-raise)
(evil-global-set-key 'normal (kbd "J") #'nx-transpose-forward)
(evil-global-set-key 'normal (kbd "K") #'nx-transpose-backward)

(evil-global-set-key 'normal (kbd "C-S-h") #'nx-slurp-backward)
(evil-global-set-key 'normal (kbd "C-S-j") #'nx-barf-backward)
(evil-global-set-key 'normal (kbd "C-S-k") #'nx-barf-forward)
(evil-global-set-key 'normal (kbd "C-S-l") #'nx-slurp-forward)

(evil-define-key 'normal global-map "fs" #'nx-goto-current-form-start)
(evil-define-key 'normal global-map "fe" #'nx-goto-current-form-end)

(evil-define-key 'normal global-map "fI" #'nx-insert-before)
(evil-define-key 'normal global-map "fi" #'nx-insert-at-start)
(evil-define-key 'normal global-map "fa" #'nx-insert-at-end)
(evil-define-key 'normal global-map "fA" #'nx-insert-after)
(evil-define-key 'normal global-map "fk" #'nx-move-up)
(evil-define-key 'normal global-map "fj" #'nx-move-down)
(evil-define-key 'normal global-map "fO" #'nx-open-before-and-insert)
(evil-define-key 'normal global-map "fo" #'nx-open-after-and-insert)
(evil-define-key 'normal global-map "fP" #'nx-paste-before)
(evil-define-key 'normal global-map "fp" #'nx-paste-after)

(evil-define-key 'normal global-map "ff" #'nx-indent-current-form)
(evil-define-key 'normal global-map "fz" #'nx-unwrap)
(evil-define-key 'normal global-map "fw(" #'nx-wrap-round-and-insert)
(evil-define-key 'normal global-map "fw[" #'nx-wrap-square-and-insert)
(evil-define-key 'normal global-map "fw{" #'nx-wrap-curly-and-insert)
(evil-define-key 'normal global-map "fw)" #'nx-wrap-round)
(evil-define-key 'normal global-map "fw]" #'nx-wrap-square)
(evil-define-key 'normal global-map "fw}" #'nx-wrap-curly)

(define-key evil-inner-text-objects-map (kbd "f") #'nx-form-inner)
(define-key evil-outer-text-objects-map (kbd "f") #'nx-form-outer)
(define-key evil-operator-state-map (kbd "f") #'nx-form)
(define-key evil-visual-state-map (kbd "f") #'nx-form)

;;;;; Screen scrolling

(evil-global-set-key 'normal (kbd "C-u")
		     (lambda () (interactive)
		       (let ((scroll-preserve-screen-position 'always))
			 (scroll-down (/ (window-body-height) 2)))))

(evil-global-set-key 'normal (kbd "C-d")
		     (lambda () (interactive)
		       (let ((scroll-preserve-screen-position 'always))
			 (scroll-up (/ (window-body-height) 2)))))

(evil-global-set-key 'normal (kbd "C-f")
		     (lambda () (interactive)
		       (let ((scroll-preserve-screen-position 'always))
			 (scroll-down (window-body-height)))))

(evil-global-set-key 'normal (kbd "C-b")
		     (lambda () (interactive)
		       (let ((scroll-preserve-screen-position 'always))
			 (scroll-up (window-body-height)))))

;;;; Spacebar command map

(define-prefix-command 'nxedit-space-map)

(evil-global-set-key 'normal (kbd "SPC") #'nxedit-space-map)

(define-key nxedit-space-map (kbd "j")
            (lambda ()
              (interactive)
              (eldoc-print-current-symbol-info nil)))

(define-key nxedit-space-map (kbd "u") #'vundo)

;;;; Backspace command map

(define-prefix-command 'nxedit-backspace-map)

(evil-global-set-key 'normal (kbd "DEL") #'nxedit-backspace-map)

;;;;; Self-documentation

(define-key nxedit-backspace-map (kbd "k") #'describe-keymap)
(define-key nxedit-backspace-map (kbd "c") #'describe-command)

;;;;; Buffers and files

(define-key nxedit-backspace-map (kbd "f") #'project-find-file)
(define-key nxedit-backspace-map (kbd "b") #'consult-buffer)

;;;;; Buffer navigation

(define-key nxedit-backspace-map (kbd "g") #'consult-grep)
(define-key nxedit-backspace-map (kbd "m") #'evil-show-marks)
(define-key nxedit-backspace-map (kbd "r") #'evil-show-registers)

;;;;; LSP diagnostics

(define-key nxedit-backspace-map (kbd "d")
            #'flymake-show-buffer-diagnostics)

(define-key nxedit-backspace-map (kbd "D")
            #'flymake-show-project-diagnostics)

;;; Project-specific

(put 'nonterminal 'racket-indent-function 1)
(put 'nonterminal/nesting 'racket-indent-function 1)
(put 'nonterminal/exporting 'racket-indent-function 1)
(put 'host-interface/expression 'racket-indent-function 0)
(put 'host-interface/definition 'racket-indent-function 0)
(put 'host-interface/definitions 'racket-indent-function 0)

(put 'define-language 'racket-indent-function 1)
(put 'derive-language 'racket-indent-function 1)
(put 'define-pass 'racket-indent-function 1)

(defconst nx-racket-head-forms
  '(define-syntax-class
    pattern

    syntax-spec
    host-interface/expression
    host-interface/definition
    host-interface/definitions
    nonterminal
    nonterminal/nesting
    nonterminal/exporting
    define-persistent-symbol-table
    symbol-table-set!

    define-language
    derive-language
    define-pass

    define-narthex-syntax
    define-narthex-syntax-parser

    define-object
    define-interface
    cont
    suspend))

(defun nx-keyword-font-lock ()
  (font-lock-add-keywords
   nil
   `((,(concat "("
               (regexp-opt (mapcar #'symbol-name nx-racket-head-forms)
                           'symbols))
      1 font-lock-keyword-face t)))
  (font-lock-flush)
  (font-lock-ensure))

(add-hook 'racket-mode-hook #'nx-keyword-font-lock)
