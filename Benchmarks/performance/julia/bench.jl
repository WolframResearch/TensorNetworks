# ITensors fixed-path primitives and ITensorMPS native overlap/canonicalization.
using ITensors, ITensorMPS, JSON3, LinearAlgebra, Statistics, SHA

function readarray(root, spec)
    dims = Tuple(Int.(spec.shape))
    re = reinterpret(Float64, read(joinpath(root, spec.real)))
    length(re) == prod(dims) || error("wrong tensor length")
    # Files use C order; Julia's first array dimension is contiguous.
    value = permutedims(reshape(copy(re), reverse(dims)), reverse(1:length(dims)))
    if haskey(spec, :imag)
        imaginary = reinterpret(Float64, read(joinpath(root, spec.imag)))
        length(imaginary) == prod(dims) || error("wrong imaginary tensor length")
        value = value + complex(0, 1) * permutedims(reshape(copy(imaginary), reverse(dims)), reverse(1:length(dims)))
    end
    return value
end

function numericerror(value, reference)
    size(value) == size(reference) || error("wrong output shape")
    all(isfinite, value) || error("non-finite output")
    err = norm(value - reference) / max(1.0, norm(reference))
    isfinite(err) && err <= 1e-10 || error("normalized error exceeds 1e-10")
    return Float64(err)
end

function measure(case, implementation, task, fn, valid, protocol; mode="prepared")
    row = Dict{String,Any}("case" => case, "implementation" => implementation, "task" => task, "mode" => mode)
    try
        err = valid(fn())  # JIT and validation excluded from samples.
        count = 1
        while true
            start = time_ns()
            for _ in 1:count
                fn()
            end
            elapsed = (time_ns() - start) * 1e-9
            (elapsed >= protocol.sample_seconds || count >= 16384) && break
            count *= 2
        end
        timings = map(1:protocol.samples) do _
            start = time_ns()
            for _ in 1:count
                fn()
            end
            (time_ns() - start) * 1e-9 / count
        end
        valid(fn())
        merge!(row, Dict("status" => "ok", "normalized_error" => err,
            "samples_seconds" => timings, "iterations_per_sample" => count,
            "median_seconds" => median(timings), "min_seconds" => minimum(timings),
            "max_seconds" => maximum(timings)))
    catch exception
        row["status"] = "failed"
        row["error"] = first(sprint(showerror, exception), 300)
    end
    return row
end

function save(output, result)
    text = JSON3.write(result)
    sizeof(text) <= 8 * 1024^2 || error("result exceeds 8 MiB")
    write(output * ".tmp", text * "\n")
    mv(output * ".tmp", output; force=true)
end

function main(manifestpath, output)
    ENDIAN_BOM == 0x04030201 || error("little-endian host required")
    manifest = JSON3.read(read(manifestpath, String))
    root, protocol = dirname(manifestpath), manifest.protocol
    for spec in manifest.files
        file = joinpath(root, spec.path)
        filesize(file) == spec.bytes && bytes2hex(sha256(read(file))) == spec.sha256 || error("corpus checksum or size mismatch")
    end
    BLAS.set_num_threads(protocol.threads)
    ITensors.disable_threaded_blocksparse()
    if isdefined(ITensors, :Strided)
        ITensors.Strided.disable_threads()
    end
    result = Dict{String,Any}("schema_version" => 1, "corpus_sha256" => bytes2hex(sha256(read(manifestpath))),
        "backend" => "julia", "metadata" => Dict("julia" => string(VERSION),
            "ITensors" => string(pkgversion(ITensors)), "ITensorMPS" => string(pkgversion(ITensorMPS)),
            "JSON3" => string(pkgversion(JSON3)), "julia_threads" => Threads.nthreads(),
            "blas_threads" => BLAS.get_num_threads(), "blas_config" => string(BLAS.get_config())),
        "records" => Any[])
    rows = result["records"]
    push!(rows, measure("harness", "julia", "harness.noop", () -> 1, x -> numericerror(x, 1), protocol))
    for case in manifest.cases
        println(case.id)
        arrays = [readarray(root, spec) for spec in case.tensors]
        sizes = Dict(label => size(a, j) for (a, labels) in zip(arrays, case.labels) for (j, label) in enumerate(labels))
        indices = Dict(label => Index(dim, "audit-$(label)") for (label, dim) in sizes)
        makeobjects = () -> [ITensor(a, (indices[label] for label in labels)...)
                             for (a, labels) in zip(arrays, case.labels)]
        tensors = makeobjects()
        if case.family == "matrix_chain"
            reference = readarray(root, case.reference)
            outinds = [indices[label] for label in case.output]
            valid = x -> numericerror(Array(x, outinds...), reference)
            push!(rows, measure(case.id, "ITensors", "chain.prepare.objects", makeobjects,
                xs -> valid(foldl(*, xs)), protocol))
            push!(rows, measure(case.id, "ITensors", "chain.execute.fixed_path", () -> foldl(*, tensors), valid, protocol))
            changedvalues = copy(tensors)
            changedvalues[1] = 2 * tensors[1]
            push!(rows, measure(case.id, "ITensors", "chain.execute.new_values", () -> foldl(*, changedvalues),
                x -> numericerror(Array(x, outinds...), 2 * reference), protocol))
            supportfirst = ITensor(readarray(root, case.changed_first), (indices[label] for label in case.labels[1])...)
            changedsupport = copy(tensors)
            changedsupport[1] = supportfirst
            changedreference = readarray(root, case.changed_reference)
            push!(rows, measure(case.id, "ITensors", "chain.execute.changed_support", () -> foldl(*, changedsupport),
                x -> numericerror(Array(x, outinds...), changedreference), protocol))
            push!(rows, measure(case.id, "julia.BLAS", "chain.execute.fixed_path", () -> foldl(*, arrays),
                x -> numericerror(x, reference), protocol))
        else
            psi = MPS(tensors)
            sites = [indices[label] for label in case.output]
            reference = readarray(root, case.reference)
            push!(rows, measure(case.id, "ITensorMPS", "mps.overlap", () -> inner(psi, psi),
                x -> numericerror(x, case.norm_squared), protocol; mode="native_mps"))
            function validcanonical(x)
                orthocenter(x) == case.n || error("wrong orthogonality center")
                numericerror(Array(prod(x), sites...), reference)
            end
            push!(rows, measure(case.id, "ITensorMPS", "mps.left_canonical", () -> orthogonalize(psi, case.n),
                validcanonical, protocol; mode="native_mps"))
        end
        save(output, result)
    end
    result["metadata"]["process_peak_rss_bytes_julia"] = Sys.maxrss()
    save(output, result)
    return any(row["status"] != "ok" for row in rows) ? 1 : 0
end

exit(main(abspath(ARGS[1]), abspath(ARGS[2])))
