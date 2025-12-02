module DiffusionLimitedAggregation

function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "Main app: ", join(args, " "))
    println(Core.stdout, "It just prints its arguments!")

    return 0
end

end # module DiffusionLimitedAggregation
