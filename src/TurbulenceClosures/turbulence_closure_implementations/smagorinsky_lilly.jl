#####
##### The turbulence closure proposed by Smagorinsky and Lilly.
##### We also call this 'Constant Smagorinsky'.
#####

struct SmagorinskyLilly{TD, FT, P} <: AbstractScalarDiffusivity{TD, ThreeDimensionalFormulation}
     C :: FT
    Cb :: FT
    Pr :: P

    function SmagorinskyLilly{TD, FT}(C, Cb, Pr) where {TD, FT}
        Pr = convert_diffusivity(FT, Pr; discrete_form=false)
        P = typeof(Pr)
        return new{TD, FT, P}(C, Cb, Pr)
    end
end

@inline viscosity(::SmagorinskyLilly, K) = K.νₑ
@inline diffusivity(closure::SmagorinskyLilly, K, ::Val{id}) where id = K.νₑ / closure.Pr[id]

"""
    SmagorinskyLilly(time_discretization = ExplicitTimeDiscretization, [FT=Float64;] C=0.16, Pr=1)

Return a `SmagorinskyLilly` type associated with the turbulence closure proposed by
Lilly (1962) and Smagorinsky (1958, 1963), which has an eddy viscosity of the form

```
νₑ = (C * Δᶠ)² * √(2Σ²) * √(1 - Cb * N² / Σ²)
```

and an eddy diffusivity of the form

```
κₑ = νₑ / Pr
```

where `Δᶠ` is the filter width, `Σ² = ΣᵢⱼΣᵢⱼ` is the double dot product of
the strain tensor `Σᵢⱼ`, `Pr` is the turbulent Prandtl number, and `N²` is
the total buoyancy gradient, and `Cb` is a constant the multiplies the Richardson number
modification to the eddy viscosity.

Keyword arguments
=================
  - `C`: Smagorinsky constant. Default value is 0.16 as obtained by Lilly (1966).
  - `Cb`: Buoyancy term multipler based on Lilly (1962) (`Cb = 0` turns it off, `Cb ≠ 0` turns it on.
          Typically, and according to the original work by Lilly (1962), `Cb=1/Pr`.)
  - `Pr`: Turbulent Prandtl numbers for each tracer. Either a constant applied to every
          tracer, or a `NamedTuple` with fields for each tracer individually.
  - `time_discretization`: Either `ExplicitTimeDiscretization()` or `VerticallyImplicitTimeDiscretization()`, 
                           which integrates the terms involving only ``z``-derivatives in the
                           viscous and diffusive fluxes with an implicit time discretization.

References
==========
Smagorinsky, J. "On the numerical integration of the primitive equations of motion for
    baroclinic flow in a closed region." Monthly Weather Review (1958)

Lilly, D. K. "On the numerical simulation of buoyant convection." Tellus (1962)

Smagorinsky, J. "General circulation experiments with the primitive equations: I.
    The basic experiment." Monthly weather review (1963)

Lilly, D. K. "The representation of small-scale turbulence in numerical simulation experiments." 
    NCAR Manuscript No. 281, 0, 1966.
"""
SmagorinskyLilly(FT::DataType; kwargs...) = SmagorinskyLilly(ExplicitTimeDiscretization(), FT; kwargs...)

SmagorinskyLilly(time_discretization::TD = ExplicitTimeDiscretization(), FT=Float64; C=0.16, Cb=1.0, Pr=1.0) where TD =
        SmagorinskyLilly{TD, FT}(C, Cb, Pr)

function with_tracers(tracers, closure::SmagorinskyLilly{TD, FT}) where {TD, FT}
    Pr = tracer_diffusivities(tracers, closure.Pr)
    return SmagorinskyLilly{TD, FT}(closure.C, closure.Cb, Pr)
end

"""
    stability(N², Σ², Cb)

Return the stability function

    ``\$ \\sqrt(1 - Cb N^2 / Σ^2 ) \$``

when ``N^2 > 0``, and 1 otherwise.
"""
@inline stability(N²::FT, Σ²::FT, Cb::FT) where FT =
    ifelse(Σ²==0, zero(FT), sqrt(one(FT) - stability_factor(N², Σ², Cb)))

@inline stability_factor(N²::FT, Σ²::FT, Cb::FT) where FT = min(one(FT), Cb * N² / Σ²)

"""
    νₑ_deardorff(ς, C, Δᶠ, Σ²)

Return the eddy viscosity for constant Smagorinsky
given the stability `ς`, model constant `C`,
filter width `Δᶠ`, and strain tensor dot product `Σ²`.
"""
@inline νₑ_deardorff(ς, C, Δᶠ, Σ²) = ς * (C*Δᶠ)^2 * sqrt(2Σ²)

@inline function calc_nonlinear_νᶜᶜᶜ(i, j, k, grid::AbstractGrid{FT}, closure::SmagorinskyLilly, buoyancy, velocities, tracers) where FT
    Σ² = ΣᵢⱼΣᵢⱼᶜᶜᶜ(i, j, k, grid, velocities.u, velocities.v, velocities.w)
    N² = max(zero(FT), ℑzᵃᵃᶜ(i, j, k, grid, ∂z_b, buoyancy, tracers))
    Δᶠ = Δᶠ_ccc(i, j, k, grid, closure)
    ς  = stability(N², Σ², closure.Cb) # Use unity Prandtl number.

    return νₑ_deardorff(ς, closure.C, Δᶠ, Σ²)
end


