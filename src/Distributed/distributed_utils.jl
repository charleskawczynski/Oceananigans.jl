using Oceananigans.Fields: AbstractField
using Oceananigans.Grids:
    interior_indices,
    left_halo_indices, right_halo_indices,
    underlying_left_halo_indices, underlying_right_halo_indices

# TODO: Move to Grids/grid_utils.jl

#####
##### Viewing halos
#####

west_halo(f::AbstractField{LX, LY, LZ}; include_corners=true) where {LX, LY, LZ} =
    include_corners ? view(f.data, left_halo_indices(instantiate(LX), instantiate(topology(f, 1)), f.grid.Nx, f.grid.Hx), :, :) :
                      view(f.data, left_halo_indices(instantiate(LX), instantiate(topology(f, 1)), f.grid.Nx, f.grid.Hx),
                                   interior_indices(instantiate(LY), instantiate(topology(f, 2)), f.grid.Ny),
                                   interior_indices(instantiate(LZ), instantiate(topology(f, 3)), f.grid.Nz))

east_halo(f::AbstractField{LX, LY, LZ}; include_corners=true) where {LX, LY, LZ} =
    include_corners ? view(f.data, right_halo_indices(instantiate(LX), instantiate(topology(f, 1)), f.grid.Nx, f.grid.Hx), :, :) :
                      view(f.data, right_halo_indices(instantiate(LX), instantiate(topology(f, 1)), f.grid.Nx, f.grid.Hx),
                                   interior_indices(instantiate(LY), instantiate(topology(f, 2)), f.grid.Ny),
                                   interior_indices(instantiate(LZ), instantiate(topology(f, 3)), f.grid.Nz))

south_halo(f::AbstractField{LX, LY, LZ}; include_corners=true) where {LX, LY, LZ} =
    include_corners ? view(f.data, :, left_halo_indices(instantiate(LY), instantiate(topology(f, 2)), f.grid.Ny, f.grid.Hy), :) :
                      view(f.data, interior_indices(instantiate(LX), instantiate(topology(f, 1)), f.grid.Nx),
                                   left_halo_indices(instantiate(LY), instantiate(topology(f, 2)), f.grid.Ny, f.grid.Hy),
                                   interior_indices(instantiate(LZ), instantiate(topology(f, 3)), f.grid.Nz))

north_halo(f::AbstractField{LX, LY, LZ}; include_corners=true) where {LX, LY, LZ} =
    include_corners ? view(f.data, :, right_halo_indices(instantiate(LY), instantiate(topology(f, 2)), f.grid.Ny, f.grid.Hy), :) :
                      view(f.data, interior_indices(instantiate(LX), instantiate(topology(f, 1)), f.grid.Nx),
                                   right_halo_indices(instantiate(LY), instantiate(topology(f, 2)), f.grid.Ny, f.grid.Hy),
                                   interior_indices(instantiate(LZ), instantiate(topology(f, 3)), f.grid.Nz))

bottom_halo(f::AbstractField{LX, LY, LZ}; include_corners=true) where {LX, LY, LZ} =
    include_corners ? view(f.data, :, :, left_halo_indices(instantiate(LZ), instantiate(topology(f, 3)), f.grid.Nz, f.grid.Hz)) :
                      view(f.data, interior_indices(instantiate(LX), instantiate(topology(f, 1)), f.grid.Nx),
                                   interior_indices(instantiate(LY), instantiate(topology(f, 2)), f.grid.Ny),
                                   left_halo_indices(instantiate(LZ), instantiate(topology(f, 3)), f.grid.Nz, f.grid.Hz))

top_halo(f::AbstractField{LX, LY, LZ}; include_corners=true) where {LX, LY, LZ} =
    include_corners ? view(f.data, :, :, right_halo_indices(instantiate(LZ), instantiate(topology(f, 3)), f.grid.Nz, f.grid.Hz)) :
                      view(f.data, interior_indices(instantiate(LX), instantiate(topology(f, 1)), f.grid.Nx),
                                   interior_indices(instantiate(LY), instantiate(topology(f, 2)), f.grid.Ny),
                                   right_halo_indices(instantiate(LZ), instantiate(topology(f, 3)), f.grid.Nz, f.grid.Hz))

instantiate(T::Type) = T()
instantiate(t) = t

underlying_west_halo(f, grid, location) =
    view(f.parent, underlying_left_halo_indices(instantiate(location), instantiate(topology(grid, 1)), grid.Nx, grid.Hx), :, :)

underlying_east_halo(f, grid, location) =
    view(f.parent, underlying_right_halo_indices(instantiate(location), instantiate(topology(grid, 1)), grid.Nx, grid.Hx), :, :)

underlying_south_halo(f, grid, location) =
    view(f.parent, :, underlying_left_halo_indices(instantiate(location), instantiate(topology(grid, 2)), grid.Ny, grid.Hy), :)

underlying_north_halo(f, grid, location) =
    view(f.parent, :, underlying_right_halo_indices(instantiate(location), instantiate(topology(grid, 2)), grid.Ny, grid.Hy), :)

underlying_bottom_halo(f, grid, location) =
    view(f.parent, :, :, underlying_left_halo_indices(instantiate(location), instantiate(topology(grid, 3)), grid.Nz, grid.Hz))

underlying_top_halo(f, grid, location) =
    view(f.parent, :, :, underlying_right_halo_indices(instantiate(location), instantiate(topology(grid, 3)), grid.Nz, grid.Hz))

#####
##### Viewing boundary grid points (used to fill other halos)
#####

underlying_left_boundary_indices(loc, topo, N, H) = 1+H:2H
underlying_left_boundary_indices(::Nothing, topo, N, H) = 1:0 # empty

underlying_right_boundary_indices(loc, topo, N, H) = N+1:N+H
underlying_right_boundary_indices(::Nothing, topo, N, H) = 1:0 # empty

underlying_west_boundary(f, grid, location) =
    view(f.parent, underlying_left_boundary_indices(instantiate(location), instantiate(topology(grid, 1)), grid.Nx, grid.Hx), :, :)

underlying_east_boundary(f, grid, location) =
    view(f.parent, underlying_right_boundary_indices(instantiate(location), instantiate(topology(grid, 1)), grid.Nx, grid.Hx), :, :)

underlying_south_boundary(f, grid, location) =
    view(f.parent, :, underlying_left_boundary_indices(instantiate(location), instantiate(topology(grid, 2)), grid.Ny, grid.Hy), :)

underlying_north_boundary(f, grid, location) =
    view(f.parent, :, underlying_right_boundary_indices(instantiate(location), instantiate(topology(grid, 2)), grid.Ny, grid.Hy), :)

underlying_bottom_boundary(f, grid, location) =
    view(f.parent, :, :, underlying_left_boundary_indices(instantiate(location), instantiate(topology(grid, 3)), grid.Nz, grid.Hz))

underlying_top_boundary(f, grid, location) =
    view(f.parent, :, :, underlying_right_boundary_indices(instantiate(location), instantiate(topology(grid, 3)), grid.Nz, grid.Hz))
