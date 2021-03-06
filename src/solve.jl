function solve(prob::AbstractMonteCarloProblem,alg::Union{DEAlgorithm,Void}=nothing;num_monte=10000,batch_size = num_monte,parallel_type=:pmap,kwargs...)
  num_batches = num_monte ÷ batch_size
  u = deepcopy(prob.u_init)
  converged= false
  elapsed_time = @elapsed for i in 1:num_batches
    if i == num_batches
      I = (batch_size*(i-1)+1):num_monte
    else
      I = (batch_size*(i-1)+1):batch_size*i
    end
    batch_data = solve_batch(prob,alg,parallel_type,I,kwargs...)
    u,converged = prob.reduction(u,batch_data,I)
    converged && break
  end
  if typeof(u) <: Vector{Any}
    _u = convert(Array{typeof(u[1])},u)
  else
    _u = u
  end
  MonteCarloSolution(_u,elapsed_time,converged)
end

function solve_batch(prob,alg,parallel_type,I,kwargs...)
  if parallel_type == :pmap
      wp=CachingPool(workers())
      batch_data = pmap(wp,(i)-> begin
      new_prob = prob.prob_func(deepcopy(prob.prob),i)
      prob.output_func(solve(new_prob,alg;kwargs...),i)
    end,I)
    batch_data = convert(Array{typeof(batch_data[1])},batch_data)

  elseif parallel_type == :parfor
    batch_data = @parallel (vcat) for i in I
      new_prob = prob.prob_func(deepcopy(prob.prob),i)
      [prob.output_func(solve(new_prob,alg;kwargs...),i)]
    end

  elseif parallel_type == :threads
    batch_data = Vector{Any}()
    for i in 1:Threads.nthreads()
      push!(batch_data,[])
    end
    Threads.@threads for i in I
      new_prob = prob.prob_func(deepcopy(prob.prob),i)
      push!(batch_data[Threads.threadid()],prob.output_func(solve(new_prob,alg;kwargs...),i))
    end
    batch_data = vcat(batch_data...)
    batch_data = convert(Array{typeof(batch_data[1])},batch_data)

  elseif parallel_type == :split_threads
    wp=CachingPool(workers())
    batch_data = pmap(wp,(i) -> begin
      _num_monte = length(I)÷nprocs() # probably can be made more even?
      if i == nprocs()
        _num_monte = length(I)-_num_monte*(nprocs()-1)
      end
      thread_monte(prob,I,alg,i,kwargs...)
    end,1:nprocs())
    batch_data = vcat(batch_data...)
    batch_data = convert(Array{typeof(batch_data[1])},batch_data)
    
  elseif parallel_type == :none
    batch_data = Vector{Any}()
    for i in I
      new_prob = prob.prob_func(deepcopy(prob.prob),i)
      push!(batch_data,prob.output_func(solve(new_prob,alg;kwargs...),i))
    end
    batch_data = convert(Array{typeof(batch_data[1])},batch_data)

  else
    error("Method $parallel_type is not a valid parallelism method.")
  end
  batch_data
end

function thread_monte(prob,I,alg,procid,kwargs...)
  batch_data = Vector{Any}()
  for i in 1:Threads.nthreads()
    push!(batch_data,[])
  end
  Threads.@threads for i in (I[1]+(procid-1)*length(I)+1):(I[1]+procid*length(I))
    new_prob = prob.prob_func(deepcopy(prob.prob),i)
    push!(batch_data[Threads.threadid()],prob.output_func(solve(new_prob,alg;kwargs...),i))
  end
  batch_data = vcat(batch_data...)
  batch_data = convert(Array{typeof(batch_data[1])},batch_data)
end
