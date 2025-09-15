;; Protein Folding Predictor Contract
;; AI model for predicting protein structures and interactions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-PREDICTION-EXISTS (err u409))
(define-constant ERR-INVALID-SEQUENCE (err u422))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-ANALYSIS-IN-PROGRESS (err u429))

(define-constant MAX-SEQUENCE-LENGTH u2000)
(define-constant MIN-SEQUENCE-LENGTH u10)
(define-constant MAX-PROTEIN-NAME-LENGTH u64)
(define-constant PREDICTION-FEE u500000) ;; 0.5 STX in microSTX
(define-constant ANALYSIS-FEE u750000) ;; 0.75 STX in microSTX

;; Data Variables
(define-data-var prediction-counter uint u0)
(define-data-var total-predictions uint u0)
(define-data-var total-analyses uint u0)
(define-data-var contract-revenue uint u0)

;; Data Maps
(define-map protein-predictions
    uint
    {
        name: (string-ascii 64),
        sequence: (string-ascii 2000),
        predictor: principal,
        structure-type: (string-ascii 32),
        confidence-score: uint,
        folding-energy: int,
        stability-index: uint,
        prediction-method: (string-ascii 32),
        created-at: uint,
        updated-at: uint,
        status: (string-ascii 16)
    }
)

(define-map structure-coordinates
    uint
    {
        prediction-id: uint,
        alpha-helices: (list 20 { start: uint, end: uint, confidence: uint }),
        beta-sheets: (list 15 { start: uint, end: uint, confidence: uint }),
        loops: (list 30 { start: uint, end: uint, type: (string-ascii 16) }),
        disulfide-bonds: (list 10 { residue1: uint, residue2: uint, distance: uint }),
        secondary-structure: (string-ascii 2000),
        tertiary-coords: (list 100 { x: int, y: int, z: int, atom-type: (string-ascii 4) })
    }
)

(define-map interaction-analysis
    uint
    {
        prediction-id: uint,
        analyst: principal,
        binding-sites: (list 10 { start: uint, end: uint, affinity: uint }),
        interaction-partners: (list 5 (string-ascii 64)),
        binding-energies: (list 5 int),
        molecular-dynamics: (list 20 { time: uint, energy: int, rmsd: uint }),
        hydrophobic-patches: (list 8 { center: uint, size: uint, score: uint }),
        created-at: uint
    }
)

(define-map mutation-effects
    { prediction-id: uint, mutation-id: uint }
    {
        original-residue: (string-ascii 3),
        mutated-residue: (string-ascii 3),
        position: uint,
        stability-change: int,
        function-impact: uint,
        pathogenicity-score: uint,
        conservation-score: uint,
        structural-impact: (string-ascii 32),
        predicted-by: principal,
        created-at: uint
    }
)

(define-map folding-simulations
    uint
    {
        prediction-id: uint,
        simulator: principal,
        simulation-time: uint,
        temperature: uint,
        ph-level: uint,
        ionic-strength: uint,
        folding-pathway: (list 50 (string-ascii 16)),
        intermediate-states: (list 20 uint),
        folding-rate: uint,
        unfolding-rate: uint,
        created-at: uint
    }
)

(define-map user-predictions
    principal
    {
        total-predictions: uint,
        successful-predictions: uint,
        analysis-count: uint,
        accuracy-score: uint,
        reputation-level: uint,
        last-prediction: uint
    }
)

(define-map quality-assessments
    uint
    {
        prediction-id: uint,
        assessor: principal,
        ramachandran-score: uint,
        clash-score: uint,
        geometry-score: uint,
        overall-quality: uint,
        validation-notes: (list 10 (string-ascii 128)),
        assessed-at: uint
    }
)

;; Private Functions

(define-private (validate-sequence (sequence (string-ascii 2000)))
    (let ((seq-length (len sequence)))
        (and
            (>= seq-length MIN-SEQUENCE-LENGTH)
            (<= seq-length MAX-SEQUENCE-LENGTH)
            (is-valid-amino-acid-sequence sequence)
        )
    )
)

(define-private (is-valid-amino-acid-sequence (sequence (string-ascii 2000)))
    ;; Simplified validation - in reality would check for valid amino acid codes
    (> (len sequence) u0)
)

(define-private (validate-protein-name (name (string-ascii 64)))
    (and
        (> (len name) u0)
        (<= (len name) MAX-PROTEIN-NAME-LENGTH)
    )
)

