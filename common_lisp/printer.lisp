(require "types")
(require "utils")

(defpackage :printer
  (:use :common-lisp :utils :types)
  (:export :pr-str))

(in-package :printer)

(defun pr-mal-sequence (start-delimiter sequence end-delimiter &optional (print-readably t))
  (concatenate 'string
               start-delimiter
               (format nil
                       "~{~a~^ ~}"
                       (map 'list (lambda (value)
                                    (pr-str value print-readably))
                            (types:mal-value sequence)))
               end-delimiter))

(defun pr-mal-hash-map (hash-map &optional (print-readably t))
  (let ((hash-map-value (types:mal-value hash-map)))
    (concatenate 'string
                 "{"
                 (format nil
                         "~{~a~^ ~}"
                         (mapcar (lambda (key-value)
                                   (format nil
                                           "~a ~a"
                                           (pr-str (car key-value) print-readably)
                                           (pr-str (cdr key-value) print-readably)))
                                 (loop
                                    for key being the hash-keys of hash-map-value
                                    collect (cons key (gethash key hash-map-value)))))
                 "}")))

(defun pr-string (ast &optional (print-readably t))
  (if print-readably
      (utils:replace-all (prin1-to-string (types:mal-value ast))
                         "
"
                         "\\n")
      (types:mal-value ast)))

(defun pr-str (ast &optional (print-readably t))
  (when ast
    (switch-mal-type ast
      (types:number (format nil "~d" (types:mal-value ast)))
      (types:boolean (if (types:mal-value ast) "true" "false"))
      (types:nil "nil")
      (types:string (pr-string ast print-readably))
      (types:symbol (format nil "~a" (types:mal-value ast)))
      (types:keyword (format nil ":~a" (types:mal-value ast)))
      (types:list (pr-mal-sequence "(" ast ")" print-readably))
      (types:vector (pr-mal-sequence "[" ast "]" print-readably))
      (types:hash-map (pr-mal-hash-map ast print-readably))
      (types:atom (format nil "(atom ~a)" (pr-str (types:mal-value ast))))
      (types:fn "#<function>")
      (types:builtin-fn "#<builtin function>"))))
