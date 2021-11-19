import Mercury as Hg
import ZMQ
using Sockets
import Dates: now, format
import Serialization: serialize, deserialize
using TOML

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

    Hg.publish.(loggerIO.pubs)
end

function add_log_topic(hg_log::MercuryLogger, addr::IPv4, port::Int, msg::Hg.MercuryMessage)
    loggerIO = Hg.getIO(hg_log)

    # Create a publisher
    sub = Hg.ZmqSubscriber(loggerIO.ctx, addr, port)
    Hg.add_subscriber!(loggerIO, msg, sub)
end
