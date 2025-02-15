function download_many(urls::AbstractVector{String}, filenames::AbstractVector{String};
                       download_successful::Function = req_body::String -> true,
                       retries=10, first_delay=0.05, max_delay=10.0, factor=5.0,
                       verbosity=1)
    cur_delay = first_delay

    dirs = unique(dirname.(filenames))
    foreach(mkpath, dirs)

    N = length(urls)
    verbosity > 0 && @info "Downloading $(N) files, hang tight"

    @withprogress begin
        for (i,(url,filename)) in enumerate(zip(urls, filenames))
            if isfile(filename)
                verbosity > 1 && @info "Already downloaded" url filename
                @logprogress i/N
                continue
            end
            verbosity > 0 && @info "Download" url filename
            exp_backoff = ExponentialBackOff(n=retries, first_delay=cur_delay,
                                             max_delay=max_delay, factor=factor)
            delays = collect(exp_backoff)

            i = 0
            req = HTTP.request("GET", url,
                               retry_delays=exp_backoff,
                               retry_check=(s, ex, req, resp, resp_body) -> begin
                                   if HTTP.status ≠ 200
                                       i += 1
                                   end
                                   true
                               end)

            if req.status == 200
                req_body = HTTP.request("GET", url).body |> String
                if download_successful(req_body)
                    verbosity > 1 && @info "Download successful"
                    open(filename, "w") do file
                        write(file, req_body)
                    end
                else
                    @error "Download unsuccessful"
                end
            else
                @error "Download failed" url filename
            end

            if i > 0
                cur_delay = delays[min(i,length(delays))]
                @warn "Retries have happened, increasing minimum delay to $(cur_delay)"
            end
            if i ≥ retries
                error("Number of retries exceeded")
            end

            @logprogress i/N
            sleep(0.2)
        end
    end
end