(define-private (calculate-confidence-score
    (sequence-length uint)
    (structure-complexity uint)
    (method-reliability uint)
    )
    (let (
        (base-score (* method-reliability u2))
        (length-factor (if (> sequence-length u500) u80 u95))
        (complexity-factor (- u100 structure-complexity))
    )
        (/ (+ base-score length-factor complexity-factor) u3)
    )
)

(define-private (calculate-folding-energy (sequence-length uint) (structure-type (string-ascii 32)))
    (let (
        (base-energy (* (to-int sequence-length) -5))
        (type-modifier (if (is-eq structure-type "alpha-helical") -10 -5))
    )
        (+ base-energy type-modifier)
    )
)

(define-private (update-user-prediction-stats (predictor principal) (successful bool))
    (let (
        (current-stats (default-to 
            { total-predictions: u0, successful-predictions: u0, analysis-count: u0,
              accuracy-score: u0, reputation-level: u1, last-prediction: stacks-block-height }
            (map-get? user-predictions predictor)
        ))
    )
        (map-set user-predictions predictor
            (merge current-stats
                {
                    total-predictions: (+ (get total-predictions current-stats) u1),
                    successful-predictions: (if successful
                        (+ (get successful-predictions current-stats) u1)
                        (get successful-predictions current-stats)
                    ),
                    last-prediction: stacks-block-height
                }
            )
        )
    )
)

(define-private (increment-prediction-counter)
    (let ((new-id (+ (var-get prediction-counter) u1)))
        (var-set prediction-counter new-id)
        new-id
    )
)

(define-private (is-prediction-owner (prediction-id uint) (user principal))
    (match (map-get? protein-predictions prediction-id)
        prediction-data (is-eq (get predictor prediction-data) user)
        false
    )
)

(define-private (calculate-stability-index (folding-energy int) (sequence-length uint))
    (let (
        (energy-component (if (< folding-energy 0) 
            (to-uint (- 0 folding-energy))
            u0
        ))
        (length-factor (/ sequence-length u10))
    )
        (+ energy-component length-factor)
    )
)

;; Public Functions

(define-public (predict-structure
    (name (string-ascii 64))
    (sequence (string-ascii 2000))
    (prediction-method (string-ascii 32))
    (structure-type (string-ascii 32))
    )
    (let (
        (prediction-id (increment-prediction-counter))
        (predictor tx-sender)
        (sequence-length (len sequence))
    )
        (asserts! (validate-protein-name name) ERR-INVALID-INPUT)
        (asserts! (validate-sequence sequence) ERR-INVALID-SEQUENCE)
        (asserts! (>= (stx-get-balance tx-sender) PREDICTION-FEE) ERR-INSUFFICIENT-BALANCE)
        
        (try! (stx-transfer? PREDICTION-FEE tx-sender (as-contract tx-sender)))
        (var-set contract-revenue (+ (var-get contract-revenue) PREDICTION-FEE))
        
        (let (
            (confidence (calculate-confidence-score sequence-length u30 u85))
            (folding-energy (calculate-folding-energy sequence-length structure-type))
            (stability (calculate-stability-index folding-energy sequence-length))
        )
            (map-set protein-predictions prediction-id
                {
                    name: name,
                    sequence: sequence,
                    predictor: predictor,
                    structure-type: structure-type,
                    confidence-score: confidence,
                    folding-energy: folding-energy,
                    stability-index: stability,
                    prediction-method: prediction-method,
                    created-at: stacks-block-height,
                    updated-at: stacks-block-height,
                    status: "predicted"
                }
            )
        )
        
        (update-user-prediction-stats predictor true)
        (var-set total-predictions (+ (var-get total-predictions) u1))
        
        (ok prediction-id)
    )
)

(define-public (analyze-interactions
    (prediction-id uint)
    (binding-sites (list 10 { start: uint, end: uint, affinity: uint }))
    (interaction-partners (list 5 (string-ascii 64)))
    (binding-energies (list 5 int))
    )
    (let (
        (prediction-data (unwrap! (map-get? protein-predictions prediction-id) ERR-NOT-FOUND))
        (analyst tx-sender)
    )
        (asserts! (is-eq (get status prediction-data) "predicted") ERR-INVALID-INPUT)
        (asserts! (>= (stx-get-balance tx-sender) ANALYSIS-FEE) ERR-INSUFFICIENT-BALANCE)
        
        (try! (stx-transfer? ANALYSIS-FEE tx-sender (as-contract tx-sender)))
        (var-set contract-revenue (+ (var-get contract-revenue) ANALYSIS-FEE))
        
        (map-set interaction-analysis prediction-id
            {
                prediction-id: prediction-id,
                analyst: analyst,
                binding-sites: binding-sites,
                interaction-partners: interaction-partners,
                binding-energies: binding-energies,
                molecular-dynamics: (list),
                hydrophobic-patches: (list),
                created-at: stacks-block-height
            }
        )
        
        (map-set protein-predictions prediction-id
            (merge prediction-data
                {
                    updated-at: stacks-block-height,
                    status: "analyzed"
                }
            )
        )
        
        (var-set total-analyses (+ (var-get total-analyses) u1))
        (ok true)
    )
)

