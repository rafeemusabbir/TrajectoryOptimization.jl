using Plots
using Random
pyplot()
include("N_plots.jl")
model, obj = Dynamics.dubinscar_escape
circles = Dynamics.circles_escape

# Constrained
opts = SolverOptions()
opts.verbose = false
opts.cost_tolerance = 1e-6
opts.cost_tolerance_intermediate = 1e-5
opts.constraint_tolerance = 1e-5
opts.resolve_feasible = false
opts.outer_loop_update_type = :default
opts.use_nesterov = false
opts.penalty_scaling = 200
opts.penalty_initial = .1
opts.R_infeasible = 20

N=101

solver = Solver(model,obj,N=N,opts=opts)
n,m,N = get_sizes(solver)
U0 = ones(m,N)
X0 = rollout(solver,U0)
res, stats = solve(solver,U0)


# Infeasible
opts = SolverOptions()
opts.verbose = false
opts.cost_tolerance = 1e-6
opts.cost_tolerance_intermediate = 0.01
opts.constraint_tolerance = 1e-4
opts.resolve_feasible = true
opts.outer_loop_update_type = :default
opts.use_nesterov = false
opts.penalty_scaling = 50
opts.penalty_initial = 10
opts.R_infeasible = 1
opts.square_root = true
ipopt_options = Dict("tol"=>opts.cost_tolerance,"constr_viol_tol"=>opts.constraint_tolerance)

N = 101
solver = Solver(model, obj, N=N, opts=opts)
n,m,N = get_sizes(solver)
Random.seed!(2);
U0 = ones(m,N-1) + rand(m,N-1)/3
X_guess = [2.5 2.5 0.;4. 5. .785;5. 6.25 0.;7.5 6.25 -.261;9 5. -1.57;7.5 2.5 0.]
X0 = TrajectoryOptimization.interp_rows(N,obj.tf,Array(X_guess'))

solver.opts.verbose = false
solver.opts.cost_tolerance_infeasible = 1e-6
@btime solve(solver,X0,U0)
res_inf, stats_inf = solve(solver,X0,U0)
stats_inf["iterations"]
stats_inf["runtime"]
evals(solver,:f) / stats_inf["iterations"]

@btime solve_dircol(solver,X0,U0, options=ipopt_options)
res_i, stats_i = solve_dircol(solver,X0,U0, options=ipopt_options)
stats_i["iterations"]
evals(solver,:f)/stats_i["iterations"]
stats_i["runtime"]

# constraint_plot(solver,X0,U0)

plt = plot(title="",aspect_ratio=:equal,size=(500,300),xlim=[-0.5,10.5],ylim=[-0.5,6.6],grid=:off,bg=:white)
plot_obstacles(circles,:grey60)
plot_trajectory!(X0,style=:dash,color=:black,width=2,label="Initial Guess")
plot_trajectory!(res_i.X,width=3,color=:blue,label="Ipopt")
plot_trajectory!(to_array(res.X),width=2,color=:darkorange2,label="ALTRO",aspect_ratio=:equal,legend=:topleft)
plot_trajectory!(to_array(res_inf.X),width=2,color=:darkorange2,style=:dash,label="ALTRO (inf)",aspect_ratio=:equal)
scatter!([obj.x0[1]],[obj.x0[2]],label=:start,color=:red,markerstrokecolor=:red,markersize=12,markershape=:rtriangle)
scatter!([obj.xf[1]],[obj.xf[2]],label=:goal,color=:green,markerstrokecolor=:green,markersize=12,markershape=:rtriangle)
savefig(joinpath(IMAGE_DIR,"escape_traj.eps"))

solver_truth = Solver(model, obj, N=601)

Ns = [101,161,201,241,301]
group = "escape"
run_step_size_comparison(model, obj, U0, group, Ns, opts=opts, integrations=[:rk3,:ipopt],benchmark=true, infeasible=true, X0=X0, dt_truth=solver_truth.dt)
plot_stat("runtime",group,legend=:topleft,["rk3","ipopt"],title="Escape",color=[:blue :darkorange2],size=(500,250))
savefig(joinpath(IMAGE_DIR,"escape_runtime.eps"))
plot_stat("iterations",group,legend=:topleft,["rk3","ipopt"],title="Escape",size=(500,250))
savefig(joinpath(IMAGE_DIR,"escape_iters.eps"))
plot_stat("error",group,yscale=:log10,legend=:right,["rk3","ipopt"],title="Escape")

Ns, data = load_data("runtime",["rk3","ipopt"],"escape")
Ns, err = load_data("std",["rk3","ipopt"],"escape")
plot(Ns,data[1],yerr=err[1],label="ALTRO",markershape=:circle,markersize=6,color=:darkorange2,markerstrokecolor=:darkorange2)
plot!(Ns,data[2],yerr=err[2],label="Ipopt",markershape=:circle,markersize=6,color=:blue,markerstrokecolor=:blue)
