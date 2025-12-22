using Random
using DelimitedFiles

# --- Input Parsing ---
function parse_inputs(args::Vector{String})
    if length(args) < 4
        println(Core.stdout, "Usage: script.jl width height particles_count steps [start_col] [start_row] [out_map]")
        exit(1)
    end

    width = parse(RowT, args[1])
    height = parse(RowT, args[2])
    particles_count = parse(UInt, args[3])
    steps = parse(UInt, args[4])

    start_col = length(args) >= 5 ? parse(RowT, args[5]) : (div(width, 2) + 1)
    start_row = length(args) >= 6 ? parse(RowT, args[6]) : (div(height, 2) + 1)
    out_map = length(args) >= 7 ? args[7] : "crystal.txt"

    if start_col > width || start_row > height
        println(Core.stdout, "Starting point should be inside the matrix")
        exit(1)
    end

    return width, height, particles_count, steps, start_col, start_row, out_map
end

# Type aliases
const RowT = UInt16
const ElemT = UInt8

const MASTER_SEED = UInt64(0x394934714f2ae5a4)
const NEIGHBORS = (
    (-1, -1), (-1, 0), (-1, 1),
    (0, -1), (0, 1),
    (1, -1), (1, 0), (1, 1)
)
const MOVES = [(0, 1), (0, -1), (1, 0), (-1, 0)]

# --- Main Simulation ---
function run_dla(steps::UInt, particles::Tuple{Vector{RowT},Vector{RowT}}, map::Matrix{ElemT}, prng::Xoshiro)
    height = size(map, 1)
    width = size(map, 2)

    (rows, cols) = particles
    active_count = size(rows, 1)

    for _ in 1:steps
        i = UInt(1)

        while i <= active_count
            r, c = rows[i], cols[i]
            should_crystallized = false

            for (dr, dc) in NEIGHBORS
                nr, nc = r + dr, c + dc

                if 1 <= nr <= height && 1 <= nc <= width
                    if @inbounds map[nr, nc] > 0
                        should_crystallized = true
                        break
                    end
                end
            end

            if should_crystallized
                # Crystallize
                @inbounds map[r, c] += 1

                # Swap with last
                rows[i] = rows[active_count]
                cols[i] = cols[active_count]
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

                rows[i] = nr
                cols[i] = nc

                i += 1
            end
        end

        if active_count == 0
            break
        end
    end
end

function (@main)(args::Vector{String})::Cint
    width, height, particles_count, steps, start_col, start_row, out_map = parse_inputs(args)

    map = zeros(ElemT, height, width)

    map[start_row, start_col] = 1

    prng = Xoshiro(MASTER_SEED)
    particles_rows = rand(prng, Vector{RowT}(1:height), particles_count)
    particles_cols = rand(prng, Vector{RowT}(1:width), particles_count)

    run_dla(steps, (particles_rows, particles_cols), map, prng)

    io = Base.open(out_map, "w")
    write(io, string(height) * ' ' * string(width) * '\n')
    writedlm(io, map, ' ')
    Base.close(io)

    return 0
end
