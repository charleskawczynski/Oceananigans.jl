"""
This example sets up a dry, warm thermal bubble perturbation in a uniform
lateral mean flow which buoyantly rises. Identical to the verification
experiment in ../dry_rising_thermal_bubble except that entropy is used as
the prognostic thermodynamic variable rather than potential temperature.
"""

using Printf
using Profile
using Plots
using VideoIO
using FileIO
using Oceananigans
using JULES

const km = 1000
const hPa = 100

Lx = 20km
Lz = 10km

Δ = 0.1km  # grid spacing [m]

Nx = Int(Lx/Δ)
Ny = 1
Nz = Int(Lz/Δ)

grid = RegularCartesianGrid(size=(Nx, Ny, Nz), halo=(2, 2, 2),
                            x=(-Lx/2, Lx/2), y=(-Lx/2, Lx/2), z=(0, Lz))

model = CompressibleModel(
                      grid = grid,
                 densities = DryEarth3(),
    thermodynamic_variable = PrognosticS(),
                   closure = ConstantIsotropicDiffusivity(ν=0.0, κ=0.0)
)

#####
##### Dry thermal bubble perturbation
#####

gas = model.densities.ρ₁
R, cₚ, cᵥ = gas.R, gas.cₚ, gas.cᵥ
sref, Tref, ρref = gas.s₀, gas.T₀, gas.ρ₀
g  = model.gravity
pₛ = 1000hPa
Tₛ = 300

# Define initial mixing ratios
q₁(z) = exp(-(4z/Lz)^2)
q₂(z) = exp(-(4*(z - Lz)/Lz)^2)
q₃(z) = 1 - q₁(z) - q₂(z)

# Define an approximately hydrostatic background state
θ₀(x, y, z) = Tₛ
p₀(x, y, z) = pₛ * (1 - g*z/(cₚ*Tₛ))^(cₚ/R)
T₀(x, y, z) = Tₛ*(p₀(x, y, z)/pₛ)^(R/cₚ)
ρ₀(x, y, z) = p₀(x, y, z)/(R*T₀(x, y, z))
ρ₁₀(x, y, z) = q₁(z) * ρ₀(x, y, z)
ρ₂₀(x, y, z) = q₂(z) * ρ₀(x, y, z)
ρ₃₀(x, y, z) = q₃(z) * ρ₀(x, y, z)
function ρs₀(x, y, z)
    ρs = 0.0
    T = T₀(x, y, z)
    for ρ in (ρ₁₀(x, y, z), ρ₂₀(x, y, z), ρ₃₀(x, y, z))
        ρs += (ρ > 0 ?  ρ * (sref + cᵥ*log(T/Tref) - R*log(ρ/ρref)) : 0.0)
    end
    return ρs
end

# Define the initial density perturbation
xᶜ, zᶜ = 0km, 2km
xʳ, zʳ = 2km, 2km
L(x, y, z) = sqrt(((x - xᶜ)/xʳ)^2 + ((z - zᶜ)/zʳ)^2)
function ρ′(x, y, z; θᶜ′ = 2.0)
    l = L(x, y, z)
    θ′ = (l <= 1) * θᶜ′ * cos(π/2 * L(x, y, z))^2
    return -ρ₀(x, y, z) * θ′ / θ₀(x, y, z)
end

# Define initial state
ρᵢ(x, y, z) = ρ₀(x, y, z) + ρ′(x, y, z)
pᵢ(x, y, z) = p₀(x, y, z)
Tᵢ(x, y, z) = pᵢ(x, y, z) / (R * ρᵢ(x, y, z))
ρ₁ᵢ(x, y, z) = q₁(z) * ρᵢ(x, y, z)
ρ₂ᵢ(x, y, z) = q₂(z) * ρᵢ(x, y, z)
ρ₃ᵢ(x, y, z) = q₃(z) * ρᵢ(x, y, z)
function ρsᵢ(x, y, z)
    ρs = 0.0
    T = Tᵢ(x, y, z)
    for ρ in (ρ₁ᵢ(x, y, z), ρ₂ᵢ(x, y, z), ρ₃ᵢ(x, y, z))
        ρs += (ρ > 0 ?  ρ * (sref + cᵥ*log(T/Tref) - R*log(ρ/ρref)) : 0.0)
    end
    return ρs
end

# Set initial state after saving perturbation-free background
ρ, ρ₁, ρ₂, ρ₃, ρs = model.total_density, model.tracers.ρ₁, model.tracers.ρ₂, model.tracers.ρ₃, model.tracers.ρs
xC, zC = grid.xC, grid.zC
set!(model.tracers.ρ₁, ρ₁₀)
set!(model.tracers.ρ₂, ρ₂₀)
set!(model.tracers.ρ₃, ρ₃₀)
set!(model.tracers.ρs, ρs₀)
update_total_density!(model.total_density, model.grid, model.densities, model.tracers)
ρʰᵈ = ρ.data[1:Nx, 1, 1:Nz]
ρsʰᵈ = ρs.data[1:Nx, 1, 1:Nz]
set!(model.tracers.ρ₁, ρ₁ᵢ)
set!(model.tracers.ρ₂, ρ₂ᵢ)
set!(model.tracers.ρ₃, ρ₃ᵢ)
set!(model.tracers.ρs, ρsᵢ)
update_total_density!(model.total_density, model.grid, model.densities, model.tracers)

