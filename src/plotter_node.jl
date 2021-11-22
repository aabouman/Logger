# __precompile__(false)

struct MercuryPlotterError <: Exception
    msg::String
end

mutable struct MercuryPlotter <: Hg.Node
    # Required by Abstract Node type
    nodeio::Hg.NodeIO
    fig::GRUtils.Figure
    msg_name::String
    msg_field::Symbol
    trace_x::CircularBuffer{Float64}
    trace_y::CircularBuffer{Float64}
end

function MercuryPlotter(ctx::ZMQ.Context, rate::Real)
    # Adding the Ground Vicon Subscriber to the Node
    loggerIO = Hg.NodeIO(ctx; rate = rate)
    fig = GRUtils.Figure()
    msg_name = ""
    msg_field = Symbol()
    trace_x = CircularBuffer{Float64}(1000)
    trace_y = CircularBuffer{Float64}(1000)

    return MercuryPlotter(
        loggerIO,
        fig,
        msg_name,
        msg_field,
        trace_x,
        trace_y,
        )
end

function add_plot_trace(hg_plot::MercuryPlotter, entry::MercurySpecEntry)
    plotterIO = Hg.getIO(hg_plot)

    hg_plot.msg_name = entry.topic_name
    hg_plot.msg_field = entry.field

    # Create a publisher
    sub = Hg.ZmqSubscriber(plotterIO.ctx, entry.address, entry.port_number)
    Hg.add_subscriber!(plotterIO, entry.message, sub)
end

function Hg.startup(hg_plot::MercuryPlotter)
    GRUtils.gcf(hg_plot.fig)
    GRUtils.title!(hg_plot.fig, hg_plot.msg_name)
end

function Hg.compute(hg_plot::MercuryPlotter)
    plotterIO = Hg.getIO(hg_plot)
    @assert length(plotterIO.subs) == 1

    for sub in plotterIO.subs
        Hg.on_new(sub) do msg
            push!(hg_plot.trace_x, time())
            val = getproperty(msg, hg_plot.msg_field)
            push!(hg_plot.trace_y, val)

            GRUtils.plot!(hg_plot.fig, hg_plot.trace_x[1:end], hg_plot.trace_y[1:end])
            GRUtils.display(hg_plot.fig)

            # geom = GRUtils.Geometry(
            #     :line,
            #     hg_plot.trace_x[1:end],
            #     hg_plot.trace_y[1:end],
            #     Float64[],
            #     Float64[],
            #     "",
            #     "",
            #     Dict{Symbol, Float64}()
            # )
            # hg_plot.fig.plots[1].geoms[1] = geom

            # hg_plot.last_time = time()
        end
    end
end

function Hg.finishup(hg_plot::MercuryPlotter)
    GRUtils.display(hg_plot.fig)
end

function start_plotting(
        entry::MercurySpecEntry,
        zmq_ctx::ZMQ.Context,
        rate::Real,
    )

    hg_plot = MercuryPlotter(zmq_ctx, rate, )
    add_plot_trace(hg_plot, entry)

    Hg.launch(hg_plot)

    return hg_plot
end

function start_plotting(
        toml_specifier::String;
        zmq_ctx::ZMQ.Context = ZMQ.context(),
        rate::Real = 100,
    )
    entry_list = parse_toml(toml_specifier)
    # Must use invokelatest as we have imported the message ProtoBuf files inside parse_toml
    hg_plot = Base.invokelatest(start_plotting, entry_list[1], zmq_ctx, rate, )

    return hg_plot
end