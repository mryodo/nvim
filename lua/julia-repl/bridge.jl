#!/usr/bin/env julia

using Sockets

socket_path = ARGS[1]

# Remove stale socket from a previous session.
if ispath(socket_path)
    rm(socket_path)
end

server = listen(socket_path)

println("Julia REPL bridge")
println("Listening on: ", socket_path)
println()

function evaluate(code)
    try
        # Wrap the code in a begin/end block so multiline selections
        # are parsed as one Julia expression.
        expr = Meta.parse("begin\n" * code * "\nend")

        result = Core.eval(Main, expr)

        if result !== nothing
            display(result)
            println()
        end
    catch err
        showerror(stdout, err, catch_backtrace())
        println()
    end

    return flush(stdout)
end

while true
    client = accept(server)

    try
        # Protocol:
        #
        # <number of UTF-8 bytes>\n
        # <Julia source>

        header = readline(client)
        len = parse(Int, header)

        data = read(client, len)
        code = String(data)

        println("julia> ", replace(code, "\n" => "\n       "))

        evaluate(code)
    catch err
        showerror(stdout, err, catch_backtrace())
        println()
        flush(stdout)
    finally
        close(client)
    end
end