(define-public (assess-mutation-impact
    (prediction-id uint)
    (mutations (list 10 { position: uint, original: (string-ascii 3), mutated: (string-ascii 3) }))
    )
    (let (
        (prediction-data (unwrap! (map-get? protein-predictions prediction-id) ERR-NOT-FOUND))
    )
        (asserts! (or 
            (is-prediction-owner prediction-id tx-sender)
            (is-eq tx-sender CONTRACT-OWNER)
        ) ERR-UNAUTHORIZED)
        
        ;; Process each mutation (simplified implementation)
        (fold process-single-mutation mutations { prediction-id: prediction-id, mutation-counter: u0 })
        
        (ok (len mutations))
    )
)

(define-private (process-single-mutation
    (mutation { position: uint, original: (string-ascii 3), mutated: (string-ascii 3) })
    (context { prediction-id: uint, mutation-counter: uint })
    )
    (let (
        (mutation-id (+ (get mutation-counter context) u1))
        (stability-change (- 0 (* (to-int (get position mutation)) 2))) ;; Simplified calculation
    )
        (map-set mutation-effects 
            { prediction-id: (get prediction-id context), mutation-id: mutation-id }
            {
                original-residue: (get original mutation),
                mutated-residue: (get mutated mutation),
                position: (get position mutation),
                stability-change: stability-change,
                function-impact: u50,
                pathogenicity-score: u30,
                conservation-score: u70,
                structural-impact: "moderate",
                predicted-by: tx-sender,
                created-at: stacks-block-height
            }
        )
        { prediction-id: (get prediction-id context), mutation-counter: mutation-id }
    )
)

(define-public (simulate-folding
    (prediction-id uint)
    (simulation-params { temperature: uint, ph: uint, time: uint })
    )
    (let (
        (prediction-data (unwrap! (map-get? protein-predictions prediction-id) ERR-NOT-FOUND))
        (simulator tx-sender)
    )
        (asserts! (is-prediction-owner prediction-id tx-sender) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status prediction-data) "analyzed") ERR-INVALID-INPUT)
        
        (map-set folding-simulations prediction-id
            {
                prediction-id: prediction-id,
                simulator: simulator,
                simulation-time: (get time simulation-params),
                temperature: (get temperature simulation-params),
                ph-level: (get ph simulation-params),
                ionic-strength: u150,
                folding-pathway: (list "unfolded" "intermediate" "folded"),
                intermediate-states: (list u10 u50 u90),
                folding-rate: u1000,
                unfolding-rate: u10,
                created-at: stacks-block-height
            }
        )
        
        (map-set protein-predictions prediction-id
            (merge prediction-data
                {
                    updated-at: stacks-block-height,
                    status: "simulated"
                }
            )
        )
        
        (ok true)
    )
)

;; Read-only Functions

(define-read-only (get-prediction-results (prediction-id uint))
    (map-get? protein-predictions prediction-id)
)

(define-read-only (get-structure-coordinates (prediction-id uint))
    (map-get? structure-coordinates prediction-id)
)

(define-read-only (get-interaction-analysis (prediction-id uint))
    (map-get? interaction-analysis prediction-id)
)

(define-read-only (get-mutation-effects (prediction-id uint) (mutation-id uint))
    (map-get? mutation-effects { prediction-id: prediction-id, mutation-id: mutation-id })
)

(define-read-only (get-folding-simulation (prediction-id uint))
    (map-get? folding-simulations prediction-id)
)

(define-read-only (get-user-prediction-stats (user principal))
    (map-get? user-predictions user)
)

(define-read-only (get-quality-assessment (prediction-id uint))
    (map-get? quality-assessments prediction-id)
)

(define-read-only (get-prediction-count)
    (var-get prediction-counter)
)

(define-read-only (get-total-predictions)
    (var-get total-predictions)
)

(define-read-only (get-total-analyses)
    (var-get total-analyses)
)

(define-read-only (get-contract-revenue)
    (var-get contract-revenue)
)

