;; Genetic Circuit Designer Contract
;; Visual design tool for genetic circuits and pathways with validation and optimization

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-CIRCUIT-EXISTS (err u409))
(define-constant ERR-INVALID-COMPONENT (err u422))
(define-constant ERR-CIRCUIT-NOT-VALIDATED (err u428))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))

(define-constant MAX-CIRCUIT-NAME-LENGTH u64)
(define-constant MAX-DESCRIPTION-LENGTH u256)
(define-constant MAX-COMPONENTS-PER-CIRCUIT u50)
(define-constant DESIGN-FEE u1000000) ;; 1 STX in microSTX

;; Data Variables
(define-data-var circuit-counter uint u0)
(define-data-var total-designs uint u0)
(define-data-var contract-balance uint u0)

;; Data Maps
(define-map circuits
    uint
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        designer: principal,
        components: (list 50 (string-ascii 32)),
        pathway-type: (string-ascii 32),
        validated: bool,
        optimization-score: uint,
        created-at: uint,
        updated-at: uint,
        status: (string-ascii 16)
    }
)

(define-map circuit-components
    { circuit-id: uint, component-id: uint }
    {
        name: (string-ascii 32),
        component-type: (string-ascii 24),
        function: (string-ascii 64),
        expression-level: uint,
        interactions: (list 10 uint),
        upstream: (optional uint),
        downstream: (optional uint)
    }
)

(define-map validation-results
    uint
    {
        circuit-id: uint,
        validator: principal,
        logic-score: uint,
        safety-score: uint,
        efficiency-score: uint,
        overall-score: uint,
        issues: (list 20 (string-ascii 64)),
        recommendations: (list 10 (string-ascii 128)),
        validated-at: uint
    }
)

(define-map pathway-optimizations
    uint
    {
        circuit-id: uint,
        optimizer: principal,
        original-score: uint,
        optimized-score: uint,
        changes-made: (list 15 (string-ascii 128)),
        ai-suggestions: (list 10 (string-ascii 256)),
        optimization-time: uint,
        created-at: uint
    }
)

(define-map user-designs
    principal
    {
        total-circuits: uint,
        validated-circuits: uint,
        optimization-count: uint,
        reputation-score: uint,
        last-active: uint
    }
)

(define-map circuit-collaborators
    { circuit-id: uint, collaborator: principal }
    {
        role: (string-ascii 16),
        permissions: (list 5 (string-ascii 16)),
        added-at: uint,
        added-by: principal
    }
)

;; Private Functions

(define-private (validate-circuit-name (name (string-ascii 64)))
    (and
        (> (len name) u0)
        (<= (len name) MAX-CIRCUIT-NAME-LENGTH)
    )
)

(define-private (validate-description (desc (string-ascii 256)))
    (<= (len desc) MAX-DESCRIPTION-LENGTH)
)

(define-private (validate-components (components (list 50 (string-ascii 32))))
    (and
        (> (len components) u0)
        (<= (len components) MAX-COMPONENTS-PER-CIRCUIT)
    )
)

(define-private (calculate-optimization-score 
    (logic-score uint) 
    (efficiency-score uint) 
    (safety-score uint)
    )
    (/ (+ logic-score efficiency-score safety-score) u3)
)

(define-private (update-user-stats (designer principal) (validated bool))
    (let (
        (current-stats (default-to 
            { total-circuits: u0, validated-circuits: u0, optimization-count: u0, 
              reputation-score: u0, last-active: stacks-block-height }
            (map-get? user-designs designer)
        ))
    )
        (map-set user-designs designer
            (merge current-stats
                {
                    total-circuits: (+ (get total-circuits current-stats) u1),
                    validated-circuits: (if validated 
                        (+ (get validated-circuits current-stats) u1)
                        (get validated-circuits current-stats)
                    ),
                    last-active: stacks-block-height
                }
            )
        )
    )
)

(define-private (increment-circuit-counter)
    (let ((new-id (+ (var-get circuit-counter) u1)))
        (var-set circuit-counter new-id)
        new-id
    )
)

(define-private (is-circuit-owner (circuit-id uint) (user principal))
    (match (map-get? circuits circuit-id)
        circuit-data (is-eq (get designer circuit-data) user)
        false
    )
)

(define-private (has-collaboration-access (circuit-id uint) (user principal))
    (or 
        (is-circuit-owner circuit-id user)
        (is-some (map-get? circuit-collaborators { circuit-id: circuit-id, collaborator: user }))
    )
)

;; Public Functions

