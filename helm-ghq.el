;;; helm-ghq.el --- ghq with helm interface -*- lexical-binding: t; -*-

;; Copyright (C) 2015 by Takashi Masuda

;; Author: Takashi Masuda <masutaka.net@gmail.com>
;; URL: https://github.com/masutaka/emacs-helm-ghq
;; Version: 1.6.0
;; Package-Requires: ((helm "1.8.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; helm-ghq.el provides a helm interface to "ghq".

;;; Code:

(require 'helm)
(require 'helm-mode)
(require 'helm-files)

(defgroup helm-ghq nil
  "ghq with helm interface"
  :prefix "helm-ghq-"
  :group 'helm)

(defcustom helm-ghq-command-ghq
  "ghq"
  "*A ghq command"
  :type 'string
  :group 'helm-ghq)

(defcustom helm-ghq-command-ghq-arg-root
  '("root")
  "*Arguments for getting ghq root path using ghq command"
  :type '(repeqt string)
  :group 'helm-ghq)

(defcustom helm-ghq-command-ghq-arg-list
  '("list" "--full-path")
  "*Arguments for getting ghq list"
  :type '(repeqt string)
  :group 'helm-ghq)

(defcustom helm-ghq-command-ghq-arg-update-repo
  '("get" "-u")
  "*Arguments for updating a repository"
  :type '(repeqt string)
  :group 'helm-ghq)

(defcustom helm-ghq-command-git
  "git"
  "*A git command"
  :type 'string
  :group 'helm-ghq)

(defcustom helm-ghq-command-git-arg-root
  '("config" "ghq.root")
  "*Arguments for getting ghq root path using git command"
  :type '(repeqt string)
  :group 'helm-ghq)

(defcustom helm-ghq-command-git-arg-ls-files
  '("ls-files")
  "*Arguments for getting file list in git repository"
  :type '(repeqt string)
  :group 'helm-ghq)

(defcustom helm-ghq-command-hg
  "hg"
  "*A hg command"
  :type 'string
  :group 'helm-ghq)

(defcustom helm-ghq-command-hg-arg-ls-files
  '("manifest")
  "*Arguments for getting file list in hg repository"
  :type '(repeqt string)
  :group 'helm-ghq)

(defcustom helm-ghq-command-svn
  "svn"
  "*A svn command"
  :type 'string
  :group 'helm-ghq)

(defcustom helm-ghq-command-svn-arg-ls-files
  '("list" "--recursive")
  "*Arguments for getting files (and directories) list in svn repository"
  :type '(repeqt string)
  :group 'helm-ghq)

(defun helm-ghq--open-dired (file)
  (dired (file-name-directory file)))

(defun helm-ghq--open-dired-with-dircotry (dircotry)
  (dired (concat (helm-ghq--root) "/" dircotry)))

(defun helm-ghq--open-dired-with-dircotry-in-other-window (dircotry)
  (dired-other-window (concat (helm-ghq--root) "/" dircotry)))

(defun helm-ghq--open-dired-with-dircotry-in-other-frame (dircotry)
  (dired-other-frame (concat (helm-ghq--root) "/" dircotry)))

(defvar helm-ghq--dired nil)

(defvar helm-ghq--action
  '(("Open File" . find-file)
    ("Open File other window" . find-file-other-window)
    ("Open File other frame" . find-file-other-frame)
    ("Open Directory" . helm-ghq--open-dired)))

(defvar helm-ghq--directory-action
  '(("Open Directory" . helm-ghq--open-dired-with-dircotry)
    ("Open Directory other window" . helm-ghq--open-dired-with-dircotry-in-other-window)
    ("Open Direcotry other frame" . helm-ghq--open-dired-with-dircotry-in-other-frame)))

(defvar helm-source-ghq
  (helm-build-sync-source "ghq"
    :candidates #'helm-ghq--list-candidates
    :match #'helm-ghq--files-match-only-basename
    :filter-one-by-one (lambda (candidate)
                         (if helm-ff-transformer-show-only-basename
                             candidate
                           (cons (cdr candidate) (cdr candidate))))
    :keymap helm-generic-files-map
    :help-message helm-generic-file-help-message
    :action helm-ghq--action)
  "Helm source for ghq.")

(defun helm-ghq--files-match-only-basename (candidate)
  "Allow matching only basename of file when \" -b\" is added at end of pattern.
If pattern contain one or more spaces, fallback to match-plugin
even is \" -b\" is specified."
  (let ((source (helm-get-current-source)))
    (if (string-match "\\([^ ]*\\) -b\\'" helm-pattern)
        (progn
          (helm-attrset 'no-matchplugin nil source)
          (string-match (match-string 1 helm-pattern)
                        (helm-basename candidate)))
      ;; Disable no-matchplugin by side effect.
      (helm-aif (assq 'no-matchplugin source)
          (setq source (delete it source)))
      (string-match
       (replace-regexp-in-string " -b\\'" "" helm-pattern)
       candidate))))

(defmacro helm-ghq--line-string ()
  `(buffer-substring-no-properties
    (line-beginning-position) (line-end-position)))

(defun helm-ghq--root-fallback ()
  (erase-buffer)
  (unless (zerop (apply #'process-file
			helm-ghq-command-git nil t nil
			helm-ghq-command-git-arg-root))
    (error "Failed: Can't find ghq root"))
  (goto-char (point-min))
  (expand-file-name (helm-ghq--line-string)))

(defun helm-ghq--root ()
  (with-temp-buffer
    (apply #'process-file
	   helm-ghq-command-ghq nil t nil
	   helm-ghq-command-ghq-arg-root)
    (goto-char (point-min))
    (let ((output (helm-ghq--line-string)))
      (if (string-match-p "\\`No help topic" output)
          (helm-ghq--root-fallback)
        (expand-file-name output)))))

(defun helm-ghq--list-candidates ()
  (with-temp-buffer
    (unless (zerop (apply #'call-process
			  helm-ghq-command-ghq nil t nil
			  helm-ghq-command-ghq-arg-list))
      (error "Failed: Can't get ghq list candidates"))
    (let ((ghq-root (helm-ghq--root))
          paths)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((path (helm-ghq--line-string)))
          (push (cons (file-relative-name path ghq-root) path) paths))
        (forward-line 1))
      (reverse paths))))

(defun helm-ghq--ls-files ()
  (with-current-buffer (helm-candidate-buffer 'global)
    (unless (or (zerop (call-process "git" nil '(t nil) nil "ls-files"))
                (zerop (call-process "hg" nil t nil "manifest")))
      (error "Failed: git ls-files | hg manifest"))))

(defun helm-ghq--source (repo)
  (let ((name (file-name-nondirectory (directory-file-name repo))))
    (helm-build-in-buffer-source name
      :init #'helm-ghq--ls-files
      :action helm-ghq--action)))

(defun helm-ghq--list-directories ()
  (with-current-buffer (helm-candidate-buffer 'global)
    (unless (zerop (call-process "ghq" nil t nil "list"))
      (error "Failed: ghq list"))))

(defun helm-ghq--dired-source ()
  `((name . "ghq direcotry list")
    (init . helm-ghq--list-directories)
    (candidates-in-buffer)
    (action . ,helm-ghq--directory-action)))

(defun helm-ghq--repo-to-user-project (repo)
  (cond ((string-match "github.com/\\(.+\\)" repo)
         (match-string-no-properties 1 repo))
        ((string-match "code.google.com/\\(.+\\)" repo)
         (match-string-no-properties 1 repo))))

(defsubst hel-ghq--concat-as-command (args)
  (mapconcat 'identity args " "))

(defun helm-ghq--update-repository (repo)
  (let* ((user-project (helm-ghq--repo-to-user-project repo))
	 (command (hel-ghq--concat-as-command
		   (list
		    helm-ghq-command-ghq
		    (hel-ghq--concat-as-command
		     helm-ghq-command-ghq-arg-update-repo)
		    user-project))))
    (async-shell-command command)))

(defun helm-ghq--source-update (repo)
  (helm-build-sync-source "Update Repository"
    :candidates '(" ") ; dummy
    :action (lambda (_c)
              (helm-ghq--update-repository repo))))

;;;###autoload
(defun helm-ghq ()
  (interactive)
  (if helm-ghq--dired
      (helm :buffer "*helm-ghq-list*"
            :sources (helm-ghq--dired-source))
    (let ((repo (helm-comp-read "ghq-list: "
                                (helm-ghq--list-candidates)
                                :name "ghq list"
                                :must-match t)))
      (let ((default-directory (file-name-as-directory repo)))
        (helm :sources (list (helm-ghq--source default-directory)
                             (helm-ghq--source-update repo))
              :buffer "*helm-ghq-list*")))))


(provide 'helm-ghq)

;;; helm-ghq.el ends here
