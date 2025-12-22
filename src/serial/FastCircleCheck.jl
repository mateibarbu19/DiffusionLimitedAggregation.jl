using ArgParse: ArgParseSettings, add_arg_group!, @add_arg_table!, parse_args
using Random: Xoshiro, rand
using DelimitedFiles: writedlm
using KernelAbstractions.Extras.LoopInfo: @unroll

using BenchmarkTools: @benchmarkable, run

using Profile
using InteractiveUtils

using YAML
using OrderedCollections
using Dates

# Type aliases
const ElemT = UInt8
const RowT = UInt16
const CoordT = Tuple{RowT, RowT}
const RowTL = Int64
const CoordTL = Tuple{RowTL, RowTL}
const DistT = UInt64

const FRACTAL_DIMENSION = Float64(1.71)

const MASTER_SEED = UInt64(0x394934714f2ae5a4)
const NEIGHBORS = @. CoordTL((
    (-1, -1), (-1, 0), (-1, 1),
    (0, -1), (0, 1),
    (1, -1), (1, 0), (1, 1)
))
const MOVES = @. CoordTL(((0, 1), (0, -1), (1, 0), (-1, 0)))
const THRESHOLD_DIST = DistT(2)

const CACHED_RESULT = Ref{Matrix{ElemT}}()

macro if_flag(flag, expr)
    if flag
        # 'esc' prevents the macro from renaming variables (hygiene)
        return esc(expr)
    else
        return nothing
    end
end

const WRITE_STATS = false
const global_storage = Ref(Int[])
macro if_track_stats(expr)
    return :(@if_flag($WRITE_STATS, $(esc(expr))))
end

const WRITE_UNCRYSTALLIZED = false
macro if_dump_uncrystallized(expr)
    return :(@if_flag($WRITE_UNCRYSTALLIZED, $(esc(expr))))
end

# --- Input Parsing ---
function parse_inputs(args::Vector{String})
    s = ArgParseSettings("Diffusion-limited Aggregation simulation")

    add_arg_group!(s, "Simulation setup", exclusive=true, required=true)
    @add_arg_table! s begin
        "--new", "-n"
            action = :store_arg
            arg_type = RowT

            dest_name = "square_side_length"
            help = "simulate for a square surface with a resulting fractal dimension of " * string(FRACTAL_DIMENSION)

        "--old"
            action = :store_arg
            nargs = 4
            arg_type = UInt
            metavar = ["WIDTH", "HEIGHT", "PARTICLES_COUNT", "STEPS"]
            help = "set your own simulation parameters"
    end

    add_arg_group!(s, "More optional arguments", required=false)
    @add_arg_table! s begin
        "--start"
            action = :store_arg
            nargs = 2
            arg_type = RowT
            metavar = ["ROW", "COLUMN"]
            help = "starting particle position"

        "--steps"
            action = :store_arg
            arg_type = UInt
            # default = nothing
            help = "number of simulation steps"

        "--output", "-o"
            arg_type = String
            action = :store_arg
            dest_name = "output_file"
            default = "crystal.txt"
            help = "output file name"

        "--benchmark", "-b"
            arg_type = String
            action = :store_arg
            arg_type = Int
            dest_name = "samples_count"
            default = 0
            help = "how many benchmark samples to run"

        "--profiling_file", "-p"
            arg_type = String
            action = :store_arg
            arg_type = String
            help = "enable profiling and save to a file"
    end

    parsed_args = parse_args(args, s)

    old = parsed_args["old"]
    if length(old) != 0
        shape = CoordT((old[1], old[2]))
        particles_count = old[3]
        steps = old[4]
    else
        height = parsed_args["square_side_length"]
        shape = (height, height)

        tmp = (4 / pi) * (height / 2) ^ FRACTAL_DIMENSION
        particles_count = UInt(floor(tmp))

        steps = typemax(UInt)
        if !isnothing(parsed_args["steps"])
            steps = parsed_args["steps"]
        end
    end

    if length(parsed_args["start"]) != 0
        start = CoordTL(parsed_args["start"])
    else
        start = CoordTL(@. div(shape, 2) + 1)
    end

    return shape, start, particles_count, steps, parsed_args["output_file"], parsed_args["samples_count"], parsed_args["profiling_file"]
end

get_arity(t::Tuple{Vararg{Any, N}}) where N = N

@inline function should_crystallize(row, col, height, width, grid)
    @inbounds @unroll for i in 1:get_arity(NEIGHBORS)
        dr, dc = NEIGHBORS[i]
        nr, nc = row + dr, col + dc

        if 1 <= nr <= height && 1 <= nc <= width
            if grid[nr, nc] > 0
                return true
            end
        end
    end

    return false
end