(define-public (design-circuit 
    (name (string-ascii 64))
    (description (string-ascii 256))
    (components (list 50 (string-ascii 32)))
    (pathway-type (string-ascii 32))
    )
    (let (
        (circuit-id (increment-circuit-counter))
        (designer tx-sender)
    )
        (asserts! (validate-circuit-name name) ERR-INVALID-INPUT)
        (asserts! (validate-description description) ERR-INVALID-INPUT)
        (asserts! (validate-components components) ERR-INVALID-INPUT)
        (asserts! (>= (stx-get-balance tx-sender) DESIGN-FEE) ERR-INSUFFICIENT-BALANCE)
        
        (try! (stx-transfer? DESIGN-FEE tx-sender (as-contract tx-sender)))
        (var-set contract-balance (+ (var-get contract-balance) DESIGN-FEE))
        
        (map-set circuits circuit-id
            {
                name: name,
                description: description,
                designer: designer,
                components: components,
                pathway-type: pathway-type,
                validated: false,
                optimization-score: u0,
                created-at: stacks-block-height,
                updated-at: stacks-block-height,
                status: "draft"
            }
        )
        
        (update-user-stats designer false)
        (var-set total-designs (+ (var-get total-designs) u1))
        
        (ok circuit-id)
    )
)

(define-public (validate-circuit 
    (circuit-id uint)
    (logic-score uint)
    (safety-score uint)
    (efficiency-score uint)
    (issues (list 20 (string-ascii 64)))
    (recommendations (list 10 (string-ascii 128)))
    )
    (let (
        (circuit-data (unwrap! (map-get? circuits circuit-id) ERR-NOT-FOUND))
        (overall-score (calculate-optimization-score logic-score efficiency-score safety-score))
        (validator tx-sender)
    )
        (asserts! (<= logic-score u100) ERR-INVALID-INPUT)
        (asserts! (<= safety-score u100) ERR-INVALID-INPUT)
        (asserts! (<= efficiency-score u100) ERR-INVALID-INPUT)
        
        (map-set validation-results circuit-id
            {
                circuit-id: circuit-id,
                validator: validator,
                logic-score: logic-score,
                safety-score: safety-score,
                efficiency-score: efficiency-score,
                overall-score: overall-score,
                issues: issues,
                recommendations: recommendations,
                validated-at: stacks-block-height
            }
        )
        
        (map-set circuits circuit-id
            (merge circuit-data
                {
                    validated: true,
                    optimization-score: overall-score,
                    updated-at: stacks-block-height,
                    status: "validated"
                }
            )
        )
        
        (update-user-stats (get designer circuit-data) true)
        (ok overall-score)
    )
)

(define-public (optimize-pathway
    (circuit-id uint)
    (ai-suggestions (list 10 (string-ascii 256)))
    (changes-made (list 15 (string-ascii 128)))
    )
    (let (
        (circuit-data (unwrap! (map-get? circuits circuit-id) ERR-NOT-FOUND))
        (original-score (get optimization-score circuit-data))
        (optimizer tx-sender)
    )
        (asserts! (has-collaboration-access circuit-id tx-sender) ERR-UNAUTHORIZED)
        (asserts! (get validated circuit-data) ERR-CIRCUIT-NOT-VALIDATED)
        
        (let ((optimized-score (+ original-score u10))) ;; Simplified optimization calculation
            (map-set pathway-optimizations circuit-id
                {
                    circuit-id: circuit-id,
                    optimizer: optimizer,
                    original-score: original-score,
                    optimized-score: optimized-score,
                    changes-made: changes-made,
                    ai-suggestions: ai-suggestions,
                    optimization-time: u1,
                    created-at: stacks-block-height
                }
            )
            
            (map-set circuits circuit-id
                (merge circuit-data
                    {
                        optimization-score: optimized-score,
                        updated-at: stacks-block-height,
                        status: "optimized"
                    }
                )
            )
            
            (ok optimized-score)
        )
    )
)

(define-public (add-collaborator
    (circuit-id uint)
    (collaborator principal)
    (role (string-ascii 16))
    (permissions (list 5 (string-ascii 16)))
    )
    (begin
        (asserts! (is-circuit-owner circuit-id tx-sender) ERR-UNAUTHORIZED)
        (asserts! (is-none (map-get? circuit-collaborators { circuit-id: circuit-id, collaborator: collaborator })) ERR-CIRCUIT-EXISTS)
        
        (map-set circuit-collaborators { circuit-id: circuit-id, collaborator: collaborator }
            {
                role: role,
                permissions: permissions,
                added-at: stacks-block-height,
                added-by: tx-sender
            }
        )
        
        (ok true)
    )
)

;; Read-only Functions

(define-read-only (get-circuit-details (circuit-id uint))
    (map-get? circuits circuit-id)
)

(define-read-only (get-validation-results (circuit-id uint))
    (map-get? validation-results circuit-id)
)

(define-read-only (get-pathway-optimization (circuit-id uint))
    (map-get? pathway-optimizations circuit-id)
)

(define-read-only (get-user-stats (user principal))
    (map-get? user-designs user)
)

(define-read-only (get-circuit-count)
    (var-get circuit-counter)
)

(define-read-only (get-total-designs)
    (var-get total-designs)
)

(define-read-only (get-contract-balance)
    (var-get contract-balance)
)