ρ_plot = contour(model.grid.xC ./ km, model.grid.zC ./ km,
    rotr90(ρ.data[1:Nx, 1, 1:Nz] .- ρʰᵈ), fill=true, levels=10, xlims=(-5, 5),
    clims=(-0.008, 0.008), color=:balance, dpi=200)
savefig(ρ_plot, "rho_prime_initial_condition.png")

s_slice = rotr90(ρs.data[1:Nx, 1, 1:Nz] ./ ρ.data[1:Nx, 1, 1:Nz])
s_plot = contour(model.grid.xC ./ km, model.grid.zC ./ km, s_slice,
                 fill=true, levels=10, xlims=(-5, 5), color=:thermal, dpi=200)
savefig(s_plot, "entropy_initial_condition.png")

#####
##### Watch the thermal bubble rise!
#####

ρ̄ᵢ = sum(ρ.data[1:Nx,1,1:Nz])/(Nx*Nz)
Δt=0.1
for n in 1:200

    time_step!(model, Δt = Δt, Nt = 50)

    CFL = cfl(model, Δt)
    ρ̄ = sum(ρ.data[1:Nx,1,1:Nz])/(Nx*Nz)
    @printf("t = %.2f s, CFL = %.2e, ρ̄ = %.2e (rel.err. = %.2e)\n",
        model.clock.time, CFL, ρ̄, (ρ̄ - ρ̄ᵢ)/ρ̄)

    xC, yC, zC = model.grid.xC ./ km, model.grid.yC ./ km, model.grid.zC ./ km
    xF, yF, zF = model.grid.xF ./ km, model.grid.yF ./ km, model.grid.zF ./ km

    j = 1
    update_total_density!(model.total_density, model.grid, model.densities, model.tracers)
    ρ₁_slice = rotr90(ρ₁[1:Nx, j, 1:Nz])
    ρ₂_slice = rotr90(ρ₂[1:Nx, j, 1:Nz])
    ρ₃_slice = rotr90(ρ₃[1:Nx, j, 1:Nz])
    ρ_slice = rotr90(ρ[1:Nx, j, 1:Nz])
    ρ′_slice = rotr90(ρ[1:Nx, j, 1:Nz] .- ρʰᵈ)
    s_slice = rotr90(ρs[1:Nx, j, 1:Nz] ./ ρ[1:Nx, j, 1:Nz])

    ρ₁_title = @sprintf("rho1, t = %d s", round(Int, model.clock.time))
    pρ₁ = heatmap(xC, zC, ρ₁_slice, title=ρ₁_title, fill=true, levels=50,
        xlims=(-5, 5), color=:dense, linecolor = nothing, clims = (0, 1.1))
    pρ₂ = heatmap(xC, zC, ρ₂_slice, title="rho2", fill=true, levels=50,
        xlims=(-5, 5), color=:dense, linecolor = nothing, clims = (0, 1.1))
    pρ₃ = heatmap(xC, zC, ρ₃_slice, title="rho3", fill=true, levels=50,
        xlims=(-5, 5), color=:dense, linecolor = nothing, clims = (0, 1.1))
    pρ = heatmap(xC, zC, ρ_slice, title="rho", fill=true, levels=50,
        xlims=(-5, 5), color=:dense, linecolor = nothing, clims = (0, 1.1))
    pρ′ = heatmap(xC, zC, ρ′_slice, title="rho'", fill=true, levels=50,
        xlims=(-5, 5), color=:balance, linecolor = nothing, clims = (-0.007, 0.007))
    ps = heatmap(xC, zC, s_slice, title="s", fill=true, levels=50,
        xlims=(-5, 5), color=:oxy, linecolor = nothing)

    p = plot(pρ₁, pρ₂, pρ₃, pρ, pρ′, ps, layout=(3, 2), show=true, dpi = 200,
        size = (600, 600))
    savefig(p, @sprintf("frames/thermal_bubble_%03d.png", n))
end

@printf("Rendering MP4\n")
imgs = filter(x -> occursin(".png", x), readdir("frames"))
imgorder = map(x -> split(split(x, ".")[1], "_")[end], imgs)
p = sortperm(parse.(Int, imgorder))
frames = []
for img in imgs[p]
    push!(frames, convert.(RGB, load("frames/$img")))
end
encodevideo("thermal_bubble.mp4", frames, framerate = 30)
