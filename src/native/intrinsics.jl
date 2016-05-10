# Native intrinsics

export
    # Indexing and dimensions
    # TODO: dynamically export
    threadIdx,
    blockDim, blockIdx,
    gridDim,
    warpsize,

    # Memory management
    sync_threads,
    cuSharedMem, setCuSharedMem, getCuSharedMem,
    cuSharedMem_i64, setCuSharedMem_i64, getCuSharedMem_i64,
    cuSharedMem_double, setCuSharedMem_double, getCuSharedMem_double



#
# Indexing and dimensions
#

for dim in (:x, :y, :z)
    # Thread index
    fname = Symbol("threadIdx_$dim")
    intrinsic = "llvm.nvvm.read.ptx.sreg.tid.$dim"
    @eval begin
        $fname() = Base.llvmcall(
            ($("""declare i32 @$intrinsic() readnone nounwind"""),
             $("""%1 = tail call i32 @$intrinsic()
                  ret i32 %1""")),
            Int32, Tuple{}) + 1
    end

    # Block dimension (#threads per block)
    fname = Symbol("blockDim_$dim")
    intrinsic = "llvm.nvvm.read.ptx.sreg.ntid.$dim"
    @eval begin
        $fname() = Base.llvmcall(
            ($("""declare i32 @$intrinsic() readnone nounwind"""),
             $("""%1 = tail call i32 @$intrinsic()
                  ret i32 %1""")),
            Int32, Tuple{})
    end

    # Block index
    fname = Symbol("blockIdx_$dim")
    intrinsic = "llvm.nvvm.read.ptx.sreg.ctaid.$dim"
    @eval begin
        $fname() = Base.llvmcall(
            ($("""declare i32 @$intrinsic() readnone nounwind"""),
             $("""%1 = tail call i32 @$intrinsic()
                  ret i32 %1""")),
            Int32, Tuple{}) + 1
    end

    # Grid dimension (#blocks)
    fname = Symbol("gridDim_$dim")
    intrinsic = "llvm.nvvm.read.ptx.sreg.nctaid.$dim"
    @eval begin
        $fname() = Base.llvmcall(
            ($("""declare i32 @$intrinsic() readnone nounwind"""),
             $("""%1 = tail call i32 @$intrinsic()
                  ret i32 %1""")),
            Int32, Tuple{})
    end
end

# Tuple accessors
threadIdx() = dim3(threadIdx_x(), threadIdx_y(), threadIdx_z())
blockDim() =  dim3(blockDim_x(),  blockDim_y(),  blockDim_z())
blockIdx() =  dim3(blockIdx_x(),  blockIdx_y(),  blockIdx_z())
gridDim() =   dim3(gridDim_x(),   gridDim_y(),   gridDim_z())

# Warpsize
warpsize() = Base.llvmcall(
    ("""declare i32 @llvm.nvvm.read.ptx.sreg.warpsize() readnone nounwind""",
     """%1 = tail call i32 @llvm.nvvm.read.ptx.sreg.warpsize()
        ret i32 %1"""),
    Int32, Tuple{})


#
# Thread management
#

# Synchronization
sync_threads() = Base.llvmcall(
    ("""declare void @llvm.nvvm.barrier0() readnone nounwind""",
     """call void @llvm.nvvm.barrier0()
        ret void"""),
    Void, Tuple{})


#
# Shared memory
#

# TODO: generalize for types
# TODO: static shared memory
# TODO: wrap this in a class, using get and setindex
# FIXME: it is a hack to declare the p0,p3 intrinsic in cuSharedMem,
#        but declaring it in the setters and getters results in two declarations
# TODO: This is broken. Besides, the new llvmcall parses declarations,
#       so the @shmem assignment now only works because of chance

# Shared memory for type Float32
cuSharedMem() = Base.llvmcall(
    ("""@shmem_f32 = external addrspace(3) global [0 x float]""",
     """%1 = getelementptr inbounds [0 x float], [0 x float] addrspace(3)* @shmem_f32, i64 0, i64 0
        %2 = addrspacecast float addrspace(3)* %1 to float addrspace(0)*
        ret float* %2"""),
    Ptr{Float32}, Tuple{})
setCuSharedMem(shmem, index, value) = Base.llvmcall(
     """%4 = addrspacecast float addrspace(0)* %0 to float addrspace(3)*
        %5 = getelementptr inbounds float, float addrspace(3)* %4, i64 %1
        store float %2, float addrspace(3)* %5
        ret void""",
    Void, Tuple{Ptr{Float32}, Int64, Float32}, shmem, index-1, value)
getCuSharedMem(shmem, index) = Base.llvmcall(
     """%3 = addrspacecast float addrspace(0)* %0 to float addrspace(3)*
        %4 = getelementptr inbounds float, float addrspace(3)* %3, i64 %1
        %5 = load float, float addrspace(3)* %4
        ret float %5""",
    Float32, Tuple{Ptr{Float32}, Int64}, shmem, index-1)

# Shared memory for type Int64
cuSharedMem_i64() = Base.llvmcall(
    ("""@shmem_i64 = external addrspace(3) global [0 x i64]""",
     """%1 = getelementptr inbounds [0 x i64], [0 x i64] addrspace(3)* @shmem_i64, i64 0, i64 0
        %2 = addrspacecast i64 addrspace(3)* %1 to i64 addrspace(0)*
        ret i64* %2"""),
    Ptr{Int64}, Tuple{})
