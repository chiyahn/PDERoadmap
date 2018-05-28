using DifferentialEquations, NamedTuples, BenchmarkTools, Plots, BandedMatrices

#These would be generated automatically by DiffEqOperators.jl
#These are the differential operators for positive drift 0upwind finite differences
function diffusionoperators(x_min, x_max, M)
    x = linspace(x_min, x_max, M)
    Δ = x[2]-x[1]

    dl_1 = zeros(M-1)
    d_1 = -1 * ones(M)
    d_1[end] = 0
    du_1 = ones(M-1)
    L_1_plus = Tridiagonal(dl_1, d_1, du_1)/Δ

    dl_2 = ones(M-1)
    d_2 = -2 * ones(M)
    d_2[1] = -1
    d_2[end] = -1
    du_2 = ones(M-1)
    L_2 = Tridiagonal(dl_2, d_2, du_2)/(Δ^2)

    return (x, L_1_plus, L_2) #Tuple with the discretization
end

#Create DiffEq Problem for solving
function createODEproblem(c_tilde, sigma_tilde, mu_tilde, x_min, x_max, M, T, rho)
    x, L_1_plus, L_2  = diffusionoperators(x_min, x_max, M) #Discretize the operator

    p = @NT(L_1_plus = L_1_plus, L_2 = L_2, x = x, rho = rho, mu_tilde = mu_tilde, sigma_tilde = sigma_tilde, c_tilde = c_tilde) #Named tuple for parameters.

    #Check upwind direction
    @assert minimum(mu_tilde.(T, x)) >= 0.0
    @assert minimum(mu_tilde.(0.0, x)) >= 0.0

    #Calculating the stationary solution,
    L_T = rho*I - Diagonal(mu_tilde.(T, x)) * L_1_plus - Diagonal(sigma_tilde.(T, x).^2/2.0) * L_2
    u_T = L_T \ c_tilde.(T, x)

    @assert(issorted(u_T)) #We are only solving versions that are increasing for now

    function f(du,u,p,t)
        L = p.rho*I  - Diagonal(p.mu_tilde.(t, x)) * p.L_1_plus - Diagonal(p.sigma_tilde.(t, p.x).^2/2) * p.L_2
        A_mul_B!(du,L,u)
        du .+= p.c_tilde.(t, p.x)
    end

    tspan = (T, 0.0)
    return ODEProblem(f, u_T, tspan, p)
end

# mu_tilde is time varying but sigma_tilde is not.
x_min = 0.01
x_max = 1.0
M = 30
T = 0.3
rho = 0.05
sigma_bar = 0.1
c_tilde(t, x) = exp(x)
sigma_tilde(t, x) =  sigma_bar * x
mu_tilde(t, x) = 0.1*x + t/1500.0 #How is this so sensitive?
basealgorithm = CVODE_BDF() #ImplicitEuler() #A reasonable alternative. Algorithms which don't work well: Rosenbrock23(), Rodas4(), KenCarp4()
plotevery = 5

prob = createODEproblem(c_tilde, sigma_tilde, mu_tilde, x_min, x_max, M, T, rho)
sol = solve(prob, basealgorithm)
plot(sol, vars=1:plotevery:M, xlims=[0.0 T], xflip=false)
@assert(issorted(sol[end]))
# @btime solve($prob, $basealgorithm) #Benchmark

# Increase the time variation and see lack of stability near the end.  How bad is relative.
mu_tilde(t, x) = 0.1*x + t/15.0 #increase the time variation
prob = createODEproblem(c_tilde, sigma_tilde, mu_tilde, x_min, x_max, M, T, rho)
sol = solve(prob, basealgorithm)
plot(sol, vars=1:plotevery:M, xlims=[0.0 T], xflip=false)
@assert(issorted(sol[end]))

#ImplicitEuler is more order preserving...
prob = createODEproblem(c_tilde, sigma_tilde, mu_tilde, x_min, x_max, M, T, rho)
sol = solve(prob, ImplicitEuler())
plot(sol, vars=1:plotevery:M, xlims=[0.0 T], xflip=false)
@assert(issorted(sol[end]))
