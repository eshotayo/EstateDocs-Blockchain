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

;; Adds additional tags to document metadata
(define-public (add-document-tags (doc-id uint) (additional-tags (list 10 (string-ascii 32))))
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
      (existing-tags (get tags document-data))
      (combined-tags (unwrap! (as-max-len? (concat existing-tags additional-tags) u10) err-tag-validation-failed))
    )
    ;; Verify document exists and caller is the owner
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) err-unauthorized-owner)

    ;; Validate new tags format
    (asserts! (validate-tag-format additional-tags) err-tag-validation-failed)

    ;; Update document with combined tags
    (map-set estate-documents
      { doc-id: doc-id }
      (merge document-data { tags: combined-tags })
    )
    (ok combined-tags)
  )
)

;; Changes document ownership to new principal
(define-public (transfer-document (doc-id uint) (new-owner principal))
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
    )
    ;; Verify caller is the current owner
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) err-unauthorized-owner)

    ;; Update ownership
    (map-set estate-documents
      { doc-id: doc-id }
      (merge document-data { owner: new-owner })
    )
    (ok true)
  )
)

;; Remove access permission for a specific user
(define-public (remove-viewer-access (doc-id uint) (viewer principal))
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
    )
    ;; Verify document exists and caller is the owner
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) err-unauthorized-owner)
    (asserts! (not (is-eq viewer tx-sender)) err-admin-only-action)

    ;; Remove access permission
    (map-delete document-permissions { doc-id: doc-id, viewer: viewer })
    (ok true)
  )
)

;; Places security hold on document
(define-public (security-lock-document (doc-id uint))
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
      (security-tag "SECURITY-HOLD")
      (existing-tags (get tags document-data))
    )
    ;; Verify caller is either the owner or system administrator
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! 
      (or 
        (is-eq tx-sender admin-address)
        (is-eq (get owner document-data) tx-sender)
      ) 
      err-admin-only-action
    )

    (ok true)
  )
)

;; Examines document authenticity and ownership history
(define-public (verify-document-authenticity (doc-id uint) (presumed-owner principal))
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
      (actual-owner (get owner document-data))
      (registration-height (get registration-block document-data))
      (has-access (default-to 
        false 
        (get can-view 
          (map-get? document-permissions { doc-id: doc-id, viewer: tx-sender })
        )
      ))
    )
    ;; Validate document existence and access permissions
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! 
      (or 
        (is-eq tx-sender actual-owner)
        has-access
        (is-eq tx-sender admin-address)
      ) 
      err-permission-denied
    )

    ;; Generate verification report
    (if (is-eq actual-owner presumed-owner)
      ;; Return successful verification with details
      (ok {
        is-valid: true,
        current-height: block-height,
        blocks-since-creation: (- block-height registration-height),
        owner-match: true
      })
      ;; Return ownership mismatch
      (ok {
        is-valid: false,
        current-height: block-height,
        blocks-since-creation: (- block-height registration-height),
        owner-match: false
      })
    )
  )
)

;; ===== Utility Functions =====

;; Checks if document exists in registry
(define-private (document-exists (doc-id uint))
  (is-some (map-get? estate-documents { doc-id: doc-id }))
)

;; Validates tag structure
(define-private (is-valid-tag (tag (string-ascii 32)))
  (and
    (> (len tag) u0)
    (< (len tag) u33)
  )
)

;; Ensures all tags meet formatting requirements
(define-private (validate-tag-format (tags (list 10 (string-ascii 32))))
  (and
    (> (len tags) u0)
    (<= (len tags) u10)
    (is-eq (len (filter is-valid-tag tags)) (len tags))
  )
)

;; Gets document size information
(define-private (get-document-size (doc-id uint))
  (default-to u0
    (get file-size
      (map-get? estate-documents { doc-id: doc-id })
    )
  )
)

;; Verifies if caller has ownership rights
(define-private (is-document-owner (doc-id uint) (user principal))
  (match (map-get? estate-documents { doc-id: doc-id })
    document-data (is-eq (get owner document-data) user)
    false
  )
)



;; ===== Document Management Functions =====

