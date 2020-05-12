;; -*- mode: emacs-lisp -*-
;; This file is loaded by Spacemacs at startup.
;; It must be stored in your home directory.

(defconst user-site-lisp-directory
  (expand-file-name "site-lisp/" user-emacs-directory))

(add-to-list 'load-path "~/.emacs.d/lisp")

;; (defun add-to-load-path (path &optional dir)
;;   (setq load-path
;;         (cons (expand-file-name path (or dir user-emacs-directory)) load-path)))


;; Add top-level lisp directories, in case they were not setup by the
;; environment.

;; (dolist (dir (nreverse
;;               (list

;;                user-site-lisp-directory)))
;;   (dolist (entry (nreverse (directory-files-and-attributes dir)))
;;     (if (cadr entry)
;;         (add-to-load-path (car entry) dir))))

;; (eval-and-compile
;;   (mapc
;;    #'(lambda (path)
;;        (push (expand-file-name path user-emacs-directory) load-path))
;;    '("site-lisp" "lisp" "lisp/use-package" ""))

;;   (defun agda-site-lisp ()
;;     (let ((agda
;;            (nth 1 (split-string
;;                    (shell-command-to-string "load-env-agda which agda")
;;                    "\n")))))))

(eval-and-compile
  (defvar use-package-verbose t)
  ;; (defvar use-package-expand-minimally t)
  (eval-after-load 'advice
    `(setq ad-redefinition-action 'accept))
  ;; (require 'cl)
  ;; (require 'use-package)
  )

(defun dotspacemacs/layers ()
  "Configuration Layers declaration.
You should not put any user code in this function besides modifying the variable
values."
  (setq-default
   ;; Base distribution to use. This is a layer contained in the directory
   ;; `+distribution'. For now available distributions are `spacemacs-base'
   ;; or `spacemacs'. (default 'spacemacs)
   dotspacemacs-distribution 'spacemacs
   ;; Lazy installation of layers (i.e. layers are installed only when a file
   ;; with a supported type is opened). Possible values are `all', `unused'
   ;; and `nil'. `unused' will lazy install only unused layers (i.e. layers
   ;; not listed in variable `dotspacemacs-configuration-layers'), `all' will
   ;; lazy install any layer that support lazy installation even the layers
   ;; listed in `dotspacemacs-configuration-layers'. `nil' disable the lazy
   ;; installation feature and you have to explicitly list a layer in the
   ;; variable `dotspacemacs-configuration-layers' to install it.
   ;; (default 'unused)
   dotspacemacs-enable-lazy-installation 'unused
   ;; If non-nil then Spacemacs will ask for confirmation before installing
   ;; a layer lazily. (default t)
   dotspacemacs-ask-for-lazy-installation t
   ;; If non-nil layers with lazy install support are lazy installed.
   ;; List of additional paths where to look for configuration layers.
   ;; Paths must have a trailing slash (i.e. `~/.mycontribs/')
   dotspacemacs-configuration-layer-path '()
   ;; List of configuration layers to load.
   dotspacemacs-configuration-layers
   '(
     rust
     nginx
     go
     sql
     php
     docker
     ansible
     ruby
     csv
     yaml
     javascript
     html
     ;; ----------------------------------------------------------------
     ;; Example of useful layers you may want to use right away.
     ;; Uncomment some layer names and press <SPC f e R> (Vim style) or
     ;; <M-m f e R> (Emacs style) to install them.
     ;; ----------------------------------------------------------------
     helm
     auto-completion
     ;; better-defaults
     emacs-lisp
     git
     latex
     (latex :variables latex-build-command "LaTeX")
     (latex :variables latex-enable-auto-fill t)
     (latex :variables latex-enable-folding t)
     markdown
     org
     ;; (shell :variables
     ;;        shell-default-height 30
     ;;        shell-default-position 'bottom)
     spell-checking
     syntax-checking
     ;; version-control
     ;;
     ;; my additons bellow 
     osx
     themes-megapack
     python
     w3m
     ;;
     ;; elfeed and the rss file
     ;; (elfeed :variables rmh-elfeed-org-files (list "~/Dropbox/Org/elfeed.org"))
     )
   ;; List of additional packages that will be installed without being
   ;; wrapped in a layer. If you need some configuration for these
   ;; packages, then consider creating a layer. You can also put the
   ;; configuration in `dotspacemacs/user-config'.
   dotspacemacs-additional-packages '(persistent-scratch shift-text geben writeroom-mode)
   ;; A list of packages that cannot be updated.
   dotspacemacs-frozen-packages '()
   ;; A list of packages that will not be installed and loaded.
   dotspacemacs-excluded-packages '(org-bullets)
   ;; Defines the behaviour of Spacemacs when installing packages.
   ;; Possible values are `used-only', `used-but-keep-unused' and `all'.
   ;; `used-only' installs only explicitly used packages and uninstall any
   ;; unused packages as well as their unused dependencies.
   ;; `used-but-keep-unused' installs only the used packages but won't uninstall
   ;; them if they become unused. `all' installs *all* packages supported by
   ;; Spacemacs and never uninstall them. (default is `used-only')
   dotspacemacs-install-packages 'used-only))

(defun dotspacemacs/init ()
  "Initialization function.
This function is called at the very startup of Spacemacs initialization
before layers configuration.
You should not put any user code in there besides modifying the variable
values."
  ;; This setq-default sexp is an exhaustive list of all the supported
  ;; spacemacs settings.
  (setq-default
   ;; If non nil ELPA repositories are contacted via HTTPS whenever it's
   ;; possible. Set it to nil if you have no way to use HTTPS in your
   ;; environment, otherwise it is strongly recommended to let it set to t.
   ;; This variable has no effect if Emacs is launched with the parameter
   ;; `--insecure' which forces the value of this variable to nil.
   ;; (default t)
   dotspacemacs-elpa-https t
   ;; Maximum allowed time in seconds to contact an ELPA repository.
   dotspacemacs-elpa-timeout 5
   ;; If non nil then spacemacs will check for updates at startup
   ;; when the current branch is not `develop'. Note that checking for
   ;; new versions works via git commands, thus it calls GitHub services
   ;; whenever you start Emacs. (default nil)
   dotspacemacs-check-for-update nil
   ;; If non-nil, a form that evaluates to a package directory. For example, to
   ;; use different package directories for different Emacs versions, set this
   ;; to `emacs-version'.
   dotspacemacs-elpa-subdirectory nil
   ;; One of `vim', `emacs' or `hybrid'.
   ;; `hybrid' is like `vim' except that `insert state' is replaced by the
   ;; `hybrid state' with `emacs' key bindings. The value can also be a list
   ;; with `:variables' keyword (similar to layers). Check the editing styles
   ;; section of the documentation for details on available variables.
   ;; (default 'vim)
   dotspacemacs-editing-style 'emacs
   ;; If non nil output loading progress in `*Messages*' buffer. (default nil)
   dotspacemacs-verbose-loading nil
   ;; Specify the startup banner. Default value is `official', it displays
   ;; the official spacemacs logo. An integer value is the index of text
   ;; banner, `random' chooses a random text banner in `core/banners'
   ;; directory. A string value must be a path to an image format supported
   ;; by your Emacs build.
   ;; If the value is nil then no banner is displayed. (default 'official)
   dotspacemacs-startup-banner 'official
   ;; List of items to show in startup buffer or an association list of
   ;; the form `(list-type . list-size)`. If nil then it is disabled.
   ;; Possible values for list-type are:
   ;; `recents' `bookmarks' `projects' `agenda' `todos'."
   ;; List sizes may be nil, in which case
   ;; `spacemacs-buffer-startup-lists-length' takes effect.
   dotspacemacs-startup-lists '((recents . 5)
                                (projects . 7))
   ;; True if the home buffer should respond to resize events.
   dotspacemacs-startup-buffer-responsive t
   ;; Default major mode of the scratch buffer (default `text-mode')
   dotspacemacs-scratch-mode 'text-mode
   ;; List of themes, the first of the list is loaded when spacemacs starts.
   ;; Press <SPC> T n to cycle to the next theme in the list (works great
   ;; with 2 themes variants, one dark and one light)
   dotspacemacs-themes '(spacemacs-light
                         spacemacs-dark)
   ;; If non nil the cursor color matches the state color in GUI Emacs.
   dotspacemacs-colorize-cursor-according-to-state t
   ;; Default font, or prioritized list of fonts. `powerline-scale' allows to
   ;; quickly tweak the mode-line size to make separators look not too crappy.
   dotspacemacs-default-font '("Source Code Pro"
                               :size 13
                               :weight normal
                               :width normal
                               :powerline-scale 1.1)
   ;; The leader key
   dotspacemacs-leader-key "SPC"
   ;; The key used for Emacs commands (M-x) (after pressing on the leader key).
   ;; (default "SPC")
   dotspacemacs-emacs-command-key "SPC"
   ;; The key used for Vim Ex commands (default ":")
   dotspacemacs-ex-command-key ":"
   ;; The leader key accessible in `emacs state' and `insert state'
   ;; (default "M-m")
   dotspacemacs-emacs-leader-key "M-m"
   ;; Major mode leader key is a shortcut key which is the equivalent of
   ;; pressing `<leader> m`. Set it to `nil` to disable it. (default ",")
   dotspacemacs-major-mode-leader-key ","
   ;; Major mode leader key accessible in `emacs state' and `insert state'.
   ;; (default "C-M-m")
   dotspacemacs-major-mode-emacs-leader-key "C-M-m"
   ;; These variables control whether separate commands are bound in the GUI to
   ;; the key pairs C-i, TAB and C-m, RET.
   ;; Setting it to a non-nil value, allows for separate commands under <C-i>
   ;; and TAB or <C-m> and RET.
   ;; In the terminal, these pairs are generally indistinguishable, so this only
   ;; works in the GUI. (default nil)
   dotspacemacs-distinguish-gui-tab nil
   ;; If non nil `Y' is remapped to `y$' in Evil states. (default nil)
   dotspacemacs-remap-Y-to-y$ nil
   ;; If non-nil, the shift mappings `<' and `>' retain visual state if used
   ;; there. (default t)
   dotspacemacs-retain-visual-state-on-shift t
   ;; If non-nil, J and K move lines up and down when in visual mode.
   ;; (default nil)
   dotspacemacs-visual-line-move-text nil
   ;; If non nil, inverse the meaning of `g' in `:substitute' Evil ex-command.
   ;; (default nil)
   dotspacemacs-ex-substitute-global nil
   ;; Name of the default layout (default "Default")
   dotspacemacs-default-layout-name "Default"
   ;; If non nil the default layout name is displayed in the mode-line.
   ;; (default nil)
   dotspacemacs-display-default-layout nil
   ;; If non nil then the last auto saved layouts are resume automatically upon
   ;; start. (default nil)
   dotspacemacs-auto-resume-layouts nil
   ;; Size (in MB) above which spacemacs will prompt to open the large file
   ;; literally to avoid performance issues. Opening a file literally means that
   ;; no major mode or minor modes are active. (default is 1)
   dotspacemacs-large-file-size 1
   ;; Location where to auto-save files. Possible values are `original' to
   ;; auto-save the file in-place, `cache' to auto-save the file to another
   ;; file stored in the cache directory and `nil' to disable auto-saving.
   ;; (default 'cache)
   dotspacemacs-auto-save-file-location 'cache
   ;; Maximum number of rollback slots to keep in the cache. (default 5)
   dotspacemacs-max-rollback-slots 5
   ;; If non nil, `helm' will try to minimize the space it uses. (default nil)
   dotspacemacs-helm-resize nil
   ;; if non nil, the helm header is hidden when there is only one source.
   ;; (default nil)
   dotspacemacs-helm-no-header nil
   ;; define the position to display `helm', options are `bottom', `top',
   ;; `left', or `right'. (default 'bottom)
   dotspacemacs-helm-position 'bottom
   ;; Controls fuzzy matching in helm. If set to `always', force fuzzy matching
   ;; in all non-asynchronous sources. If set to `source', preserve individual
   ;; source settings. Else, disable fuzzy matching in all sources.
   ;; (default 'always)
   dotspacemacs-helm-use-fuzzy nil
   ;; If non nil the paste micro-state is enabled. When enabled pressing `p`
   ;; several times cycle between the kill ring content. (default nil)
   dotspacemacs-enable-paste-transient-state nil
   ;; Which-key delay in seconds. The which-key buffer is the popup listing
   ;; the commands bound to the current keystroke sequence. (default 0.4)
   dotspacemacs-which-key-delay 0.4
   ;; Which-key frame position. Possible values are `right', `bottom' and
   ;; `right-then-bottom'. right-then-bottom tries to display the frame to the
   ;; right; if there is insufficient space it displays it at the bottom.
   ;; (default 'bottom)
   dotspacemacs-which-key-position 'bottom
   ;; If non nil a progress bar is displayed when spacemacs is loading. This
   ;; may increase the boot time on some systems and emacs builds, set it to
   ;; nil to boost the loading time. (default t)
   dotspacemacs-loading-progress-bar t
   ;; If non nil the frame is fullscreen when Emacs starts up. (default nil)
   ;; (Emacs 24.4+ only)
   dotspacemacs-fullscreen-at-startup nil
   ;; If non nil `spacemacs/toggle-fullscreen' will not use native fullscreen.
   ;; Use to disable fullscreen animations in OSX. (default nil)
   dotspacemacs-fullscreen-use-non-native nil
   ;; If non nil the frame is maximized when Emacs starts up.
   ;; Takes effect only if `dotspacemacs-fullscreen-at-startup' is nil.
   ;; (default nil) (Emacs 24.4+ only)
   dotspacemacs-maximized-at-startup nil
   ;; A value from the range (0..100), in increasing opacity, which describes
   ;; the transparency level of a frame when it's active or selected.
   ;; Transparency can be toggled through `toggle-transparency'. (default 90)
   dotspacemacs-active-transparency 90
   ;; A value from the range (0..100), in increasing opacity, which describes
   ;; the transparency level of a frame when it's inactive or deselected.
   ;; Transparency can be toggled through `toggle-transparency'. (default 90)
   dotspacemacs-inactive-transparency 90
   ;; If non nil show the titles of transient states. (default t)
   dotspacemacs-show-transient-state-title t
   ;; If non nil show the color guide hint for transient state keys. (default t)
   dotspacemacs-show-transient-state-color-guide t
   ;; If non nil unicode symbols are displayed in the mode line. (default t)
   dotspacemacs-mode-line-unicode-symbols t
   ;; If non nil smooth scrolling (native-scrolling) is enabled. Smooth
   ;; scrolling overrides the default behavior of Emacs which recenters point
   ;; when it reaches the top or bottom of the screen. (default t)
   dotspacemacs-smooth-scrolling t
   ;; If non nil line numbers are turned on in all `prog-mode' and `text-mode'
   ;; derivatives. If set to `relative', also turns on relative line numbers.
   ;; (default nil)
   dotspacemacs-line-numbers nil
   ;; Code folding method. Possible values are `evil' and `origami'.
   ;; (default 'evil)
   dotspacemacs-folding-method 'evil
   ;; If non-nil smartparens-strict-mode will be enabled in programming modes.
   ;; (default nil)
   dotspacemacs-smartparens-strict-mode nil
   ;; If non-nil pressing the closing parenthesis `)' key in insert mode passes
   ;; over any automatically added closing parenthesis, bracket, quote, etc…
   ;; This can be temporary disabled by pressing `C-q' before `)'. (default nil)
   dotspacemacs-smart-closing-parenthesis nil
   ;; Select a scope to highlight delimiters. Possible values are `any',
   ;; `current', `all' or `nil'. Default is `all' (highlight any scope and
   ;; emphasis the current one). (default 'all)
   dotspacemacs-highlight-delimiters 'all
   ;; If non nil, advise quit functions to keep server open when quitting.
   ;; (default nil)
   dotspacemacs-persistent-server nil
   ;; List of search tool executable names. Spacemacs uses the first installed
   ;; tool of the list. Supported tools are `ag', `pt', `ack' and `grep'.
   ;; (default '("ag" "pt" "ack" "grep"))
   dotspacemacs-search-tools '("ag" "pt" "ack" "grep")
   ;; The default package repository used if no explicit repository has been
   ;; specified with an installed package.
   ;; Not used for now. (default nil)
   dotspacemacs-default-package-repository nil
   ;; Delete whitespace while saving buffer. Possible values are `all'
   ;; to aggressively delete empty line and long sequences of whitespace,
   ;; `trailing' to delete only the whitespace at end of lines, `changed'to
   ;; delete only whitespace for changed lines or `nil' to disable cleanup.
   ;; (default nil)
   dotspacemacs-whitespace-cleanup nil
   ))

(defun dotspacemacs/user-init ()
  "Initialization function for user code.
It is called immediately after `dotspacemacs/init', before layer configuration
executes.
 This function is mostly useful for variables that need to be set
before packages are loaded. If you are unsure, you should try in setting them in
`dotspacemacs/user-config' first."
  )

(defun dotspacemacs/user-config ()
  "Configuration function for user code.
This function is called at the very end of Spacemacs initialization after
layers configuration.
This is the place where most of your configurations should be done. Unless it is
explicitly specified that a variable should be set before a package is loaded,
you should place your code here."
  (require 'org-tempo)
;;; Load customization settings

  (defvar running-alternate-emacs nil)


  ;; (if (memq major-mode dired-mode)
  ;;     (unbind-key "M-s f" dired-mode-map))

  (eval-after-load "dired" '(progn
                              (unbind-key "M-s f" dired-mode-map)))


  (bind-key "C-<escape>" 'mode-line-other-buffer)
  (bind-key "H-v" #'yank)
  (bind-key "C-c o" #'customize-option)
  (bind-key "C-x g" #'magit-status)

  (bind-key "C-c n" #'insert-user-timestamp)
  (bind-key "C-c o" #'customize-option)
  (bind-key "C-c O" #'customize-group)
  (bind-key "C-c F" #'customize-face)

  (bind-key "C-c q" #'fill-region)
  (bind-key "C-c r" #'replace-regexp)
  (bind-key "C-c s" #'replace-string)
  (bind-key "C-c u" #'rename-uniquely)

  (bind-key "C-c v" #'ffap)

  (bind-key* "<C-return>" #'other-window)


  (defun my-helm-do-grep ()
    (interactive)
    (helm-do-grep-1 (list default-directory)))

  (defun my-helm-do-grep-r ()
    (interactive)
    (helm-do-grep-1 (list default-directory) t))

  (bind-key "M-s f" #'my-helm-do-grep-r)
  (bind-key "M-s g" #'my-helm-do-grep)

;;; help-map

  (defvar lisp-find-map)
  (define-prefix-command 'lisp-find-map)

  (bind-key "C-h e" #'lisp-find-map)

  ;;; C-h e

  (bind-key "C-h e c" #'finder-commentary)
  (bind-key "C-h e e" #'view-echo-area-messages)
  (bind-key "C-h e f" #'find-function)
  (bind-key "C-h e F" #'find-face-definition)

  (bind-key "C-h e d" #'my-describe-symbol)
  (bind-key "C-h e i" #'info-apropos)
  (bind-key "C-h e k" #'find-function-on-key)
  (bind-key "C-h e l" #'find-library)

  ;; (bind-key "C-h e s" #'spacemacs/switch-to-scratch-buffer)
  (bind-key "C-h e s" #'scratch)
  (bind-key "C-h e v" #'find-variable)
  (bind-key "C-h e V" #'apropos-value)

  (defvar ctl-period-map)
  (define-prefix-command 'ctl-period-map)
  (bind-key "C-." #'ctl-period-map)

  ;; (bind-key* "<C-return>" #'other-window)

  (eval-after-load "dired" '(progn
                              (bind-key "l" #'dired-up-directory dired-mode-map)
                              (bind-key "e" #'dired-mark-files-containing-regexp dired-mode-map)))

  (add-hook 'doc-view-mode-hook 'auto-revert-mode)

  (use-package persistent-scratch
    :if (and window-system (not running-alternate-emacs)
             (not noninteractive)))

  (defvar lisp-modes '(emacs-lisp-mode
                       inferior-emacs-lisp-mode
                       ielm-mode
                       lisp-mode
                       inferior-lisp-mode
                       lisp-interaction-mode
                       slime-repl-mode))

  (defvar lisp-mode-hooks
    (mapcar (function
             (lambda (mode)
               (intern
                (concat (symbol-name mode) "-hook"))))
            lisp-modes))

  (defun scratch ()
    (interactive)
    (let ((current-mode major-mode))
      (switch-to-buffer-other-window (get-buffer-create "*scratch*"))
      (goto-char (point-min))
      (when (looking-at ";")
        (forward-line 4)
        (delete-region (point-min) (point)))
      (goto-char (point-max))
      (if (memq current-mode lisp-modes)
          (funcall current-mode))))


;;; Delayed configuration

  (use-package dot-org
  :load-path "~/.emacs.d"
  :ensure org-plus-contrib
  :commands my-org-startup
  :bind (("M-C"   . jump-to-org-agenda)
         ("H-M-S-RET" . org-smart-capture)
         ("M-M"   . org-inline-note)
         ("C-c a" . org-agenda)
         ("C-c S" . org-store-link)
         ("C-c l" . org-insert-link)
         ("C-. n" . org-velocity-read))
  :defer 30
  :config
    (my-org-startup))

  (defun web-mode-hook ()
    "Hooks for Web mode."
    ;;indent
    (setq web-mode-attr-indent-offset 2)
    (setq web-mode-markup-indent-offset 2)
    (setq web-mode-css-indent-offset 2)
    (setq web-mode-code-indent-offset 2)

    (setq web-mode-enable-auto-pairing t)
    (setq web-mode-enable-css-colorization t)

    (setq web-mode-enable-comment-keywords t)
    (setq web-mode-enable-current-column-highlight t)
    (setq web-mode-enable-current-element-highlight t)
    (setq web-mode-enable-element-tag-fontification t)

    ;; (local-set-key (kbd "RET") 'indent-and-newline)
    )
  (add-hook 'web-mode-hook  'web-mode-hook)

  ;; (use-package dired-sidebar
  ;;   :ensure t
  ;;   :commands (dired-sidebar-toggle-sidebar))

  (use-package dired-sidebar
    :bind (("C-x C-n" . dired-sidebar-toggle-sidebar))
    :ensure t
    :commands (dired-sidebar-toggle-sidebar)
    :init
    (add-hook 'dired-sidebar-mode-hook
              (lambda ()
                (unless (file-remote-p default-directory)
                  (auto-revert-mode))))
    :config
    (push 'toggle-window-split dired-sidebar-toggle-hidden-commands)
    (push 'rotate-windows dired-sidebar-toggle-hidden-commands)

    (setq dired-sidebar-subtree-line-prefix "__")
    (setq dired-sidebar-theme 'vscode)
    (setq dired-sidebar-use-term-integration t)
    (setq dired-sidebar-use-custom-font t))

  (eval-after-load 'drupal-mode
    '(progn
       (add-hook 'drupal-mode-hook
                 '(lambda ()
                    (yas-activate-extra-mode 'drupal-mode)))))

  (use-package dockerfile-mode
                :mode "Dockerfile\\'"
                :config
                (put 'dockerfile-image-name 'safe-local-variable #'stringp)
                )

  ;; (use-package docker
  ;;   :ensure t
  ;;   :bind ("C-c d" . docker))

  ;; https://github.com/Silex/docker.el
  (use-package docker
    :ensure t
    :bind ("C-c d" . docker)
    :custom (docker-image-run-arguments '("-i" "-t" "--rm")))

  ;; (use-package docker-compose-mode)

  ;; (use-package eshell-bookmark
  ;;   :after eshell
  ;;   :config
  ;;   (add-hook 'eshell-mode-hook #'eshell-bookmark-setup))

  (use-package ivy
    :diminish
    :disabled t
    :demand t

    :bind (("C-x b" . ivy-switch-buffer)
           ("C-x B" . ivy-switch-buffer-other-window)
           ("M-H"   . ivy-resume))

    :bind (:map ivy-minibuffer-map
                ("<tab>" . ivy-alt-done)
                ("SPC"   . ivy-alt-done-or-space)
                ("C-d"   . ivy-done-or-delete-char)
                ("C-i"   . ivy-partial-or-done)
                ("C-r"   . ivy-previous-line-or-history)
                ("M-r"   . ivy-reverse-i-search))

    :bind (:map ivy-switch-buffer-map
                ("C-k" . ivy-switch-buffer-kill))

    :custom
    (ivy-dynamic-exhibit-delay-ms 200)
    (ivy-height 10)
    (ivy-initial-inputs-alist nil t)
    (ivy-magic-tilde nil)
    (ivy-re-builders-alist '((t . ivy--regex-ignore-order)))
    (ivy-use-virtual-buffers t)
    (ivy-wrap t)

    :preface
    (defun ivy-done-or-delete-char ()
      (interactive)
      (call-interactively
       (if (eolp)
           #'ivy-immediate-done
         #'ivy-delete-char)))

    (defun ivy-alt-done-or-space ()
      (interactive)
      (call-interactively
       (if (= ivy--length 1)
           #'ivy-alt-done
         #'self-insert-command)))

    (defun ivy-switch-buffer-kill ()
      (interactive)
      (debug)
      (let ((bn (ivy-state-current ivy-last)))
        (when (get-buffer bn)
          (kill-buffer bn))
        (unless (buffer-live-p (ivy-state-buffer ivy-last))
          (setf (ivy-state-buffer ivy-last)
                (with-ivy-window (current-buffer))))
        (setq ivy--all-candidates (delete bn ivy--all-candidates))
        (ivy--exhibit)))

    ;; This is the value of `magit-completing-read-function', so that we see
    ;; Magit's own sorting choices.
    (defun my-ivy-completing-read (&rest args)
      (let ((ivy-sort-functions-alist '((t . nil))))
        (apply 'ivy-completing-read args)))

    :config
    (ivy-mode 1)
    (ivy-set-occur 'ivy-switch-buffer 'ivy-switch-buffer-occur))

  (use-package ivy-bibtex
    :commands ivy-bibtex)

  (use-package ivy-hydra
    :after (ivy hydra)
    :defer t)

  (use-package ivy-pass
    :commands ivy-pass)

  (use-package ivy-rich
    :disabled t
    :after ivy
    :demand t
    :config
    (ivy-rich-mode 1)
    (setq ivy-virtual-abbreviate 'full
          ivy-rich-switch-buffer-align-virtual-buffer t
          ivy-rich-path-style 'abbrev))

  (use-package ivy-rtags
    :disabled t
    :load-path "~/.nix-profile/share/emacs/site-lisp/rtags"
    :after (ivy rtags))

  (use-package shift-text
    :commands (shfit-text-right shfit-text-left shift-text-up shift-text-down)
    :bind (("<M-right>" . shift-text-right)
           ("<M-left>" .  shift-text-left)
           ("<M-up>" .  shift-text-up)
           ("<M-down>" .  shift-text-down)))

  (use-package vscode-icon
    :ensure t
    :commands (vscode-icon-for-file))

  (use-package yasnippet
    :demand t
    :diminish yas-minor-mode
    :commands (yas-expand yas-minor-mode)
    :functions (yas-guess-snippet-directories yas-table-name)
    :defines (yas-guessed-modes)
    :mode ("/\\.emacs\\.d/snippets/" . snippet-mode)
    :bind (("C-c y TAB" . yas-expand)
           ("C-c y s"   . yas-insert-snippet)
           ("C-c y n"   . yas-new-snippet)
           ("C-c y v"   . yas-visit-snippet-file))
    :preface
    (defun yas-new-snippet (&optional choose-instead-of-guess)
      (interactive "P")
      (let ((guessed-directories (yas-guess-snippet-directories)))
        (switch-to-buffer "*new snippet*")
        (erase-buffer)
        (kill-all-local-variables)
        (snippet-mode)
        (set (make-local-variable 'yas-guessed-modes)
             (mapcar #'(lambda (d) (intern (yas-table-name (car d))))
                     guessed-directories))
        (unless (and choose-instead-of-guess
                     (not (y-or-n-p "Insert a snippet with useful headers? ")))
          (yas-expand-snippet
           (concat "\n"
                   "# -*- mode: snippet -*-\n"
                   "# name: $1\n"
                   "# --\n"
                   "$0\n")))))

    :config
    (yas-load-directory "~/.emacs.d/snippets/")
    (yas-global-mode 1)

    (bind-key "C-i" #'yas-next-field-or-maybe-expand yas-keymap))

  ;; (use-package projectile-drupal
  ;;   :load-path "~/.emacs.d/lisp/projectile-drupal"

  ;;   :init
  ;;   (progn
  ;;     (defun dkh-get-site-name ()
  ;;       "Gets site name based on University WWNG standard or standalone."
  ;;       (if (locate-dominating-file default-directory
  ;;                                   "current")
  ;;           (let* ((project-root-dir (locate-dominating-file default-directory
  ;;                                                            "current"))
  ;;                  (path (split-string project-root-dir "/")))     ; path as list
  ;;             (car (last (nbutlast path 1))))
  ;;         (projectile-project-name)))

  ;;     (defun dkh-get-base-url ()
  ;;       "Gets the projectile-drupal-base-url based on University WWNG standard or standalone."
  ;;       (let* ((uri
  ;;               (if (equal projectile-drupal-site-name "admissions_undergraduate")
  ;;                   "ww/admissions/undergraduate"
  ;;                 (concat "colorado.dev/" projectile-drupal-site-name))))
  ;;         (concat "http://" uri)))

  ;;     (bind-key "C-H-M-<" 'projectile-switch-to-prev-buffer)
  ;;     (bind-key "C-H-M->" 'projectile-switch-to-next-buffer)
  ;;     (bind-key "C-H-M-p" 'revert-buffer)
  ;;     (bind-key "C-H-M-\"" 'kill-buffer)))

  (bind-key "<H-down>" #'shrink-window)
  (bind-key "<H-left>" #'shrink-window-horizontally)
  (bind-key "<H-right>" #'enlarge-window-horizontally)
  (bind-key "<H-up>" #'enlarge-window)
  (bind-key "H-`" #'make-frame)
  (bind-key "M-`" #'other-frame)

  (eval-when-compile
    (defvar emacs-min-height)
    (defvar emacs-min-width))

  (defvar display-name
    (let ((width (display-pixel-width)))
      (cond ((>= width 2560) 'retina-imac)
            ((= width 1440) 'retina-macbook-pro))))

  (defvar emacs-min-top 23)
  (defvar emacs-min-left
    (cond ((eq display-name 'retina-imac) 975)
          (t 521)))
  (defvar emacs-min-height
    (cond ((eq display-name 'retina-imac) 57)
          (t 44)))
  (defvar emacs-min-width 100)

  (if running-alternate-emacs
      (setq emacs-min-top 22
            emacs-min-left 5
            emacs-min-height 57
            emacs-min-width 90))

  (defvar emacs-min-font
    (cond
     ((eq display-name 'retina-imac)
      (if running-alternate-emacs
          "-*-Myriad Pro-normal-normal-normal-*-20-*-*-*-p-0-iso10646-1"
        ;; "-*-Source Code Pro-normal-normal-normal-*-20-*-*-*-m-0-iso10646-1"
        "-*-Hack-normal-normal-normal-*-18-*-*-*-m-0-iso10646-1"
        ))
     ((string= (system-name) "ubuntu")
      ;; "-*-Source Code Pro-normal-normal-normal-*-20-*-*-*-m-0-iso10646-1"
      "-*-Hack-normal-normal-normal-*-14-*-*-*-m-0-iso10646-1"
      )
     (t
      (if running-alternate-emacs
          "-*-Myriad Pro-normal-normal-normal-*-17-*-*-*-p-0-iso10646-1"
        ;; "-*-Source Code Pro-normal-normal-normal-*-15-*-*-*-m-0-iso10646-1"
        "-*-Hack-normal-normal-normal-*-14-*-*-*-m-0-iso10646-1"
        ))))

  (let ((frame-alist
         (list (cons 'top    emacs-min-top)
               (cons 'left   emacs-min-left)
               (cons 'height emacs-min-height)
               (cons 'width  emacs-min-width)
               (cons 'font   emacs-min-font))))
    (setq initial-frame-alist frame-alist))

  (defun emacs-min ()
    (interactive)

    (set-frame-parameter (selected-frame) 'fullscreen nil)
    (set-frame-parameter (selected-frame) 'vertical-scroll-bars nil)
    (set-frame-parameter (selected-frame) 'horizontal-scroll-bars nil)

    (set-frame-parameter (selected-frame) 'top emacs-min-top)
    (set-frame-parameter (selected-frame) 'left emacs-min-left)
    (set-frame-parameter (selected-frame) 'height emacs-min-height)
    (set-frame-parameter (selected-frame) 'width emacs-min-width)

    (set-frame-font emacs-min-font))

  (if window-system
      (add-hook 'after-init-hook 'emacs-min))

  (defun emacs-max ()
    (interactive)
    (set-frame-parameter (selected-frame) 'fullscreen 'fullboth)
    (set-frame-parameter (selected-frame) 'vertical-scroll-bars nil)
    (set-frame-parameter (selected-frame) 'horizontal-scroll-bars nil))

  (defun emacs-toggle-size ()
    (interactive)
    (if (> (cdr (assq 'width (frame-parameters))) 100)
        (emacs-min)
      (emacs-max)))

  (bind-key "C-c m" #'emacs-toggle-size)


  (dolist
      (r `((?i (file . "~/.spacemacs"))
           ;; (?a (file . "~/.emacs.d/.abbrev_defs"))
           (?a (file . "~/Box/projects/ace_communications/website_administration_and_deployment_charter.org"))
           (?b (file . "~/.profile"))
           (?B (file . "~/.bashrc"))
           (?e (file . "~/"))
           (?t (file . "/Users/dhaley/Box/projects/todo.txt"))
           (?s (file . "~/.emacs.d/settings.el"))
           (?o (file . "~/.emacs.d/dot-org.el"))
           (?g (file . "~/.emacs.d/dot-gnus.el"))
           (?O (file . "~/.emacs.d/org-settings.el"))
           (?r (file . "~/src/drupal_scripts/release.sh"))
           (?G (file . "~/.emacs.d/gnus-settings.el"))
           (?u (file . "~/.emacs.d/site-lisp/xmsi-math-symbols-input.el"))
           (?z (file . "~/.zshrc"))
           (?h (file . "~/Box/projects/computational-science-general-home-page.org"))
           (?S (file . "~/Box/projects/standup.org"))
           ))
    (set-register (car r) (cadr r)))

  (setq w3m-home-page "https://www.google.com")
  ;; W3M Home Page
  (setq w3m-default-display-inline-images t)
  (setq w3m-default-toggle-inline-images t)
  ;; W3M default display images
  (setq w3m-command-arguments '("-cookie" "-F"))
  (setq w3m-use-cookies t)
  ;; W3M use cookies
  (setq browse-url-browser-function 'w3m-browse-url)
  ;; Browse url function use w3m
  (setq w3m-view-this-url-new-session-in-background t)
  ;; W3M view url new session in background
  )




;; Do not write anything past this comment. This is where Emacs will
;; auto-generate custom variable definitions.


(defun dotspacemacs/emacs-custom-settings ()
  "Emacs custom settings.
This is an auto-generated function, do not modify its content directly, use
Emacs customize menu instead.
This function is called at the very end of Spacemacs initialization."
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(bmkp-last-as-first-bookmark-file "/Users/dhaley/spacemacs/.emacs.d/.cache/bookmarks")
 '(browse-url-browser-function (quote browse-url-default-browser))
 '(custom-safe-themes
   (quote
    ("285d1bf306091644fb49993341e0ad8bafe57130d9981b680c1dbd974475c5c7" "51ec7bfa54adf5fff5d466248ea6431097f5a18224788d0bd7eb1257a4f7b773" "76c5b2592c62f6b48923c00f97f74bcb7ddb741618283bdb2be35f3c0e1030e3" "732b807b0543855541743429c9979ebfb363e27ec91e82f463c91e68c772f6e3" "a24c5b3c12d147da6cef80938dca1223b7c7f70f2f382b26308eba014dc4833a" "2809bcb77ad21312897b541134981282dc455ccd7c14d74cc333b6e549b824f3" "7023f8768081cd1275f7fd1cd567277e44402c65adfe4dc10a3a908055ed634d" "fa2b58bb98b62c3b8cf3b6f02f058ef7827a8e497125de0254f56e373abee088" "c1fb68aa00235766461c7e31ecfc759aa2dd905899ae6d95097061faeb72f9ee" "c433c87bd4b64b8ba9890e8ed64597ea0f8eb0396f4c9a9e01bd20a04d15d358" "00445e6f15d31e9afaa23ed0d765850e9cd5e929be5e8e63b114a3346236c44c" "7aaee3a00f6eb16836f5b28bdccde9e1079654060d26ce4b8f49b56689c51904" "7f1d414afda803f3244c6fb4c2c64bea44dac040ed3731ec9d75275b9e831fe5" "621595cbf6c622556432e881945dda779528e48bb57107b65d428e61a8bb7955" default)))
 '(docker-image-run-arguments (quote ("-i" "-t" "--rm")) t)
 '(evil-want-Y-yank-to-eol nil)
 '(hl-todo-keyword-faces
   (quote
    (("TODO" . "#dc752f")
     ("NEXT" . "#dc752f")
     ("THEM" . "#2d9574")
     ("PROG" . "#3a81c3")
     ("OKAY" . "#3a81c3")
     ("DONT" . "#f2241f")
     ("FAIL" . "#f2241f")
     ("DONE" . "#42ae2c")
     ("NOTE" . "#b1951d")
     ("KLUDGE" . "#b1951d")
     ("HACK" . "#b1951d")
     ("TEMP" . "#b1951d")
     ("FIXME" . "#dc752f")
     ("XXX+" . "#dc752f")
     ("\\?\\?\\?+" . "#dc752f"))))
 '(mac-command-modifier (quote hyper))
 '(mac-function-modifier (quote hyper))
 '(mac-option-modifier (quote meta))
 '(mac-pass-command-to-system nil)
 '(magit-auto-revert-mode nil)
 '(magit-completing-read-function (quote my-ivy-completing-read))
 '(magit-diff-options nil)
 '(magit-fetch-arguments nil)
 '(magit-highlight-trailing-whitespace nil)
 '(magit-highlight-whitespace nil)
 '(magit-log-section-commit-count 10)
 '(magit-pre-refresh-hook nil)
 '(magit-process-popup-time 15)
 '(magit-push-always-verify nil)
 '(magit-refresh-status-buffer nil)
 '(magit-stage-all-confirm nil)
 '(magit-unstage-all-confirm nil)
 '(magit-use-overlays nil)
 '(org-M-RET-may-split-line (quote ((headline) (default . t))))
 '(org-adapt-indentation nil)
 '(org-agenda-auto-exclude-function (quote org-my-auto-exclude-function))
 '(org-agenda-clock-consistency-checks
   (quote
    (:max-duration "4:00" :min-duration 0 :max-gap 0 :gap-ok-around
                   ("4:00"))))
 '(org-agenda-clockreport-parameter-plist
   (quote
    (:link t :maxlevel 5 :fileskip0 t :compact t :narrow 80)))
 '(org-agenda-cmp-user-defined (quote bh/agenda-sort))
 '(org-agenda-compact-blocks t)
 '(org-agenda-custom-commands
   (quote
    (("N" "Notes" tags "NOTE"
      ((org-agenda-overriding-header "Notes")
       (org-tags-match-list-sublevels t)))
     ("h" "Habits" tags-todo "STYLE=\"habit\""
      ((org-agenda-overriding-header "Habits")
       (org-agenda-sorting-strategy
        (quote
         (todo-state-down effort-up category-keep)))))
     (" " "Agenda"
      ((agenda "" nil)
       (tags "REFILE"
             ((org-agenda-overriding-header "Tasks to Refile")
              (org-tags-match-list-sublevels nil)))
       (tags-todo "-CANCELLED/!"
                  ((org-agenda-overriding-header "Stuck Projects")
                   (org-agenda-skip-function
                    (quote bh/skip-non-stuck-projects))
                   (org-agenda-sorting-strategy
                    (quote
                     (category-keep)))))
       (tags-todo "-HOLD-CANCELLED/!"
                  ((org-agenda-overriding-header "Projects")
                   (org-agenda-skip-function
                    (quote bh/skip-non-projects))
                   (org-tags-match-list-sublevels
                    (quote indented))
                   (org-agenda-sorting-strategy
                    (quote
                     (category-keep)))))
       (tags-todo "-CANCELLED/!NEXT"
                  ((org-agenda-overriding-header
                    (concat "Project Next Tasks"
                            (if bh/hide-scheduled-and-waiting-next-tasks "" " (including WAITING and SCHEDULED tasks)")))
                   (org-agenda-skip-function
                    (quote bh/skip-projects-and-habits-and-single-tasks))
                   (org-tags-match-list-sublevels t)
                   (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-sorting-strategy
                    (quote
                     (todo-state-down effort-up category-keep)))))
       (tags-todo "-REFILE-CANCELLED-WAITING-HOLD/!"
                  ((org-agenda-overriding-header
                    (concat "Project Subtasks"
                            (if bh/hide-scheduled-and-waiting-next-tasks "" " (including WAITING and SCHEDULED tasks)")))
                   (org-agenda-skip-function
                    (quote bh/skip-non-project-tasks))
                   (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-sorting-strategy
                    (quote
                     (category-keep)))))
       (tags-todo "-REFILE-CANCELLED-WAITING-HOLD/!"
                  ((org-agenda-overriding-header
                    (concat "Standalone Tasks"
                            (if bh/hide-scheduled-and-waiting-next-tasks "" " (including WAITING and SCHEDULED tasks)")))
                   (org-agenda-skip-function
                    (quote bh/skip-project-tasks))
                   (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-todo-ignore-with-date bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-sorting-strategy
                    (quote
                     (category-keep)))))
       (tags-todo "-CANCELLED+WAITING|HOLD/!"
                  ((org-agenda-overriding-header
                    (concat "Waiting and Postponed Tasks"
                            (if bh/hide-scheduled-and-waiting-next-tasks "" " (including WAITING and SCHEDULED tasks)")))
                   (org-agenda-skip-function
                    (quote bh/skip-non-tasks))
                   (org-tags-match-list-sublevels nil)
                   (org-agenda-todo-ignore-scheduled bh/hide-scheduled-and-waiting-next-tasks)
                   (org-agenda-todo-ignore-deadlines bh/hide-scheduled-and-waiting-next-tasks)))
       (tags "-REFILE/"
             ((org-agenda-overriding-header "Tasks to Archive")
              (org-agenda-skip-function
               (quote bh/skip-non-archivable-tasks))
              (org-tags-match-list-sublevels nil))))
      nil))))
 '(org-agenda-deadline-leaders (quote ("!D!: " "D%02d: ")))
 '(org-agenda-default-appointment-duration 60)
 '(org-agenda-diary-file "/Users/dhaley/Box/projects/diary.org")
 '(org-agenda-dim-blocked-tasks nil)
 '(org-agenda-exporter-settings
   (quote
    ((org-agenda-write-buffer-name "Damon's VC-Rsrch/Dean-Grad Agenda"))))
 '(org-agenda-files
   (quote
    ("/Users/dhaley/Box/projects/todo.txt" "/Users/dhaley/Box/projects/from-mobile.org")))
 '(org-agenda-fontify-priorities t)
 '(org-agenda-include-diary t)
 '(org-agenda-inhibit-startup t)
 '(org-agenda-insert-diary-extract-time t)
 '(org-agenda-log-mode-items (quote (closed clock state)))
 '(org-agenda-ndays 1)
 '(org-agenda-persistent-filter t)
 '(org-agenda-prefix-format
   (quote
    ((agenda . "  %-11c%?-12t% s")
     (timeline . "  % s")
     (todo . "  %-11c")
     (tags . "  %-11c"))))
 '(org-agenda-repeating-timestamp-show-all t)
 '(org-agenda-restriction-lock-highlight-subtree nil)
 '(org-agenda-scheduled-leaders (quote ("" "S%d: ")))
 '(org-agenda-scheduled-relative-text "S%d: ")
 '(org-agenda-scheduled-text "")
 '(org-agenda-show-all-dates t)
 '(org-agenda-skip-additional-timestamps-same-entry t)
 '(org-agenda-skip-deadline-if-done t)
 '(org-agenda-skip-scheduled-if-deadline-is-shown t)
 '(org-agenda-skip-scheduled-if-done t)
 '(org-agenda-skip-timestamp-if-done t)
 '(org-agenda-skip-unavailable-files t)
 '(org-agenda-sorting-strategy
   (quote
    ((agenda habit-down time-up user-defined-up effort-up category-keep)
     (todo category-up effort-up)
     (tags category-up effort-up)
     (search category-up))))
 '(org-agenda-span (quote day))
 '(org-agenda-start-on-weekday nil)
 '(org-agenda-start-with-log-mode nil)
 '(org-agenda-sticky t)
 '(org-agenda-tags-column -100)
 '(org-agenda-tags-todo-honor-ignore-options t)
 '(org-agenda-text-search-extra-files (quote (agenda-archives)))
 '(org-agenda-time-grid
   (quote
    ((daily today remove-match)
     #("----------------" 0 16
       (org-heading t))
     (900 1100 1300 1500 1700))))
 '(org-agenda-todo-ignore-with-date nil)
 '(org-agenda-use-time-grid nil)
 '(org-agenda-window-setup (quote current-window))
 '(org-archive-location "%s_archive::* Archived Tasks")
 '(org-archive-save-context-info (quote (time category itags)))
 '(org-attach-method (quote mv))
 '(org-babel-load-languages
   (quote
    ((php . t)
     (python . t)
     (js . t)
     (ruby . t)
     (shell . t)
     (sql . t)
     (emacs-lisp . t))))
 '(org-babel-results-keyword "results")
 '(org-beamer-frame-default-options "fragile")
 '(org-blank-before-new-entry (quote ((heading) (plain-list-item . auto))))
 '(org-capture-templates
   (quote
    (("t" "Task" entry
      (file+headline "/Users/dhaley/Box/projects/todo.txt" "Inbox")
      "* TODO %?
SCHEDULED: %t
:PROPERTIES:
:ID:       %(shell-command-to-string \"uuidgen\"):CREATED:  %U
:END:" :prepend t))))
 '(org-catch-invisible-edits (quote error))
 '(org-clock-auto-clock-resolution (quote when-no-clock-is-running))
 '(org-clock-clocked-in-display nil)
 '(org-clock-history-length 23)
 '(org-clock-idle-time 10)
 '(org-clock-in-resume t)
 '(org-clock-in-switch-to-state (quote bh/clock-in-to-next))
 '(org-clock-into-drawer t)
 '(org-clock-mode-line-total (quote current))
 '(org-clock-out-remove-zero-time-clocks t)
 '(org-clock-out-switch-to-state nil)
 '(org-clock-out-when-done t)
 '(org-clock-persist t)
 '(org-clock-persist-file "~/.emacs.d/data/org-clock-save.el")
 '(org-clock-persist-query-resume nil)
 '(org-clock-report-include-clocking-task t)
 '(org-clock-resolve-expert t)
 '(org-clock-sound "/usr/local/lib/tngchime.wav")
 '(org-clone-delete-id t)
 '(org-columns-default-format
   "%80ITEM(Task) %10Effort(Effort){:} %10Confidence(Confidence) %10CLOCKSUM")
 '(org-completion-use-ido t)
 '(org-confirm-babel-evaluate nil)
 '(org-confirm-elisp-link-function nil)
 '(org-confirm-shell-link-function nil)
 '(org-crypt-disable-auto-save nil)
 '(org-crypt-key "F0B66B40")
 '(org-cycle-global-at-bob t)
 '(org-cycle-include-plain-lists t)
 '(org-cycle-separator-lines 0)
 '(org-deadline-warning-days 14)
 '(org-default-notes-file "/Users/dhaley/Box/projects/todo.txt")
 '(org-default-priority 69)
 '(org-directory "/Users/dhaley/Box/projects")
 '(org-ditaa-jar-path "~/bin/DitaaEps/DitaaEps.jar")
 '(org-edit-src-content-indentation 0)
 '(org-emphasis-alist
   (quote
    (("*" bold "<b>" "</b>")
     ("/" italic "<i>" "</i>")
     ("_" underline "<span style=\"text-decoration:underline;\">" "</span>")
     ("=" org-code "<code>" "</code>" verbatim)
     ("~" org-verbatim "<code>" "</code>" verbatim))))
 '(org-enable-bootstrap-support t t)
 '(org-enable-github-support t t)
 '(org-enable-priority-commands t)
 '(org-enforce-todo-dependencies t)
 '(org-export-allow-BIND t)
 '(org-export-html-inline-images t)
 '(org-export-html-style-extra
   "<link rel=\"stylesheet\" href=\"http://doc.norang.ca/org.css\" type=\"text/css\" />")
 '(org-export-html-style-include-default nil)
 '(org-export-html-xml-declaration
   (quote
    (("html" . "")
     ("was-html" . "<?xml version=\"1.0\" encoding=\"%s\"?>")
     ("php" . "<?php echo \"<?xml version=\\\"1.0\\\" encoding=\\\"%s\\\" ?>\"; ?>"))))
 '(org-export-htmlize-output-type (quote css))
 '(org-export-latex-classes
   (quote
    (("article" "\\documentclass[11pt]{article}"
      ("\\section{%s}" . "\\section*{%s}")
      ("\\subsection{%s}" . "\\subsection*{%s}")
      ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
      ("\\paragraph{%s}" . "\\paragraph*{%s}")
      ("\\subparagraph{%s}" . "\\subparagraph*{%s}"))
     ("linalg" "\\documentclass{article}
\\usepackage{linalgjh}
[DEFAULT-PACKAGES]
[EXTRA]
`[PACKAGES]"
      ("\\section{%s}" . "\\section*{%s}")
      ("\\subsection{%s}" . "\\subsection*{%s}")
      ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
      ("\\paragraph{%s}" . "\\paragraph*{%s}")
      ("\\subparagraph{%s}" . "\\subparagraph*{%s}"))
     ("report" "\\documentclass[11pt]{report}"
      ("\\part{%s}" . "\\part*{%s}")
      ("\\chapter{%s}" . "\\chapter*{%s}")
      ("\\section{%s}" . "\\section*{%s}")
      ("\\subsection{%s}" . "\\subsection*{%s}")
      ("\\subsubsection{%s}" . "\\subsubsection*{%s}"))
     ("book" "\\documentclass[11pt]{book}"
      ("\\part{%s}" . "\\part*{%s}")
      ("\\chapter{%s}" . "\\chapter*{%s}")
      ("\\section{%s}" . "\\section*{%s}")
      ("\\subsection{%s}" . "\\subsection*{%s}")
      ("\\subsubsection{%s}" . "\\subsubsection*{%s}"))
     ("beamer" "\\documentclass{beamer}" org-beamer-sectioning))))
 '(org-export-latex-listings t)
 '(org-export-use-babel nil)
 '(org-export-with-section-numbers nil)
 '(org-export-with-sub-superscripts (quote {}))
 '(org-export-with-timestamps nil)
 '(org-extend-today-until 7)
 '(org-fast-tag-selection-single-key (quote expert))
 '(org-file-apps
   (quote
    ((auto-mode . emacs)
     ("\\.mm\\'" . system)
     ("\\.x?html?\\'" . system)
     ("\\.pdf\\'" . system))))
 '(org-fontify-done-headline t)
 '(org-footnote-section nil)
 '(org-global-properties
   (quote
    (("Effort_ALL" . "0:15 0:30 0:45 1:00 2:00 3:00 4:00 5:00 6:00 0:00")
     ("Confidence_ALL" . "low medium high")
     ("STYLE_ALL" . "habit"))))
 '(org-habit-graph-column 50)
 '(org-habit-preceding-days 42)
 '(org-habit-today-glyph 45)
 '(org-hide-leading-stars t)
 '(org-html-checkbox-type "unicode")
 '(org-id-link-to-org-use-id (quote create-if-interactive-and-no-custom-id))
 '(org-id-locations-file "~/.emacs.d/data/org-id-locations")
 '(org-id-method (quote uuidgen))
 '(org-image-actual-width (quote (800)))
 '(org-indirect-buffer-display (quote current-window))
 '(org-insert-heading-respect-content t)
 '(org-irc-link-to-logs t t)
 '(org-latex-default-packages-alist
   (quote
    (("T1" "fontenc" t)
     ("" "fixltx2e" nil)
     ("" "graphicx" t)
     ("" "longtable" nil)
     ("" "float" nil)
     ("" "wrapfig" nil)
     ("" "rotating" nil)
     ("normalem" "ulem" t)
     ("" "amsmath" t)
     ("" "textcomp" t)
     ("" "marvosym" t)
     ("" "wasysym" t)
     ("" "amssymb" t)
     ("" "hyperref" nil)
     "\\tolerance=1000")))
 '(org-link-abbrev-alist
   (quote
    (("gmail" . "https://mail.google.com/mail/u/0/#all/%s")
     ("google" . "http://www.google.com/search?q=%s")
     ("map" . "http://maps.google.com/maps?q=%s")
     ("github_nrel" . "https://github.nrel.gov")
     ("github" . "https://github.com")
     ("ndg" . "https://github.nrel.gov/NrelDrupal/%s"))))
 '(org-link-frame-setup
   (quote
    ((vm . vm-visit-folder)
     (gnus . org-gnus-no-new-news)
     (file . find-file))))
 '(org-link-mailto-program (quote (compose-mail "%a" "%s")))
 '(org-list-allow-alphabetical t)
 '(org-list-demote-modify-bullet
   (quote
    (("+" . "-")
     ("*" . "-")
     ("1." . "-")
     ("1)" . "-")
     ("A)" . "-")
     ("B)" . "-")
     ("a)" . "-")
     ("b)" . "-")
     ("A." . "-")
     ("B." . "-")
     ("a." . "-")
     ("b." . "-"))))
 '(org-log-done (quote time))
 '(org-log-into-drawer t)
 '(org-log-state-notes-insert-after-drawers nil)
 '(org-lowest-priority 69)
 '(org-mobile-agendas (quote ("Z")))
 '(org-mobile-directory "~/Dropbox/Apps/MobileOrg")
 '(org-mobile-files (quote ("/Users/dhaley/Box/projects/todo.txt")))
 '(org-mobile-files-exclude-regexp "\\(TODO\\(-.*\\)?\\)\\'")
 '(org-mobile-inbox-for-pull "/Users/dhaley/Box/projects/from-mobile.org")
 '(org-modules
   (quote
    (org-gnus org-id org-info org-habit org-depend org-tempo)))
 '(org-odd-levels-only nil)
 '(org-outline-path-complete-in-steps nil)
 '(org-plantuml-jar-path nil)
 '(org-priority-faces
   (quote
    ((65 :foreground "ForestGreen" :weight bold)
     (67 :foreground "dark gray" :slant italic))))
 '(org-refile-allow-creating-parent-nodes (quote confirm))
 '(org-refile-target-verify-function (quote bh/verify-refile-target))
 '(org-refile-targets
   (quote
    ((nil :maxlevel . 9)
     (org-agenda-files :maxlevel . 9))))
 '(org-refile-use-outline-path t)
 '(org-remove-highlights-with-change t)
 '(org-return-follows-link t)
 '(org-reveal-root "/Users/dhaley/src/reveal.js/js/reveal.js")
 '(org-reverse-note-order t)
 '(org-special-ctrl-a/e (quote reversed))
 '(org-special-ctrl-k t)
 '(org-speed-commands-user
   (quote
    (("0" . ignore)
     ("1" . ignore)
     ("2" . ignore)
     ("3" . ignore)
     ("4" . ignore)
     ("5" . ignore)
     ("6" . ignore)
     ("7" . ignore)
     ("8" . ignore)
     ("9" . ignore)
     ("a" . ignore)
     ("d" . ignore)
     ("h" . bh/hide-other)
     ("i" progn
      (forward-char 1)
      (call-interactively
       (quote org-insert-heading-respect-content)))
     ("k" . org-kill-note-or-show-branches)
     ("l" . ignore)
     ("m" . ignore)
     ("q" . bh/show-org-agenda)
     ("r" . ignore)
     ("s" . org-save-all-org-buffers)
     ("w" . org-refile)
     ("x" . ignore)
     ("y" . ignore)
     ("z" . org-add-note)
     ("A" . ignore)
     ("B" . ignore)
     ("E" . ignore)
     ("F" . bh/restrict-to-file-or-follow)
     ("G" . ignore)
     ("H" . ignore)
     ("J" . org-clock-goto)
     ("K" . ignore)
     ("L" . ignore)
     ("M" . ignore)
     ("N" . bh/narrow-to-org-subtree)
     ("P" . bh/narrow-to-org-project)
     ("Q" . ignore)
     ("R" . ignore)
     ("S" . ignore)
     ("T" . bh/org-todo)
     ("U" . bh/narrow-up-one-org-level)
     ("V" . ignore)
     ("W" . bh/widen)
     ("X" . ignore)
     ("Y" . ignore)
     ("Z" . ignore))))
 '(org-src-fontify-natively t)
 '(org-src-preserve-indentation nil)
 '(org-src-window-setup (quote current-window))
 '(org-startup-folded t)
 '(org-startup-indented t)
 '(org-startup-with-inline-images nil)
 '(org-structure-template-alist
   (quote
    (("a" . "export ascii")
     ("C" . "comment")
     ("E" . "export")
     ("c" . "center")
     ("ditaa" . "src ditaa :file")
     ("dot" . "src dot :file")
     ("e" . "example")
     ("el" . "src emacs-lisp")
     ("h" . "export html")
     ("hs" . "src haskell")
     ("http" . "src http")
     ("ipy" . "src ipython :results output")
     ("js" . "src js")
     ("l" . "export latex")
     ("laeq" . "latex 
\\begin{equation} \\label{eq-sinh}
y=\\sinh x
\\end{equation}")
     ("n" . "notes")
     ("plantuml" . "src plantuml :file")
     ("py" . "src python :results output")
     ("q" . "quote")
     ("r" . "src R")
     ("rp" . "src R :results output graphics :file ")
     ("s" . "src")
     ("v" . "verse"))))
 '(org-stuck-projects (quote ("TODO=\"PROJECT\"" nil nil "SCHEDULED:")))
 '(org-table-convert-region-max-lines 99999)
 '(org-tag-alist
   (quote
    ((:startgroup)
     ("@errand" . 101)
     ("@net" . 110)
     ("@home" . 72)
     (:endgroup)
     ("WAITING" . 119)
     ("HOLD" . 104)
     ("PERSONAL" . 80)
     ("WORK" . 87)
     ("ORG" . 79)
     ("NOTE" . 78)
     ("CANCELLED" . 99)
     ("FLAGGED" . 63))))
 '(org-tags-column -97)
 '(org-tags-exclude-from-inheritance (quote ("crypt")))
 '(org-tags-match-list-sublevels t)
 '(org-time-clocksum-format
   (quote
    (:hours "%d" :require-hours t :minutes ":%02d" :require-minutes t)))
 '(org-time-clocksum-use-fractional t)
 '(org-todo-keyword-faces
   (quote
    (("TODO" :inherit org-todo)
     ("PHONE" :foreground "forest green" :weight bold))))
 '(org-todo-keywords
   (quote
    ((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d)")
     (sequence "WAITING(w@/!)" "HOLD(h@/!)" "|" "CANCELLED(c@/!)" "PHONE" "MEETING"))))
 '(org-todo-repeat-to-state "TODO")
 '(org-todo-state-tags-triggers
   (quote
    (("CANCELLED"
      ("CANCELLED" . t))
     ("WAITING"
      ("WAITING" . t))
     ("HOLD"
      ("WAITING")
      ("HOLD" . t))
     (done
      ("WAITING")
      ("HOLD"))
     ("TODO"
      ("WAITING")
      ("CANCELLED")
      ("HOLD"))
     ("NEXT"
      ("WAITING")
      ("CANCELLED")
      ("HOLD"))
     ("DONE"
      ("WAITING")
      ("CANCELLED")
      ("HOLD")))))
 '(org-treat-S-cursor-todo-selection-as-state-change nil)
 '(org-trello-current-prefix-keybinding "C-c o")
 '(org-use-fast-todo-selection t)
 '(org-use-property-inheritance (quote ("AREA")))
 '(org-use-speed-commands t)
 '(org-use-sub-superscripts (quote {}))
 '(org-use-tag-inheritance nil)
 '(org-velocity-always-use-bucket t)
 '(org-velocity-bucket "/Users/dhaley/Box/projects/notes.txt")
 '(org-velocity-capture-templates
   (quote
    (("v" "Velocity" entry
      (file "/Users/dhaley/Box/projects/notes.txt")
      "* NOTE %:search
%i%?
:PROPERTIES:
:ID:       %(shell-command-to-string \\\"uuidgen\\\"):CREATED:  %U
:END:" :prepend t))))
 '(org-velocity-exit-on-match t)
 '(org-velocity-force-new t)
 '(org-velocity-search-method (quote regexp))
 '(org-x-backends (quote (ox-org ox-redmine)))
 '(org-x-redmine-title-prefix-function (quote org-x-redmine-title-prefix))
 '(org-x-redmine-title-prefix-match-function (quote org-x-redmine-title-prefix-match))
 '(org-yank-adjusted-subtrees t)
 '(package-selected-packages
   (quote
    (yapfify stickyfunc-enhance pytest pyenv-mode py-isort pippel pipenv pyvenv pip-requirements lsp-python-ms live-py-mode epc ctable concurrent deferred helm-pydoc helm-gtags helm-cscope xcscope ggtags dap-mode lsp-treemacs bui lsp-mode cython-mode counsel-gtags counsel ivy company-anaconda blacken anaconda-mode pythonic ztree writeroom-mode wrap-region workgroups2 workgroups weblogger wand visual-regexp visual-fill-column visible-mark vimish-fold unicode-enbox twittering-mode transpose-mark tiny theme-changer tbx2org swiper sudden-death sublimity stripe-buffer sort-words smex smart-shift smart-mode-line smart-forward smart-dash smart-cursor-color smart-compile slime session ssass-mode runner restclient redshank rainbow-mode python-mode puppet-mode prodigy pretty-mode po-mode php-eldoc php-boris-minor-mode php-boris perspective persistent-soft peep-dired paredit pandoc-mode page-break-lines pabbrev owdriver ov outshine outorg osx-trash orgbox org-trello org-repo-todo org-present-remote org-pdfview org-link-minor-mode org-caldav org-autolist on-screen olivetti ob-http oauth nyan-mode nlinum nix-mode nameless multifiles multi-web-mode multi-term move-dup minimap mic-paren manage-minor-mode memory-usage math-symbol-lists magit-gerrit magit-find-file magit-annex lua-mode log4j-mode loccur lentic know-your-http-well key-chord jist ipretty interaction-log iflipb ido-hacks ibuffer-git winum org-mime docker-compose-mode nginx-mode go-guru go-eldoc go-mode ede-php-autoload-composer-installers ede-php-autoload-drupal sql-indent jinja2-mode ansible-doc ansible rvm ruby-tools ruby-test-mode rubocop rspec-mode robe rbenv rake minitest chruby bundler inf-ruby csv-mode geben-helm-projectile geben wgrep yaml-mode shift-text company-auctex ebib parsebib seq auctex persistent-scratch web-beautify livid-mode skewer-mode simple-httpd json-mode json-snatcher json-reformat js2-refactor multiple-cursors js2-mode js-doc company-tern dash-functional tern coffee-mode web-mode tagedit slim-mode scss-mode sass-mode pug-mode less-css-mode helm-css-scss haml-mode emmet-mode company-web web-completion-data smeargle orgit org-projectile pcache org-present org org-pomodoro alert log4e gntp org-download mmm-mode markdown-toc markdown-mode magit-gitflow htmlize helm-gitignore helm-company helm-c-yasnippet gnuplot gitignore-mode gitconfig-mode gitattributes-mode git-timemachine git-messenger git-link gh-md flyspell-correct-helm flyspell-correct flycheck-pos-tip pos-tip flycheck evil-magit magit magit-popup git-commit with-editor company-statistics company auto-yasnippet auto-dictionary ac-ispell auto-complete phpunit phpcbf php-extras php-auto-yasnippets yasnippet drupal-mode php-mode ws-butler window-numbering which-key volatile-highlights vi-tilde-fringe uuidgen use-package toc-org spaceline powerline restart-emacs request rainbow-delimiters popwin persp-mode pcre2el paradox spinner org-plus-contrib org-bullets open-junk-file neotree move-text macrostep lorem-ipsum linum-relative link-hint info+ indent-guide ido-vertical-mode hydra hungry-delete hl-todo highlight-parentheses highlight-numbers parent-mode highlight-indentation hide-comnt help-fns+ helm-themes helm-swoop helm-projectile helm-mode-manager helm-make projectile pkg-info epl helm-flx helm-descbinds helm-ag google-translate golden-ratio flx-ido flx fill-column-indicator fancy-battery eyebrowse expand-region exec-path-from-shell evil-visualstar evil-visual-mark-mode evil-unimpaired evil-tutor evil-surround evil-search-highlight-persist evil-numbers evil-nerd-commenter evil-mc evil-matchit evil-lisp-state smartparens evil-indent-plus evil-iedit-state iedit evil-exchange evil-escape evil-ediff evil-args evil-anzu anzu evil goto-chg undo-tree eval-sexp-fu highlight elisp-slime-nav dumb-jump f s diminish define-word column-enforce-mode clean-aindent-mode bind-map bind-key auto-highlight-symbol auto-compile packed dash aggressive-indent adaptive-wrap ace-window ace-link ace-jump-helm-line helm avy helm-core popup async quelpa package-build spacemacs-theme)))
 '(php-mode-coding-style (quote pear))
 '(user-full-name "Damon Haley")
 '(user-initials "dkh")
 '(user-mail-address "damon.haley@nrel.gov"))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-mode-line-clock ((t (:foreground "red" :box (:line-width -1 :style released-button))))))
)
