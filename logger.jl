import Mercury as Hg
import ZMQ
using Sockets
using StaticArrays
using TOML
import Dates: now, format
import Serialization: serialize, deserialize

if !isdefined(@__MODULE__, :TestMsg)
    include(joinpath(@__DIR__, "test_msg_pb.jl"))
end

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
    # topic_log_files::Vector{String}
    log_file_name::String
    # Vector{MercuryMessage}
end

function set_log_file(hg_log::MercuryLogger, filename::String)
    hg_log.log_file_name = filename;
end

function MercuryLogger(ctx::ZMQ.Context, rate::Real, log_file_name::String)
    # Adding the Ground Vicon Subscriber to the Node
    loggerIO = Hg.NodeIO(ctx; rate = rate)
    touch(log_file_name)

    return MercuryLogger( loggerIO, log_file_name, )
end

function Hg.compute(hg_log::MercuryLogger)
    loggerIO = Hg.getIO(hg_log)

    for sub in loggerIO.subs
        Hg.on_new(sub) do msg
            open(hg_log.log_file_name, read=false, write=true, append = true) do io
                serialize(io, LogEntry(time(), msg, Hg.portstring(sub.sub)))
                write(io, "\n")
            end
        end
    end

    Hg.publish.(loggerIO.pubs)
end

function add_log_topic(hg_log::MercuryLogger, addr::IPv4, port::Int, msg::Hg.MercuryMessage)
    loggerIO = Hg.getIO(hg_log)

    # Create a publisher
    sub = Hg.ZmqSubscriber(ctx, addr, port)
    Hg.add_subscriber!(loggerIO, msg, sub)
end

function start_logging(
        topic_names::SVector{N, String},
        topic_addrs::SVector{N, IPv4},
        topic_ports::SVector{N, Int},
        topic_msgs::SVector{N, Hg.MercuryMessage},
        log_file_name = joinpath(pwd(), "mercury_log_" * format(now(), "dd_mm_yyyy_HH:MM.hglog")),
        rate = 10,
    ) where {N}

    hg_log = MercuryLogger(ZMQ.context(), rate, log_file_name)

    for (addr, port, msg) in zip(topic_addrs, topic_ports, topic_msgs)
        add_log_topic(hg_log, addr, port, msg)
    end

    Hg.launch(node)

    return node
end

# # TODO: Function which reads serial file and plays back using LogEntry
# function play_log(hg_log::MercuryLogger)

# end

# function plot_log()

# end


# """
#     Add a single topic to hg_log messages from
# """
# function Hg.add_log(hg_log::MercuryLogger, ipaddr::Sockets.IPv4, port::Int64, msg::MercuryMessage; name=gensubscribername())
#     tcp_port_string = tcpstring(motors_serial_ipaddr, motors_serial_port)
#     sub = ZmqSubscriber(getIO(hg_log).ctx, ipaddr, port; name=name)
#     add_subscriber!(getIO(hg_log), msg, sub)
# end

# function Hg.add_plot(hg_log::MercuryLogger, ipaddr::Sockets.IPv4, port::Int64, msg::MercuryMessage; name=gensubscribername())
#     tcp_port_string = tcpstring(motors_serial_ipaddr, motors_serial_port)
#     sub = ZmqSubscriber(getIO(hg_log).ctx, ipaddr, port; name=name)
#     add_subscriber!(getIO(hg_log), msg, sub)
# end

# function Hg.start_logging(setup_toml_filename::String, )

# end

# function Hg.stop_logging(hg_log::MercuryLogger, )

#     close(node.motors_relay)
# end