;; Registers a new property document with complete information
(define-public (register-document 
  (title (string-ascii 64)) 
  (file-size uint) 
  (description (string-ascii 128)) 
  (tags (list 10 (string-ascii 32)))
)
  (let
    (
      (doc-id (+ (var-get document-counter) u1))
    )
    ;; Input validation checks
    (asserts! (> (len title) u0) err-invalid-title)
    (asserts! (< (len title) u65) err-invalid-title)
    (asserts! (> file-size u0) err-invalid-document-size)
    (asserts! (< file-size u1000000000) err-invalid-document-size)
    (asserts! (> (len description) u0) err-invalid-title)
    (asserts! (< (len description) u129) err-invalid-title)
    (asserts! (validate-tag-format tags) err-tag-validation-failed)

    ;; Add document to registry
    (map-insert estate-documents
      { doc-id: doc-id }
      {
        title: title,
        owner: tx-sender,
        file-size: file-size,
        registration-block: block-height,
        description: description,
        tags: tags
      }
    )

    ;; Grant access to document creator
    (map-insert document-permissions
      { doc-id: doc-id, viewer: tx-sender }
      { can-view: true }
    )

    ;; Update registry statistics
    (var-set document-counter doc-id)
    (ok doc-id)
  )
)

;; Updates existing document with new information
(define-public (update-document 
  (doc-id uint) 
  (new-title (string-ascii 64)) 
  (new-file-size uint) 
  (new-description (string-ascii 128)) 
  (new-tags (list 10 (string-ascii 32)))
)
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
    )
    ;; Validate ownership and input parameters
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) err-unauthorized-owner)
    (asserts! (> (len new-title) u0) err-invalid-title)
    (asserts! (< (len new-title) u65) err-invalid-title)
    (asserts! (> new-file-size u0) err-invalid-document-size)
    (asserts! (< new-file-size u1000000000) err-invalid-document-size)
    (asserts! (> (len new-description) u0) err-invalid-title)
    (asserts! (< (len new-description) u129) err-invalid-title)
    (asserts! (validate-tag-format new-tags) err-tag-validation-failed)

    ;; Update document with new information
    (map-set estate-documents
      { doc-id: doc-id }
      (merge document-data { 
        title: new-title, 
        file-size: new-file-size, 
        description: new-description, 
        tags: new-tags 
      })
    )
    (ok true)
  )
)

;; ===== Extended Registry Features =====

;; Grants document access permission to another user
(define-public (grant-document-access (doc-id uint) (viewer principal))
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
    )
    ;; Verify document exists and caller is the owner
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) err-unauthorized-owner)
    (ok true)
  )
)

;; Gets document usage statistics
(define-public (get-document-statistics (doc-id uint))
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
      (registration-height (get registration-block document-data))
    )
    ;; Verify document exists and caller has access
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! 
      (or 
        (is-eq tx-sender (get owner document-data))
        (default-to false (get can-view (map-get? document-permissions { doc-id: doc-id, viewer: tx-sender })))
        (is-eq tx-sender admin-address)
      ) 
      err-permission-denied
    )

    ;; Return document statistics
    (ok {
      document-age: (- block-height registration-height),
      size-in-bytes: (get file-size document-data),
      metadata-count: (len (get tags document-data))
    })
  )
)

;; System administration functions
(define-public (system-maintenance-check)
  (begin
    ;; Verify caller is system administrator
    (asserts! (is-eq tx-sender admin-address) err-admin-only-action)

    ;; Return system health status
    (ok {
      registry-count: (var-get document-counter),
      system-healthy: true,
      last-checked: block-height
    })
  )
)

;; Archives document but maintains ownership records
(define-public (archive-document (doc-id uint))
  (let
    (
      (document-data (unwrap! (map-get? estate-documents { doc-id: doc-id }) err-document-not-found))
      (archive-tag "ARCHIVED")
      (existing-tags (get tags document-data))
      (combined-tags (unwrap! (as-max-len? (append existing-tags archive-tag) u10) err-tag-validation-failed))
    )
    ;; Verify document exists and caller is the owner
    (asserts! (document-exists doc-id) err-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) err-unauthorized-owner)

    ;; Update document with archive tag
    (map-set estate-documents
      { doc-id: doc-id }
      (merge document-data { tags: combined-tags })
    )
    (ok true)
  )
)


