# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

mutable struct TestMsg <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestMsg(; kwargs...)
        obj = new(meta(TestMsg), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        obj
    end
end # mutable struct TestMsg
const __meta_TestMsg = Ref{ProtoMeta}()
function meta(::Type{TestMsg})
    ProtoBuf.metalock() do
        if !isassigned(__meta_TestMsg)
            __meta_TestMsg[] = target = ProtoMeta(TestMsg)
            allflds = Pair{Symbol,Union{Type,String}}[:x => Float64, :y => Float64, :z => Float64]
            meta(target, TestMsg, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_TestMsg[]
    end
end
function Base.getproperty(obj::TestMsg, name::Symbol)
    if name === :x
        return (obj.__protobuf_jl_internal_values[name])::Float64
    elseif name === :y
        return (obj.__protobuf_jl_internal_values[name])::Float64
    elseif name === :z
        return (obj.__protobuf_jl_internal_values[name])::Float64
    else
        getfield(obj, name)
    end
end

export TestMsg
