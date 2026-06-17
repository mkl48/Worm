export type WormEnum = "MLP" | "QLEARN" | "CSF" | "NEAT"

export type ActivationName = "relu" | "sigmoid" | "tanh" | "softmax" | "leaky_relu"
export type OptimizerName  = "sgd" | "adam" | "rmsprop"
export type PoolName       = "max" | "avg"
export type GradeStyle     = "ordinal" | "polarity" | "pairs"
export type PolarityValue  = "+critical" | "+high" | "+medium" | "+low"
                           | "-critical" | "-high" | "-medium" | "-low"
export type MarginValue    = "large" | "medium" | "small"

export type SchemaField = {
    range: { number },
}

export type Schema = { [string]: SchemaField }

export type MLPConfig = {
    inputs:             number,
    outputs:            number,
    hidden:             { number }?,
    activation:         ActivationName?,
    output_activation:  ActivationName?,
    optimizer:          OptimizerName?,
    lr:                 number?,
    schema:             Schema?,
}

export type QLearnConfig = {
    states:         number,
    actions:        number,
    gamma:          number?,
    epsilon:        number?,
    epsilon_decay:  number?,
    epsilon_min:    number?,
    memory:         number?,
    batch:          number?,
    lr:             number?,
    schema:         Schema?,
}

export type CSFConfig = {
    grid:    { number },
    filters: number?,
    kernel:  number?,
    stride:  number?,
    pool:    PoolName?,
    outputs: number,
    schema:  Schema?,
}

export type NEATConfig = {
    inputs:             number,
    outputs:            number,
    population:         number?,
    persist:            boolean?,
    mutation_rate:      number?,
    weight_mutation:    number?,
    weight_perturb:     number?,
    crossover_rate:     number?,
    species_threshold:  number?,
    schema:             Schema?,
}

export type OrdinalEvents  = { [string]: number }
export type PolarityEvents = { [string]: PolarityValue }
export type PairEvent = {
    better: string,
    worse:  string,
    margin: MarginValue,
}

export type GradeConfig = {
    style:  GradeStyle,
    events: OrdinalEvents | PolarityEvents | { PairEvent },
    pin:    { [string]: number }?,
}

export type MLPLessonSingle = {
    input: { [string]: number } | { number },
    label: string,
}

export type MLPLessonBatch = { MLPLessonSingle }

export type QLearnLesson = {
    state:  { [string]: number } | { number },
    action: number,
    next:   { [string]: number } | { number },
    reward: string | number,
    done:   boolean,
}

export type NEATLesson = {
    evaluate:    (genome: Profile) -> number,
    generations: number?,
    on_evolve:   ((gen: number, best: NEATGenome) -> ())?,
}

export type NEATGenome = {
    fitness:  number,
    infer:    (input: any) -> any,
    export:   () -> table,
}

export type NEATStats = {
    generation:    number,
    best_fitness:  number,
    species_count: number,
}

export type Snapshot = {
    name:    string,
    weights: any,
}

export type ExportData = {
    _worm_type:   WormEnum,
    _worm_ver:    string,
    config:       any,
    weights:      any,
    labels:       { string }?,
    label_map:    { [string]: number }?,
    grade_config: GradeConfig?,
    grade_resolved: { [string]: number }?,
    snapshots:    { Snapshot }?,
    optimizer_state: any?,
    neat_population: any?,
}

export type Profile = {
    infer:      (self: Profile, input: any) -> Promise,
    lesson:     (self: Profile, data: any) -> Promise,
    interpret:  (self: Profile, fn: (raw: any) -> any) -> (),
    labels:     (self: Profile, list: { string }) -> (),
    grade:      (self: Profile, config: GradeConfig) -> (),
    grades:     (self: Profile) -> { [string]: number },
    rewards:    (self: Profile, map: { [string]: number }) -> (),
    export:     (self: Profile) -> Promise,
    import:     (self: Profile, data: ExportData) -> Promise,
    reset:      (self: Profile) -> (),
    tag:        (self: Profile, name: string) -> (),
    rollback:   (self: Profile, name: string) -> (),
    history:    (self: Profile) -> { string },
    type:       (self: Profile) -> WormEnum,
    evolve:     (self: Profile) -> Promise,
    champion:   (self: Profile) -> Profile,
}

export type Promise = {
    next:    (self: Promise, fn: (...any) -> any) -> Promise,
    toss:    (self: Promise, fn: (...any) -> any) -> Promise,
    finally: (self: Promise, fn: (...any) -> any) -> Promise,
}

return {}
