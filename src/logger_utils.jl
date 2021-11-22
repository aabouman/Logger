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
    Read the log into a vector and return vector
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
