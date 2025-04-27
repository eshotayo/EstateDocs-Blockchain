;; Estate Documentation 
;; A blockchain-based solution for securely registering and managing property documentation

;; Global Registry Statistics
(define-data-var document-counter uint u0)

;; System Error Definitions
(define-constant err-document-not-found (err u401))
(define-constant err-document-already-exists (err u402))
(define-constant err-invalid-title (err u403))
(define-constant err-invalid-document-size (err u404))
(define-constant err-permission-denied (err u405))
(define-constant err-unauthorized-owner (err u406))
(define-constant err-admin-only-action (err u407))
(define-constant err-viewing-restricted (err u408))
(define-constant err-tag-validation-failed (err u409))

;; Core Data Schema
(define-map estate-documents
  { doc-id: uint }
  {
    title: (string-ascii 64),
    owner: principal,
    file-size: uint,
    registration-block: uint,
    description: (string-ascii 128),
    tags: (list 10 (string-ascii 32))
  }
)


;; Platform Administration
(define-constant admin-address tx-sender)

(define-map document-permissions
  { doc-id: uint, viewer: principal }
  { can-view: bool }
)

;; ===== Document Access Control =====

;; Removes document from registry permanently
(define-public (delete-document (doc-id uint))
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
    )
    ;; Verify ownership
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) err-unauthorized-owner)

    ;; Remove document from registry
    (map-delete estate-documents { doc-id: doc-id })
    (ok true)
  )
)
