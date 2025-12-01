module DiffusionLimitedAggregation

greet() = print("Hello World!")

function (@main)(ARGS)
    println("Main app: ", join(ARGS, " "))
end

include("serial/Serial.jl")

end # module DiffusionLimitedAggregation
