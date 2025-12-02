using Random
using DelimitedFiles
using LinearAlgebra

# Type aliases
const ElemT = UInt8
const RowT = UInt16
const CoordT = Tuple{RowT, RowT}
const RowL = Int64
const CoordL = Tuple{RowL, RowL}

const MASTER_SEED = UInt64(0x394934714f2ae5a4)
const NEIGHBORS = [
    (-1, -1), (-1, 0), (-1, 1),
    (0, -1), (0, 1),
    (1, -1), (1, 0), (1, 1)
]
const MOVES = [(0, 1), (0, -1), (1, 0), (-1, 0)]
const THRESHOLD_DIST = 2

# --- Input Parsing ---
function parse_inputs(args::Vector{String})
    if length(args) < 4
        println(Core.stdout, "Usage: script.jl width height particles_count steps [start_col] [start_row] [out_file]")
        exit(1)
    end

    width = parse(RowT, args[1])
    height = parse(RowT, args[2])
    particles_count = parse(UInt, args[3])
    steps = parse(UInt, args[4])

    start_col = length(args) >= 5 ? parse(RowT, args[5]) : (div(width, 2) + 1)
    start_row = length(args) >= 6 ? parse(RowT, args[6]) : (div(height, 2) + 1)
    out_file = length(args) >= 7 ? args[7] : "crystal.txt"

    if start_col > width || start_row > height
        println(Core.stdout, "Starting point should be inside the matrix")
        exit(1)
    end

    return (height, width), CoordL((start_row, start_col)), particles_count, steps, out_file
end

# --- Main Simulation ---
function run_dla(grid::Matrix{ElemT}, start::CoordL, steps::UInt, particles::Vector{CoordT}, prng::Xoshiro)
    height = size(grid, 1)
    width = size(grid, 2)

    active_count = size(particles, 1)

    max_dist = Float64(0)
    start_row = RowL(start[1])
    start_col = RowL(start[2])

    for _ in 1:steps
        i = UInt(1)

        while i <= active_count
            r, c = @inbounds particles[i]
            should_crystallized = false

            dist = √((r - start_row) ^ 2 + (c - start_col) ^ 2)

            if dist < (max_dist + THRESHOLD_DIST)
                # Test if the particle should crystallize
                for (dr, dc) in NEIGHBORS
                    nr, nc = r + dr, c + dc

                    if 1 <= nr <= height && 1 <= nc <= width
                        if @inbounds grid[nr, nc] > 0
                            should_crystallized = true
                            break
                        end
                    end
                end
            end

            if should_crystallized
                # Crystallize
                @inbounds grid[r, c] += 1

                max_dist = max(max_dist, dist)

                # Swap with last
                @inbounds particles[i] = @inbounds particles[active_count]
                # Pop last
                active_count -= 1
            else
                # Move particle
                dr, dc = rand(prng, MOVES)

                nr, nc = r + dr, c + dc

                # Bounce logic
                if nr < 1
                    nr = 2
                elseif nr > height
                    nr = height - 1
                end
                if nc < 1
                    nc = 2
                elseif nc > width
                    nc = width - 1
                end

                @inbounds particles[i] = nr, nc

                i += 1
            end
        end
    end

    for i in 1:active_count
        r, c = @inbounds particles[i]
        @inbounds grid[r, c] = 255
    end
end

function (@main)(args::Vector{String})::Cint
    shape, start, particles_count, steps, out_file = parse_inputs(args)

    grid = zeros(ElemT, shape)
    grid[start...] = 1

    height = shape[1]
    width = shape[2]

    prng = Xoshiro(MASTER_SEED)
    rows = rand(prng, Vector{RowT}(1:height), particles_count)
    cols = rand(prng, Vector{RowT}(1:width), particles_count)
    particles = collect(zip(rows, cols))

    run_dla(grid, start, steps, particles, prng)

    io = Base.open(out_file, "w")
    write(io, string(height) * ' ' * string(width) * '\n')
    writedlm(io, grid, ' ')

    return 0
end
