function parse_log_toml(toml_specifier::String)
    rel_dir = dirname(toml_specifier)

    setup_dict = TOML.parsefile(toml_specifier)
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
            filename, protobuf_name_string = split(topic_dict["Message"], ":"; limit=2)
            filename = joinpath(rel_dir, filename)

            isfile(filename) || throw(MercuryLoggerError(""""Message" specifier expected to be `Int` or a string "<path_to_proto.jl>:<NameOfProto>" """))
            include(filename)
            msg = eval( Meta.parse(protobuf_name_string*"()"))

            push!(topic_msgs, msg)
        end
    end

    return topic_names, topic_addrs, topic_ports, topic_msgs
end

function start_logging(
        topic_names::Vector{String},
        topic_addrs::Vector{IPv4},
        topic_ports::Vector{Int},
        topic_msgs::Vector{Hg.MercuryMessage},
        log_file_name::String,
        zmq_ctx::ZMQ.Context,
        rate::Real,
    )
    @assert length(topic_names) == length(topic_addrs) == length(topic_ports) == length(topic_msgs)
    Base.Filesystem.splitext(log_file_name)[end] == ".hglog" || throw(MercuryLoggerError("Log file must have .hglog extension"))

    hg_log = MercuryLogger(zmq_ctx, rate, log_file_name)

    for (name, addr, port, msg) in zip(topic_names, topic_addrs, topic_ports, topic_msgs)
        push!(hg_log.topic_names, name)
        add_log_topic(hg_log, addr, port, msg)
    end

    Hg.launch(hg_log)

    return hg_log
end

function start_logging(
        toml_specifier::String,
        log_file_name::String = joinpath(pwd(), "mercury_log_" * format(now(), "dd_mm_yyyy_HH:MM.hglog"));
        zmq_ctx::ZMQ.Context = ZMQ.context(),
        rate::Real = 100,
    )

    topic_names, topic_addrs, topic_ports, topic_msgs = parse_log_toml(toml_specifier)

    node = start_logging(
        topic_names,
        topic_addrs,
        topic_ports,
        topic_msgs,
        log_file_name,
        zmq_ctx,
        rate,
    )

    return node
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
