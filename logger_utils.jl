function parse_log_toml(log_file_name::String)
    setup_dict = TOML.parsefile(log_file_name)
    setup_keys = keys(setup_dict)
    "Title" in setup_keys || throw(MercuryLoggerError("""Mercury log specification file requires "Title" key!"""))

    topic_dict_name_list = filter(x->x!="Title", setup_keys)

    topic_names = Vector{String}()
    topic_addrs = Vector{IPv4}()
    topic_ports = Vector{Int}()
    topic_msgs = Vector{Hg.MercuryMessage}()

    for topic_dict_name in topic_dict_name_list
        topic_dict = setup_dict[topic_dict_name]
        topic_keys = keys(topic_dict)

        "Address" in topic_keys || throw(MercuryLoggerError("""Mercury log specification file requires each topic have a "Address" key!"""))
        "Port" in topic_keys || throw(MercuryLoggerError("""Mercury log specification file requires each topic have a "Port" key!"""))
        "Message" in topic_keys || throw(MercuryLoggerError("""Mercury log specification file requires each topic have a "Message" key!"""))

        push!(topic_names, topic_dict_name)
        push!(topic_addrs, IPv4(topic_dict["Address"]))
        push!(topic_ports, topic_dict["Port"])

        if topic_dict["Message"] isa Int
            push!(topic_msgs, Vector{UInt8}(undef, topic_dict["Message"]))
        else
            val = eval(Meta.parse(topic_dict["Message"]))
            val isa ProtoBuf.ProtoType || throw(MercuryLoggerError(""""Message" specifier expected to be `Int` or a string evaluating to a `ProtoBuf.ProtoType`"""))

            push!(topic_msgs, val)
        end
    end

    return topic_names, topic_addrs, topic_ports, topic_msgs
end

"""
    Gives estimate of number of entries to preallocate associated vector with
"""
function count_log_entries(log_file_name::String)
    target_string = "LogEntry"
    target_bytes = Vector{UInt8}(target_string)
    window_len = length(target_string)
    window_bytes = zeros(UInt8, window_len)
    count = 0

    # Function for indexing into an array like a circular buffer
    rollover(i) = ((i-1) % window_len) + 1

    open(log_file_name, read=true, write=false) do io
        readbytes!(io, window_bytes)
        inesert_ind = rollover(1)

        for c in readeach(io, UInt8)
            window_bytes[inesert_ind] = c

            for i in 1:window_len
                tmp_ind = rollover(inesert_ind+i)
                target_bytes[i] != window_bytes[tmp_ind] && break
                # If weve gone through the whole array all the bytes match and increment count
                (i == window_len) && (count += 1)
            end

            inesert_ind = rollover(inesert_ind+1)
        end
    end

    return count
end

"""
    Read the log into a vector
"""
function read_log(log_file_name::String)
    vec = sizehint!(Vector{LogEntry}(), count_log_entries(log_file_name))

    open(log_file_name, read=true, write=false) do io
        while !eof(io)
            try
                push!(vec, deserialize(io), )
            catch error
                @warn "Log File Contains non-julia serialized data!"
                rethrow(error)
            end
        end
    end
    return vec
end
