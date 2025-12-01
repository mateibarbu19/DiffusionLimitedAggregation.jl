module Original

using Random
using DelimitedFiles

# Type Aliases
const RowT = UInt16
const ElemT = UInt8

# Constants
const MASTER_SEED = UInt64(123456789)
const NEIGHBORS = (
    (-1, -1), (-1, 0), (-1, 1),
    ( 0, -1),          ( 0, 1),
    ( 1, -1), ( 1, 0), ( 1, 1)
)
const MOVES = [(0, 1), (0, -1), (1, 0), (-1, 0)]

width = RowT(1)
height = RowT(1)
map = zeros(ElemT, height, width)

# --- Input Parsing ---
function parse_inputs()
    args = deepcopy(ARGS)
    if length(args) < 4
        println("Usage: script.jl width height particles_count steps [start_col] [start_row] [out_map]")
        exit(1)
    end

    global width = parse(RowT, args[1])
    global height = parse(RowT, args[2])
    particles_count = parse(UInt, args[3])
    steps = parse(UInt, args[4])

    start_col = length(args) >= 6 ? parse(RowT, args[6]) : (div(width, 2) + 1)
    start_row = length(args) >= 5 ? parse(RowT, args[5]) : (div(height, 2) + 1)
    out_map = length(args) >= 7 ? args[7] : "crystal.txt"

    if start_col > width || start_row > height
        println("Starting point should be inside the matrix")
        exit(1)
    end

    return particles_count, steps, start_col, start_row, out_map
end

@enum State begin
    moving
    crystallized
end

# --- Particle Definition ---
mutable struct Particle
    row::UInt
    col::UInt

    state::State

    prng::Xoshiro
end
Base.show(io::IO, p::Particle) = print(io, "(row = $(p.row), col = $(p.col))")

function splitmix64(state::UInt64)::Tuple{UInt64,UInt64}
    state += 0x9E3779B97F4A7C15
    z = state
    z = (z ⊻ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ⊻ (z >> 27)) * 0x94D049BB133111EB
    z = z ⊻ (z >> 31)
    return z, state  # return both the result and the updated state
end

# Simple PRNG-based coordinate generator
function init_particle(index::UInt, width::RowT, height::RowT)::Particle

    first_seed = MASTER_SEED + index - 1
    s0, state = splitmix64(first_seed)
    s1, state = splitmix64(state)
    s2, state = splitmix64(state)
    s3, state = splitmix64(state)

    prng = Xoshiro(s0, s1, s2, s3)

    tmp = rand(prng, UInt64)
    col = (tmp % width) + 1
    tmp = rand(prng, UInt64)
    row = (tmp % height) + 1

    return Particle(row, col, moving, prng)
end

function should_crystalize(p::Particle)::Bool
    for (dr, dc) in NEIGHBORS
        nr, nc = p.row + dr, p.col + dc

        if 1 <= nr <= height && 1 <= nc <= width
            if map[nr, nc] > 0
                return true
            end
        end
    end

    return false
end

function move_particle!(p::Particle)
    tmp = rand(p.prng, UInt64)
    dir = MOVES[(tmp & 3) + 1]

    new_row = p.row + dir[1]
    new_col = p.col + dir[2]

    # Emulate bounce
    if new_row < 1
        new_row = RowT(2)
    elseif new_row > height
        new_row = height - 1
    end
    if new_col < 1
        new_col = RowT(2)
    elseif new_col > width
        new_col = width - 1
    end

    p.row = new_row
    p.col = new_col
end

# --- Main Simulation ---
function run_dla(steps, particles, map)
    for _ in 1:steps
        for p in particles
            if p.state == crystallized
                continue
            end

            if should_crystalize(p)
                map[p.row, p.col] += 1
                p.state = crystallized
            else
                move_particle!(p)
            end
        end
    end
end

function (@main)(ARGS)
    println("Original serial implementation: ", join(ARGS, " "))

    particles_count, steps, start_col, start_row, out_map = parse_inputs()

    global map = zeros(ElemT, height, width)

    map[start_row, start_col] = 1

    particles = [init_particle(i, width, height) for i in 1:particles_count]

    print("Simulation time: ")
    @timev run_dla(steps, particles, map)

    open(out_map, "w") do io
        write(io, string(height), ' ', string(width), '\n')
        writedlm(io, map, ' ')
    end
end

end