@inline function move_particle(row, col, height, width, prng)
    # Move particle
    dr, dc = rand(prng, MOVES)

    nr, nc = row + dr, col + dc

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

    # ATTOW, if we return a tuple, Julia can't optimize the cast
    a = nr % RowT
    b = nc % RowT

    return a, b
end

# --- Main Simulation ---
function run_dla(grid::Matrix{ElemT}, start::CoordTL, steps::UInt, particles::Vector{CoordT}, prng::Xoshiro)::Nothing
    height, width = size(grid) .% RowTL

    active_count = length(particles)

    max_dist_plus_th = THRESHOLD_DIST^2
    start_row = start[1]
    start_col = start[2]

    for _ in 1:steps
        i::typeof(active_count) = 1
        @if_track_stats crystallized_cnt = 0

        @inbounds while i <= active_count
            r, c = particles[i] .% RowTL

            dist = ((r - start_row) ^ 2 + (c - start_col) ^ 2) % DistT

            crystallized = false
            if dist < max_dist_plus_th
                crystallized = should_crystallize(r, c, height, width, grid)
            end

            if crystallized
                # Allow overflow, not wise, but consistent with C version
                grid[r, c] = (1 + grid[r, c]) % ElemT

                potential_new_max = Base.unsafe_trunc(DistT, ceil((√dist + THRESHOLD_DIST) ^ 2))
                max_dist_plus_th = max(max_dist_plus_th, potential_new_max)

                # Swap with last
                particles[i] = particles[active_count]
                # Pop last
                active_count -= 1

                @if_track_stats crystallized_cnt += 1
            else
                particles[i] = move_particle(r, c, height, width, prng)
                i += 1
            end
        end

        if active_count == 0
            break
        end

        @if_track_stats if crystallized_cnt > 0
            v = global_storage[]
            push!(v, crystallized_cnt)
        end
    end

    @if_dump_uncrystallized @inbounds for i in 1:active_count
        r, c = particles[i]
        grid[r, c] = 255
    end

    if !isassigned(CACHED_RESULT)
        CACHED_RESULT[] = grid
    end

    return
end

function (@main)(args::Vector{String})::Cint
    shape, start, particles_count, steps, out_file, samples_count, profiling_file = parse_inputs(args)
    println("Running a DLA simulation.")
    println("Grid shape: ", string(Int.(shape)))
    println("Starting point: ", string(Int.(start)))
    println("Particles count: ", particles_count)
    println("Steps: ", steps)
    println("Output file: ", out_file)
    println("Benchmark sample size: ", samples_count)

    grid = zeros(ElemT, shape)
    grid[start...] = 1

    height = shape[1]
    width = shape[2]

    prng = Xoshiro(MASTER_SEED)
    rows = rand(prng, Vector{RowT}(1:height), particles_count)
    cols = rand(prng, Vector{RowT}(1:width), particles_count)
    particles = collect(zip(rows, cols))

    if samples_count > 0
        b = @benchmarkable(
            run_dla(g, $start, $steps, ps, p),
            setup=(g=copy($grid); ps=copy($particles); p=copy($prng)),

            seconds=typemax(Float64),
            evals=1,
            overhead=300, # nanoseconds
            samples=samples_count,
            gcsample=true,
        )

        trail = run(b)
        display(trail)

        _, delay = Profile.init()

        grid = CACHED_RESULT[]
    elseif !isnothing(profiling_file)
        _, delay = Profile.init()
        metadata = OrderedDict(
            "script_path"  => abspath(PROGRAM_FILE),
            "output_file" => out_file,
            "grid_shape" => Int.(shape),
            "start" => Int.(start),
            "particles_count" => particles_count,
            "steps" => steps,
            "sampling_delay" => delay,
            "timestamp" => now(),
            "source_code" => read(PROGRAM_FILE, String),
        )

        @profile run_dla(grid, start, steps, particles, prng)

        buf = IOBuffer()
        println(buf, "Un1nT3r3sT1Ng_StTr1nG")
        Profile.print(IOContext(buf, :displaysize => (100000, 10000)), format=:flat)
        metadata["profiling_data"] = String(take!(buf))

        YAML.write_file(profiling_file, metadata)
    else
        # Helpers just in case
        # InteractiveUtils.@code_warntype run_dla(grid, start, steps, particles, prng)
        # InteractiveUtils.@code_llvm run_dla(grid, start, steps, particles, prng)
        # InteractiveUtils.@code_native run_dla(grid, start, steps, particles, prng)

        @time run_dla(grid, start, steps, particles, prng)
    end

    open(out_file, "w") do io
        write(io, string(height), ' ', string(width), '\n')
        writedlm(io, grid, ' ')
    end

    @if_track_stats begin
        open("/mnt/my-ramdisk/stats.txt", "w") do io
            writedlm(io, global_storage[], '\n')
        end
    end

    return 0
end
