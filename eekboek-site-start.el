;; Use eekboek-mode for .eb files. Treat .ebz files as (zip) archives.

(autoload 'eekboek-mode "eekboek-mode" "Major mode for editing EekBoek data." t)
(add-to-list 'auto-mode-alist '("\\.eb$" . eekboek-mode))
(add-to-list 'auto-mode-alist '("\\.ebz$" . archive-mode))

;;; eekboek-site-start.el ends here
