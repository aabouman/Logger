import MercuryTools as HgTools
import Dates: format, now
import ZMQ

t_start = time_ns()

hg_log = HgTools.start_logging(
                               joinpath(@__DIR__, "setup.toml"),
                               joinpath(@__DIR__, "logs", "mercury_log_" * format(now(), "dd_mm_yyyy_HH:MM.hglog"));
                               zmq_ctx = ZMQ.context(),
                               rate = 100.,
                               );

println("Closed Log")