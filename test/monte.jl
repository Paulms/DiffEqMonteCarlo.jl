using DiffEqMonteCarlo, StochasticDiffEq, DiffEqBase,
      DiffEqProblemLibrary, OrdinaryDiffEq
using Base.Test


prob = prob_sde_2Dlinear
prob2 = MonteCarloProblem(prob)
sim = solve(prob2,SRIW1(),dt=1//2^(3),num_monte=10)
calculate_monte_errors(sim)
@test length(sim) == 10

sim = solve(prob2,SRIW1(),dt=1//2^(3),num_monte=10,parallel_type=:threads)
calculate_monte_errors(sim)
@test length(sim) == 10

sim = solve(prob2,SRIW1(),dt=1//2^(3),num_monte=10,parallel_type=:split_threads)
calculate_monte_errors(sim)
@test length(sim) == 10

sim = solve(prob2,SRIW1(),dt=1//2^(3),num_monte=10,parallel_type=:none)
calculate_monte_errors(sim)
@test length(sim) == 10

sim = solve(prob2,SRIW1(),dt=1//2^(3),num_monte=10,parallel_type=:parfor)
calculate_monte_errors(sim)
@test length(sim) == 10

prob = prob_sde_additivesystem
prob2 = MonteCarloProblem(prob)
sim = solve(prob2,SRA1(),dt=1//2^(3),num_monte=10)
calculate_monte_errors(sim)

output_func = function (sol,i)
  last(last(sol))^2
end
prob2 = MonteCarloProblem(prob,output_func=output_func)
sim = solve(prob2,SRA1(),dt=1//2^(3),num_monte=10)

prob = prob_sde_lorenz
prob2 = MonteCarloProblem(prob)
sim = solve(prob2,SRIW1(),dt=1//2^(3),num_monte=10)

output_func = function (sol,i)
  last(sol)
end

prob = prob_ode_linear
prob_func = function (prob,i)
  prob.u0 = rand()*prob.u0
  prob
end


srand(100)
reduction = function (u,batch,I)
  u = append!(u,batch)
  u,((var(u)/sqrt(last(I)))/mean(u)<0.5)?true:false
end

prob2 = MonteCarloProblem(prob,prob_func=prob_func,output_func=output_func,reduction=reduction,u_init=Vector{Float64}())
sim = solve(prob2,Tsit5(),num_monte=10000,batch_size=20)
@test sim.converged == true


srand(100)
reduction = function (u,batch,I)
  u = append!(u,batch)
  u,false
end

prob2 = MonteCarloProblem(prob,prob_func=prob_func,output_func=output_func,reduction=reduction,u_init=Vector{Float64}())
sim = solve(prob2,Tsit5(),num_monte=100,batch_size=20)
@test sim.converged == false

srand(100)
reduction = function (u,batch,I)
  u+sum(batch),false
end
prob2 = MonteCarloProblem(prob,prob_func=prob_func,output_func=output_func,reduction=reduction,u_init=0.0)
sim2 = solve(prob2,Tsit5(),num_monte=100,batch_size=20)
@test sim2.converged == false
@test mean(sim.u) ≈ sim2.u/100
