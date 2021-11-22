"""
    Entry Specifying the
"""
struct MercurySpecEntry
    topic_name::String
    address::IPv4
    port_number::Int32
    message::Hg.MercuryMessage
    field::Union{Nothing, Symbol}
end

function MercurySpecEntry(
    rel_dir::String,
    topic_name_str::String,
    address_str::String,
    port_number::Int,
    message_str::Union{String, Int},
    field_str::Union{Nothing, String},
)
    local message::Hg.MercuryMessage

    if message_str isa Int
        message = Vector{UInt8}(undef, message_str)
    else
        filename, protobuf_name_string = split(message_str, ":"; limit=2)
        filename = joinpath(rel_dir, filename)

        isfile(filename) || throw(MercuryLoggerError(""""Message" specifier expected to be `Int` or a string "<path_to_proto.jl>:<NameOfProto>" """))

        # Only include file if the message does not appear to have been imported previously
        protobuf_sym = Meta.parse(protobuf_name_string)
        # message = eval( Meta.parse(protobuf_name_string*"()") )
        if !isdefined(@__MODULE__, protobuf_sym)
            # Base.MainInclude.include(filename)
            # Base.include(MercuryTools, filename)
            include(filename)
            # include_dependency(filename)
            # display(include_dependency(filename))
            Base.invokelatest(meta, eval(protobuf_sym))
        end
        message = eval(Meta.parse(protobuf_name_string*"()") )
        # display(Meta.parse(protobuf_name_string*"()"))
        # println(Meta.parse(protobuf_name_string*"()"))
        # Base.invokelatest(Meta.parse(protobuf_name_string*"()"))
        # Base.invokelatest(eval(Meta.parse(protobuf_name_string)))
        # Base.@invokelatest Meta.parse(protobuf_name_string*"()")
    end

    field_sym = nothing
    if field_str isa String
        field_sym = Meta.parse(field_str)
        (field_sym in propertynames(message)) || throw(MercuryLoggerError("Message `$(typeof(message))` has no field `$field_str`"))
    end

    return MercurySpecEntry(topic_name_str, IPv4(address_str), port_number, message, field_sym)
end


"""
    Parse TOML file for easy specifying messages and message types

# Example:
```toml
# All MercurySpec toml files should have title field with value "MercurySpec"
Title = "MercurySpec"

# Name of the first topic
[Test_Msg]
    Address = "127.0.0.1"   # IPv4 address and
    Port = 5555             # Port number of incoming message
    # For messages which contain ProtoBuf values, `Message` field should be "<path_to_proto.jl>:<NameOfProtoBuf>"
    Message = "proto/test_msg_pb.jl:TestMsg"
    # If you plan to plot a specific field in the message
    Plot_Field = "x"

[Motor_Msg]
    Address = "127.0.0.1"
    Port = 5556
    # For messages which contain byte vectors, `Message` field integer # of bytes
    Message = 256
```

# NOTE * `"<path_to_proto.jl>:<NameOfProtoBuf>"` should specify a protocol buffer julia file RELATIVE
to the protocol buffer toml file itself.
"""
function parse_toml(toml_specifier::String)
    rel_dir = dirname(toml_specifier)

    setup_dict = TOML.parsefile(toml_specifier)
    setup_keys = keys(setup_dict)
    "Title" in setup_keys || throw(MercuryLoggerError("""Mercury log specification file requires "Title" key!"""))

    topic_dict_name_list = filter(x->x!="Title", setup_keys)

    entries = Vector{MercurySpecEntry}()

    for topic_dict_name in topic_dict_name_list
        topic_dict = setup_dict[topic_dict_name]
        topic_keys = keys(topic_dict)

        "Address" in topic_keys || throw(MercuryLoggerError("""Mercury log specification file requires each topic have a "Address" key!"""))
        "Port" in topic_keys || throw(MercuryLoggerError("""Mercury log specification file requires each topic have a "Port" key!"""))
        "Message" in topic_keys || throw(MercuryLoggerError("""Mercury log specification file requires each topic have a "Message" key!"""))

        entry = MercurySpecEntry(
            rel_dir,
            topic_dict_name,
            topic_dict["Address"],
            topic_dict["Port"],
            topic_dict["Message"],
            "Plot_Field" in topic_keys ? topic_dict["Plot_Field"] : nothing
        )

        push!(entries, entry)
    end

    return entries
end