setCuSharedMem_i64(shmem, index, value) = Base.llvmcall(
     """%4 = addrspacecast i64 addrspace(0)* %0 to i64 addrspace(3)*
        %5 = getelementptr inbounds i64, i64 addrspace(3)* %4, i64 %1
        store i64 %2, i64 addrspace(3)* %5
        ret void""",
    Void, Tuple{Ptr{Int64}, Int64, Int64}, shmem, index-1, value)
getCuSharedMem_i64(shmem, index) = Base.llvmcall(
     """%3 = addrspacecast i64 addrspace(0)* %0 to i64 addrspace(3)*
        %4 = getelementptr inbounds i64, i64 addrspace(3)* %3, i64 %1
        %5 = load i64, i64 addrspace(3)* %4
        ret i64 %5""",
    Int64, Tuple{Ptr{Int64}, Int64}, shmem, index-1)

# Shared memory for type Float64
cuSharedMem_double() = Base.llvmcall(
    ("""@shmem_f64 = external addrspace(3) global [0 x double]""",
     """%1 = getelementptr inbounds [0 x double], [0 x double] addrspace(3)* @shmem_f64, i64 0, i64 0
        %2 = addrspacecast double addrspace(3)* %1 to double addrspace(0)*
        ret double* %2"""),
    Ptr{Float64}, Tuple{})
setCuSharedMem_double(shmem, index, value) = Base.llvmcall(
     """%4 = addrspacecast double addrspace(0)* %0 to double addrspace(3)*
        %5 = getelementptr inbounds double, double addrspace(3)* %4, i64 %1
        store double %2, double addrspace(3)* %5
        ret void""",
    Void, Tuple{Ptr{Float64}, Int64, Float64}, shmem, index-1, value)
getCuSharedMem_double(shmem, index) = Base.llvmcall(
     """%3 = addrspacecast double addrspace(0)* %0 to double addrspace(3)*
        %4 = getelementptr inbounds double, double addrspace(3)* %3, i64 %1
        %5 = load double, double addrspace(3)* %4
        ret double %5""",
    Float64, Tuple{Ptr{Float64}, Int64}, shmem, index-1)


#
# Math
#

# Trigonometric
sin(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_sinf(float)""",
     """%2 = call float @__nv_sinf(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
sin(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_sin(double)""",
     """%2 = call double @__nv_sin(double %0)
        ret double %2"""),
    Float64, Tuple{Float64} , x)
cos(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_cosf(float)""",
     """%2 = call float @__nv_cosf(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
cos(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_cos(double)""",
     """%2 = call double @__nv_cos(double %0)
        ret double %2"""),
    Float64, Tuple{Float64}, x)

# Rounding
floor(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_floorf(float)""",
     """%2 = call float @__nv_floorf(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
floor(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_floor(double)""",
     """%2 = call double @__nv_floor(double %0)
        ret double %2"""),
    Float64, Tuple{Float64}, x)
ceil(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_ceilf(float)""",
     """%2 = call float @__nv_ceilf(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
ceil(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_ceil(double)""",
     """%2 = call double @__nv_ceil(double %0)
        ret double %2"""),
    Float64, Tuple{Float64}, x)
abs(x::Int32) = Base.llvmcall(
    ("""declare i32 @__nv_abs(i32)""",
     """%2 = call i32 @__nv_abs(i32 %0)
        ret i32 %2"""),
    Int32, Tuple{Int32}, x)
abs(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_fabsf(float)""",
     """%2 = call float @__nv_fabsf(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
abs(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_fabs(double)""",
     """%2 = call double @__nv_fabs(double %0)
        ret double %2"""),
    Float64, Tuple{Float64}, x)

# Square root
sqrt(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_sqrtf(float)""",
     """%2 = call float @__nv_sqrtf(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
sqrt(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_sqrt(double)""",
     """%2 = call double @__nv_sqrt(double %0)
        ret double %2"""),
    Float64, Tuple{Float64}, x)

# Log and exp
exp(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_expf(float)""",
     """%2 = call float @__nv_expf(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
exp(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_exp(double)""",
     """%2 = call double @__nv_exp(double %0)
        ret double %2"""),
    Float64, Tuple{Float64}, x)
log(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_logf(float)""",
     """%2 = call float @__nv_logf(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
log(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_log(double)""",
     """%2 = call double @__nv_log(double %0)
        ret double %2"""),
    Float64, Tuple{Float64}, x)
log10(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_log10f(float)""",
     """%2 = call float @__nv_log10f(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
log10(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_log10(double)""",
     """%2 = call double @__nv_log10(double %0)
        ret double %2"""),
    Float64, Tuple{Float64}, x)
erf(x::Float32) = Base.llvmcall(
    ("""declare float @__nv_erff(float)""",
     """%2 = call float @__nv_erff(float %0)
        ret float %2"""),
    Float32, Tuple{Float32}, x)
erf(x::Float64) = Base.llvmcall(
    ("""declare double @__nv_erf(double)""",
     """%2 = call double @__nv_erf(double %0)
        ret double %2"""),
    Float64, Tuple{Float64}, x)
