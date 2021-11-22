struct MercuryLoggerError <: Exception
    msg::String
end

struct LogEntry
    topic_name::String
    time::Float64
    msg::Hg.MercuryMessage
    topic_port::String
end

mutable struct MercuryLogger <: Hg.Node
    # Required by Abstract Node type
    nodeio::Hg.NodeIO
    topic_names::Vector{String}
    log_file_name::String
end

function MercuryLogger(ctx::ZMQ.Context, rate::Real, log_file_name::String)
    # Adding the Ground Vicon Subscriber to the Node
    loggerIO = Hg.NodeIO(ctx; rate = rate)
    touch(log_file_name)
    topic_names = Vector{String}()

    return MercuryLogger( loggerIO, topic_names, log_file_name, )
end

function set_log_file(hg_log::MercuryLogger, filename::String)
    hg_log.log_file_name = filename;
end

function Hg.compute(hg_log::MercuryLogger)
    loggerIO = Hg.getIO(hg_log)

    for (name, sub) in zip(hg_log.topic_names, loggerIO.subs)
        Hg.on_new(sub) do msg
            open(hg_log.log_file_name, read=false, write=true, append = true) do io
                serialize(io, LogEntry(name, time(), msg, Hg.portstring(sub.sub)))
            end
        end
    end
end

function add_log_topic(hg_log::MercuryLogger, addr::IPv4, port::Int, msg::Hg.MercuryMessage)
    loggerIO = Hg.getIO(hg_log)

    # Create a publisher
    sub = Hg.ZmqSubscriber(loggerIO.ctx, addr, port)
    Hg.add_subscriber!(loggerIO, msg, sub)
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
    # Must use invokelatest as we have imported the message ProtoBuf files inside parse_toml
    node = Base.invokelatest(
        start_logging,
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