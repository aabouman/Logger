t_start = time_ns()

import Mercury as Hg
using ZMQ
using Sockets

using StaticArrays
using LinearAlgebra

if !isdefined(@__MODULE__, :TestMsg)
    include(joinpath(@__DIR__, "proto", "test_msg_pb.jl"))
end
if !isdefined(@__MODULE__, :MOTORS)
    include(joinpath(@__DIR__, "proto", "motors_msg_pb.jl"))
end

mutable struct SimpleNode <: Hg.Node
    ctx::ZMQ.Context   # NOTE: can we get rid of needing to store the ZMQ context?
    nodeio::Hg.NodeIO
    test_msg::TestMsg
end

function SimpleNode(ctx; rate = 10)
    test_msg = TestMsg(x = 0, y = 0, z = 0)
    nodeio = Hg.NodeIO(rate = rate)
    SimpleNode(ctx, nodeio, test_msg)
end

function Hg.setupIO!(node::SimpleNode, nodeio::Hg.NodeIO)
    # Create a publisher
    ctx = node.ctx
    addr = ip"127.0.0.1"
    port = 5555
    pub = Hg.ZmqPublisher(ctx, addr, port, name = "test_pub")

    # Register the publisher to publish the `TestMsg` stored in the node
    Hg.add_publisher!(nodeio, node.test_msg, pub)
end

function Hg.compute(node::SimpleNode)
    # Update the internal message
    A = @SMatrix rand(3, 3)
    A = A'A
    Achol = cholesky(A)
    b = SA[node.test_msg.x, node.test_msg.y, node.test_msg.z]
    x = Achol \ b
    node.test_msg.x += 1
    node.test_msg.y = x[2]
    node.test_msg.z = x[3]

    # Publish the message
    #   Mercury will automatically encode the message as a string of bytes and send it over ZMQ
    Hg.publish(Hg.getIO(node).pubs[1])  # NOTE: can we make this easier, maybe by using a Dict?
end

function launch_simple_node(; rate = 10)
    node = SimpleNode(ZMQ.context(), rate = rate)
    Hg.setupIO!(node, Hg.getIO(node))
    Hg.launch(node)
end