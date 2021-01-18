module CUSPARSE

using ..APIUtils

using ..CUDA
using ..CUDA: CUstream, cuComplex, cuDoubleComplex, libraryPropertyType, cudaDataType
using ..CUDA: libcusparse, unsafe_free!, @retry_reclaim

using CEnum

using LinearAlgebra
using LinearAlgebra: HermOrSym

using Adapt

using SparseArrays

const SparseChar = Char

# core library
include("libcusparse_common.jl")
include("error.jl")
include("libcusparse.jl")
include("libcusparse_deprecated.jl")

include("array.jl")
include("util.jl")
include("types.jl")

# low-level wrappers
include("helpers.jl")
include("management.jl")
include("level1.jl")
include("level2.jl")
include("level3.jl")
include("preconditioners.jl")
include("conversions.jl")
include("generic.jl")

# high-level integrations
include("interfaces.jl")

# thread cache for task-local library handles
const thread_handles = Vector{Union{Nothing,cusparseHandle_t}}()

function handle()
    tid = Threads.threadid()
    if @inbounds thread_handles[tid] === nothing
        ctx = context()
        thread_handles[tid] = get!(task_local_storage(), (:CUSPARSE, ctx)) do
            handle = cusparseCreate()
            finalizer(current_task()) do task
                CUDA.isvalid(ctx) || return
                context!(ctx) do
                    cusparseDestroy(handle)
                end
            end

            handle
        end
        cusparseSetStream(thread_handles[tid], CUDA.stream_per_thread())
    end
    something(@inbounds thread_handles[tid])
end

function reset_stream()
    # NOTE: we 'abuse' the thread cache here, as switching streams doesn't invalidate it,
    #       but we (re-)apply the current stream when populating that cache.
    tid = Threads.threadid()
    thread_handles[tid] = nothing
end

function __init__()
    resize!(thread_handles, Threads.nthreads())
    fill!(thread_handles, nothing)

    CUDA.atdeviceswitch() do
        tid = Threads.threadid()
        thread_handles[tid] = nothing
    end

    CUDA.attaskswitch() do
        tid = Threads.threadid()
        thread_handles[tid] = nothing
    end
end

end