function calculate_diffusivities!(diffusivity_fields, closure::SmagorinskyLilly, model)

    arch = model.architecture
    grid = model.grid
    buoyancy = model.buoyancy
    velocities = model.velocities
    tracers = model.tracers

    event = launch!(arch, grid, :xyz,
                    calculate_nonlinear_viscosity!,
                    diffusivity_fields.νₑ, grid, closure, buoyancy, velocities, tracers,
                    dependencies = device_event(arch))

    wait(device(arch), event)

    return nothing
end

@inline κᶠᶜᶜ(i, j, k, grid, closure::SmagorinskyLilly, K, ::Val{id}, args...) where id = ℑxᶠᵃᵃ(i, j, k, grid, K.νₑ) / closure.Pr[id]
@inline κᶜᶠᶜ(i, j, k, grid, closure::SmagorinskyLilly, K, ::Val{id}, args...) where id = ℑyᵃᶠᵃ(i, j, k, grid, K.νₑ) / closure.Pr[id]
@inline κᶜᶜᶠ(i, j, k, grid, closure::SmagorinskyLilly, K, ::Val{id}, args...) where id = ℑzᵃᵃᶠ(i, j, k, grid, K.νₑ) / closure.Pr[id]

#####
##### Double dot product of strain on cell edges (currently unused)
#####

"Return the filter width for Constant Smagorinsky on a regular rectilinear grid."
@inline Δᶠ(i, j, k, grid, ::SmagorinskyLilly) = geo_mean_Δᶠ(i, j, k, grid)

# Temporarily set filter widths to cell-size (rather than distance between cell centers, etc.)
const Δᶠ_ccc = Δᶠ
const Δᶠ_ccf = Δᶠ
const Δᶠ_ffc = Δᶠ
const Δᶠ_fcf = Δᶠ
const Δᶠ_cff = Δᶠ

# tr_Σ² : ccc
#   Σ₁₂ : ffc
#   Σ₁₃ : fcf
#   Σ₂₃ : cff

"Return the double dot product of strain at `ccc`."
@inline function ΣᵢⱼΣᵢⱼᶜᶜᶜ(i, j, k, grid, u, v, w)
    return (
                    tr_Σ²(i, j, k, grid, u, v, w)
            + 2 * ℑxyᶜᶜᵃ(i, j, k, grid, Σ₁₂², u, v, w)
            + 2 * ℑxzᶜᵃᶜ(i, j, k, grid, Σ₁₃², u, v, w)
            + 2 * ℑyzᵃᶜᶜ(i, j, k, grid, Σ₂₃², u, v, w)
            )
end

"Return the double dot product of strain at `ffc`."
@inline function ΣᵢⱼΣᵢⱼᶠᶠᶜ(i, j, k, grid, u, v, w)
    return (
                  ℑxyᶠᶠᵃ(i, j, k, grid, tr_Σ², u, v, w)
            + 2 *    Σ₁₂²(i, j, k, grid, u, v, w)
            + 2 * ℑyzᵃᶠᶜ(i, j, k, grid, Σ₁₃², u, v, w)
            + 2 * ℑxzᶠᵃᶜ(i, j, k, grid, Σ₂₃², u, v, w)
            )
end

"Return the double dot product of strain at `fcf`."
@inline function ΣᵢⱼΣᵢⱼᶠᶜᶠ(i, j, k, grid, u, v, w)
    return (
                  ℑxzᶠᵃᶠ(i, j, k, grid, tr_Σ², u, v, w)
            + 2 * ℑyzᵃᶜᶠ(i, j, k, grid, Σ₁₂², u, v, w)
            + 2 *    Σ₁₃²(i, j, k, grid, u, v, w)
            + 2 * ℑxyᶠᶜᵃ(i, j, k, grid, Σ₂₃², u, v, w)
            )
end

"Return the double dot product of strain at `cff`."
@inline function ΣᵢⱼΣᵢⱼᶜᶠᶠ(i, j, k, grid, u, v, w)
    return (
                  ℑyzᵃᶠᶠ(i, j, k, grid, tr_Σ², u, v, w)
            + 2 * ℑxzᶜᵃᶠ(i, j, k, grid, Σ₁₂², u, v, w)
            + 2 * ℑxyᶜᶠᵃ(i, j, k, grid, Σ₁₃², u, v, w)
            + 2 *    Σ₂₃²(i, j, k, grid, u, v, w)
            )
end

@inline function ΣᵢⱼΣᵢⱼᶜᶜᶠ(i, j, k, grid, u, v, w)
    return (
                    ℑzᵃᵃᶠ(i, j, k, grid, tr_Σ², u, v, w)
            + 2 * ℑxyzᶜᶜᶠ(i, j, k, grid, Σ₁₂², u, v, w)
            + 2 *   ℑxᶜᵃᵃ(i, j, k, grid, Σ₁₃², u, v, w)
            + 2 *   ℑyᵃᶜᵃ(i, j, k, grid, Σ₂₃², u, v, w)
            )
end

Base.summary(closure::SmagorinskyLilly) = string("SmagorinskyLilly: C=$(closure.C), Cb=$(closure.Cb), Pr=$(closure.Pr)")
Base.show(io::IO, closure::SmagorinskyLilly) = print(io, summary(closure))

#####
##### For closures that only require an eddy viscosity νₑ field.
#####

function DiffusivityFields(grid, tracer_names, bcs, closure::SmagorinskyLilly)

    default_eddy_viscosity_bcs = (; νₑ = FieldBoundaryConditions(grid, (Center, Center, Center)))
    bcs = merge(default_eddy_viscosity_bcs, bcs)
    νₑ = CenterField(grid, boundary_conditions=bcs.νₑ)

    return (; νₑ)
end

