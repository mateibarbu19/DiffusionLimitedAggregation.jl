# Diffusion-limited aggregation

[Wikipedia reference](https://en.wikipedia.org/wiki/Diffusion-limited_aggregation)

## Development environment

Here's how to get started.
(With an impure nix shell.)

```
$ nix build .#devShells.x86_64-linux.default
$ nix develop .
# the julia project is set to the current directory through an environment variable
$ julia
julia> ]
pkg> instantiate
pkg> app add JuliaC
```

## Running something

```sh
$ julia -m DiffusionLimitedAggregation miau or bark
Main app: miau or bark
It just prints its arguments!
$ julia src/serial/Original.jl 11 11 3 100
Simulation time:   0.078976 seconds (56.02 k allocations: 2.681 MiB, 99.61% compilation time)
elapsed time (ns):  7.8976387e7
gc time (ns):       0
bytes allocated:    2811560
pool allocs:        55979
non-pool GC allocs: 0
malloc() calls:     43
free() calls:       0
minor collections:  0
full collections:   0
```

## Compiling something

This package is actually a collection of scripts.
The package itself only prints its arguments.
But for demonstration purposes lets compile the package first.

```sh
# this first compilation takes a longer time
$ juliac --trim --output-exe main --bundle build .
$ ./build/bin/main something anotherthing
Main app: something anotherthing
It just prints its arguments!
# cleanup
$ rm -rf build
# use make as a shorthand
$ make build/bin/main
```

Now, if you want to compile a script take this steps.

```sh
$ juliac --trim --output-exe improved src/serial/Improved.jl
$ ./improved 501 501 10000 40000
# use the makefile for a shorthand
# rules exist to build binaries that match just the script name.
$ make build/bin/Improved
```

The [original script](src/serial/Original.jl) is not compilable on purpose!

## Profiling

### My way

```
$ julia src/FileWithProfiling.jl [params] --profiling_file prof.log
$ ./tools/annotate_source.sh prof.log | bat -l julia
```

### The traditional way

Modify a Julia source as follows.

```julia
using Profile
using PProf

Profile.clear()
@profile run_dla(grid, start, steps, particles, prng)
# or @profile_walltime
pprof(web=false)
```

Then trigger the profiling.

```sh
# Generate analysis
$ julia src/serial/SimpleCircleCheck.jl 501 501 10000 100000 251 251 /mnt/my-ramdisk/crystal.txt
# View it
$ pprof -http=:8080 profile.pb.gz
```

## References

> However writing a multi-threaded code [...] is difficult [...]
> It is not auto-magical and requires several hours spent on understanding the concepts.
> [...]
> Julia code outperform MATLAB's code. However writing a performant code is not easy.
> [Przemyslaw Szufel](https://stackoverflow.com/a/76890223)

- [YouTube: Intro to Scientific Computing in Julia](https://youtu.be/_iQr9lNCTpY?si=9_zf_aQuJWpPIbj-)
  - [Sources](https://github.com/julia4ta/tutorials/tree/master/Series%2008)
- [Julia Doc: Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/)
- [Julia Doc: Profiling](https://docs.julialang.org/en/v1/manual/profile/)
- [Julia Doc: Multi-Threading](https://docs.julialang.org/en/v1/manual/multi-threading/)
- [JuliaC](https://github.com/JuliaLang/JuliaC.jl)
- [JuliaC examples](https://github.com/jbytecode/juliac)
- [OhMyThreads.jl](https://juliafolds2.github.io/OhMyThreads.jl/stable/)
- [BenchmarkTools.jl](https://juliaci.github.io/BenchmarkTools.jl/dev/manual/)

### Nice to know

- [YouTube: New Ways to Compile Julia](https://youtu.be/MKdobiCKSu0)
- [YouTube: Multi-Threading Using Julia for Enterprises](https://youtu.be/FzhipiZO4Jk?si=RK2BdxpUyqbcxuSs)
- [YouTube: OhMyThreads.jl](https://youtu.be/bb0zUNe32KU)
- [JET.jl](https://github.com/aviatesk/JET.jl)
