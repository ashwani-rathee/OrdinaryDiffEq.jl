## Integrator Dispatches

# Can get rid of an allocation here with a function
# get_tmp_arr(integrator.cache) which gives a pointer to some
# cache array which can be modified.

function ode_addsteps!{calcVal,calcVal2,calcVal3}(integrator,f=integrator.f,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if !(typeof(integrator.cache) <: CompositeCache)
    ode_addsteps!(integrator.k,integrator.tprev,integrator.uprev,integrator.u,integrator.dt,f,integrator.cache,always_calc_begin,allow_calc_end,force_calc_end)
  else
    ode_addsteps!(integrator.k,integrator.tprev,integrator.uprev,integrator.u,integrator.dt,f,integrator.cache.caches[integrator.cache.current],always_calc_begin,allow_calc_end,force_calc_end)
  end
end

function ode_interpolant(Θ,integrator)
  ode_addsteps!(integrator)
  if !(typeof(integrator.cache) <: CompositeCache)
    ode_interpolant(Θ,integrator.dt,integrator.uprev,integrator.u,integrator.k,integrator.cache)
  else
    ode_interpolant(Θ,integrator.dt,integrator.uprev,integrator.u,integrator.k,integrator.cache.caches[integrator.cache.current])
  end
end

function current_interpolant(t::Number,integrator)
  Θ = (t-integrator.tprev)/integrator.dt
  ode_interpolant(Θ,integrator)
end

function current_interpolant(t::AbstractArray,integrator)
  Θ = (t.-integrator.tprev)./integrator.dt
  [ode_interpolant(ϕ,integrator) for ϕ in Θ]
end

function current_extrapolant(t::Number,integrator)
  Θ = (t-integrator.tprev)/(integrator.t-integrator.tprev)
  ode_extrapolant(Θ,integrator)
end

function current_extrapolant(t::AbstractArray,integrator)
  Θ = (t.-integrator.tprev)./(integrator.t-integrator.tprev)
  [ode_extrapolant(ϕ,integrator) for ϕ in Θ]
end

function ode_extrapolant(Θ,integrator)
  ode_addsteps!(integrator)
  if !(typeof(integrator.cache) <: CompositeCache)
    ode_interpolant(Θ,integrator.t-integrator.tprev,integrator.uprev2,integrator.uprev,integrator.k,integrator.cache)
  else
    ode_interpolant(Θ,integrator.t-integrator.tprev,integrator.uprev2,integrator.uprev,integrator.k,integrator.cache.caches[integrator.cache.current])
  end
end

##

"""
ode_interpolation(tvals,ts,timeseries,ks)

Get the value at tvals where the solution is known at the
times ts (sorted), with values timeseries and derivatives ks
"""
function ode_interpolation(tvals,id)
  @unpack ts,timeseries,ks,f,notsaveat_idxs,cache = id
  tdir = sign(ts[end]-ts[1])
  idx = sortperm(tvals)
  i = 2 # Start the search thinking it's between ts[1] and ts[2]
  vals = Vector{eltype(timeseries)}(length(tvals))
  for j in idx
    t = tvals[j]
    i = findfirst((x)->tdir*x>=tdir*t,ts[notsaveat_idxs[i:end]])+i-1 # It's in the interval ts[i-1] to ts[i]
    if ts[notsaveat_idxs[i]] == t
      vals[j] = timeseries[notsaveat_idxs[i]]
    elseif ts[notsaveat_idxs[i-1]] == t # Can happen if it's the first value!
      vals[j] = timeseries[notsaveat_idxs[i-1]]
    else
      dt = ts[notsaveat_idxs[i]] - ts[notsaveat_idxs[i-1]]
      Θ = (t-ts[notsaveat_idxs[i-1]])/dt
      if typeof(cache) <: CompositeCache
        ode_addsteps!(ks[i],ts[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],dt,f,cache.caches[id.alg_choice[notsaveat_idxs[i-1]]]) # update the kcurrent
        vals[j] = ode_interpolant(Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache.caches[id.alg_choice[notsaveat_idxs[i-1]]])
      else
        ode_addsteps!(ks[i],ts[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],dt,f,cache) # update the kcurrent
        vals[j] = ode_interpolant(Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache)
      end
    end
  end
  vals
end

"""
ode_interpolation(tvals,ts,timeseries,ks)

Get the value at tvals where the solution is known at the
times ts (sorted), with values timeseries and derivatives ks
"""
function ode_interpolation!(vals,tvals,id)
  @unpack ts,timeseries,ks,f,notsaveat_idxs,cache = id
  tdir = sign(ts[end]-ts[1])
  idx = sortperm(tvals)
  i = 2 # Start the search thinking it's between ts[1] and ts[2]
  for j in idx
    t = tvals[j]
    i = findfirst((x)->tdir*x>=tdir*t,ts[notsaveat_idxs[i:end]])+i-1 # It's in the interval ts[i-1] to ts[i]
    if ts[notsaveat_idxs[i]] == t
      vals[j] = timeseries[notsaveat_idxs[i]]
    elseif ts[notsaveat_idxs[i-1]] == t # Can happen if it's the first value!
      vals[j] = timeseries[notsaveat_idxs[i-1]]
    else
      dt = ts[notsaveat_idxs[i]] - ts[notsaveat_idxs[i-1]]
      Θ = (t-ts[notsaveat_idxs[i-1]])/dt
      if typeof(cache) <: CompositeCache
        ode_addsteps!(ks[i],ts[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],dt,f,cache.caches[id.alg_choice[notsaveat_idxs[i-1]]]) # update the kcurrent
        if eltype(timeseries) <: AbstractArray
          ode_interpolant!(vals[j],Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache.caches[id.alg_choice[notsaveat_idxs[i-1]]])
        else
          vals[j] = ode_interpolant(Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache.caches[id.alg_choice[notsaveat_idxs[i-1]]])
        end
      else
        ode_addsteps!(ks[i],ts[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],dt,f,cache) # update the kcurrent
        if eltype(timeseries) <: AbstractArray
          ode_interpolant!(vals[j],Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache)
        else
          vals[j] = ode_interpolant(Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache)
        end
      end
    end
  end
end

"""
ode_interpolation(tval::Number,ts,timeseries,ks)

Get the value at tval where the solution is known at the
times ts (sorted), with values timeseries and derivatives ks
"""
function ode_interpolation(tval::Number,id)
  @unpack ts,timeseries,ks,f,notsaveat_idxs,cache = id
  tdir = sign(ts[end]-ts[1])
  i = findfirst((x)->tdir*x>=tdir*tval,@view ts[notsaveat_idxs]) # It's in the interval ts[i-1] to ts[i]
  if ts[notsaveat_idxs[i]] == tval
    val = timeseries[notsaveat_idxs[i]]
  elseif ts[notsaveat_idxs[i-1]] == tval # Can happen if it's the first value!
    push!(vals,timeseries[notsaveat_idxs[i-1]])
  else
    dt = ts[notsaveat_idxs[i]] - ts[notsaveat_idxs[i-1]]
    Θ = (tval-ts[notsaveat_idxs[i-1]])/dt
    if typeof(cache) <: CompositeCache
      ode_addsteps!(ks[i],ts[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],dt,f,cache.caches[id.alg_choice[notsaveat_idxs[i-1]]]) # update the kcurrent
      val = ode_interpolant(Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache.caches[id.alg_choice[notsaveat_idxs[i-1]]])
    else
      ode_addsteps!(ks[i],ts[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],dt,f,cache) # update the kcurrent
      val = ode_interpolant(Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache)
    end
  end
  val
end

"""
ode_interpolation!(out,tval::Number,ts,timeseries,ks)

Get the value at tval where the solution is known at the
times ts (sorted), with values timeseries and derivatives ks
"""
function ode_interpolation!(out,tval::Number,id)
  @unpack ts,timeseries,ks,f,notsaveat_idxs,cache = id
  tdir = sign(ts[end]-ts[1])
  i = findfirst((x)->tdir*x>=tdir*tval,@view ts[notsaveat_idxs]) # It's in the interval ts[i-1] to ts[i]
  if ts[notsaveat_idxs[i]] == tval
    val = timeseries[notsaveat_idxs[i]]
  elseif ts[notsaveat_idxs[i-1]] == tval # Can happen if it's the first value!
    push!(vals,timeseries[notsaveat_idxs[i-1]])
  else
    dt = ts[notsaveat_idxs[i]] - ts[notsaveat_idxs[i-1]]
    Θ = (tval-ts[notsaveat_idxs[i-1]])/dt
    if typeof(cache) <: CompositeCache
      ode_addsteps!(ks[i],ts[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],dt,f,cache.caches[id.alg_choice[notsaveat_idxs[i-1]]]) # update the kcurrent
      ode_interpolant!(out,Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache.caches[id.alg_choice[notsaveat_idxs[i-1]]])
    else
      ode_addsteps!(ks[i],ts[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],dt,f,cache) # update the kcurrent
      ode_interpolant!(out,Θ,dt,timeseries[notsaveat_idxs[i-1]],timeseries[notsaveat_idxs[i]],ks[i],cache)
    end
  end
end

"""
By default, simpledense
"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<2 || calcVal
    if !(typeof(uprev)<:AbstractArray)
      copyat_or_push!(k,1,f(t,uprev))
      copyat_or_push!(k,2,f(t+dt,u))
    else
      rtmp = similar(cache.fsalfirst)
      f(t,uprev,rtmp)
      copyat_or_push!(k,1,rtmp)
      f(t+dt,u,rtmp)
      copyat_or_push!(k,2,rtmp)
    end
  end
  nothing
end

function ode_interpolant(Θ,dt,y₀,y₁,k,cache::OrdinaryDiffEqMutableCache)
  out = similar(y₀)
  ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache)
  out
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 190

Herimte Interpolation, chosen if no other dispatch for ode_interpolant
"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache) # Default interpolant is Hermite
  if typeof(y₀) <: AbstractArray
    out = similar(y₀)
    for i in eachindex(out)
      out[i] = (1-Θ)*y₀[i]+Θ*y₁[i]+Θ*(Θ-1)*((1-2Θ)*(y₁[i]-y₀[i])+(Θ-1)*dt*k[1][i] + Θ*dt*k[2][i])
    end
  else
    out = (1-Θ)*y₀+Θ*y₁+Θ*(Θ-1)*((1-2Θ)*(y₁-y₀)+(Θ-1)*dt*k[1] + Θ*dt*k[2])
  end
  out
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 190

Herimte Interpolation, chosen if no other dispatch for ode_interpolant
"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache) # Default interpolant is Hermite
  for i in eachindex(out)
    out[i] = (1-Θ)*y₀[i]+Θ*y₁[i]+Θ*(Θ-1)*((1-2Θ)*(y₁[i]-y₀[i])+(Θ-1)*dt*k[1][i] + Θ*dt*k[2][i])
  end
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 192
"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP5ConstantCache)
  Θ1 = 1-Θ
  y₀ + dt*Θ*(k[1]+Θ1*(k[2]+Θ*(k[3]+Θ1*k[4])))
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 192
"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::DP5Cache)
  Θ1 = 1-Θ
  for i in eachindex(out)
    out[i] = y₀[i] + dt*Θ*(k[1][i]+Θ1*(k[2][i]+Θ*(k[3][i]+Θ1*k[4][i])))
  end
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 192
"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::DP5ThreadedCache)
  Θ1 = 1-Θ
  for i in eachindex(out)
    out[i] = y₀[i] + dt*Θ*(k[1][i]+Θ1*(k[2][i]+Θ*(k[3][i]+Θ1*k[4][i])))
  end
end

"""
From MATLAB ODE Suite by Shampine
"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Rosenbrock23ConstantCache)
  d = cache.d
  c1 = Θ*(1-Θ)/(1-2d)
  c2 = Θ*(Θ-2d)/(1-2d)
  y₀ + dt*(c1*k[1] + c2*k[2])
end

"""
From MATLAB ODE Suite by Shampine
"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Rosenbrock23Cache)
  d = cache.tab.d
  c1 = Θ*(1-Θ)/(1-2d)
  c2 = Θ*(Θ-2d)/(1-2d)
  for i in eachindex(out)
    out[i] = y₀[i] + dt*(c1*k[1][i] + c2*k[2][i])
  end
end

"""
From MATLAB ODE Suite by Shampine
"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Rosenbrock32ConstantCache)
  d = cache.d
  c1 = Θ*(1-Θ)/(1-2d)
  c2 = Θ*(Θ-2d)/(1-2d)
  y₀ + dt*(c1*k[1] + c2*k[2])
end

"""
From MATLAB ODE Suite by Shampine
"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Rosenbrock32Cache)
  d = cache.tab.d
  c1 = Θ*(1-Θ)/(1-2d)
  c2 = Θ*(Θ-2d)/(1-2d)
  y₀ + dt*(c1*k[1] + c2*k[2])
  for i in eachindex(out)
    out[i] = y₀[i] + dt*(c1*k[1][i] + c2*k[2][i])
  end
end

"""
Runge–Kutta pairs of order 5(4) satisfying only the first column
simplifying assumption

Ch. Tsitouras
"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Tsit5Cache)
  b1Θ = -1.0530884977290216Θ * (Θ - 1.3299890189751412)*(Θ^2 - 1.4364028541716351Θ + 0.7139816917074209)
  b2Θ = 0.1017Θ^2 * (Θ^2 - 2.1966568338249754Θ + 1.2949852507374631)
  b3Θ = 2.490627285651252793Θ^2 * (Θ^2 - 2.38535645472061657Θ + 1.57803468208092486)
  b4Θ = -16.54810288924490272*(Θ - 1.21712927295533244)*(Θ - 0.61620406037800089)*Θ^2
  b5Θ = 47.37952196281928122*(Θ - 1.203071208372362603)*(Θ - 0.658047292653547382)*Θ^2
  b6Θ = -34.87065786149660974*(Θ - 1.2)*(Θ - 0.666666666666666667)*Θ^2
  b7Θ = 2.5*(Θ - 1)*(Θ - 0.6)*Θ^2
  for i in eachindex(out)
    out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[2][i]*b2Θ + k[3][i]*b3Θ + k[4][i]*b4Θ + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ)
  end
end

"""
Runge–Kutta pairs of order 5(4) satisfying only the first column
simplifying assumption

Ch. Tsitouras
"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Tsit5ConstantCache)
  b1Θ = -1.0530884977290216Θ * (Θ - 1.3299890189751412)*(Θ^2 - 1.4364028541716351Θ + 0.7139816917074209)
  b2Θ = 0.1017Θ^2 * (Θ^2 - 2.1966568338249754Θ + 1.2949852507374631)
  b3Θ = 2.490627285651252793Θ^2 * (Θ^2 - 2.38535645472061657Θ + 1.57803468208092486)
  b4Θ = -16.54810288924490272*(Θ - 1.21712927295533244)*(Θ - 0.61620406037800089)*Θ^2
  b5Θ = 47.37952196281928122*(Θ - 1.203071208372362603)*(Θ - 0.658047292653547382)*Θ^2
  b6Θ = -34.87065786149660974*(Θ - 1.2)*(Θ - 0.666666666666666667)*Θ^2
  b7Θ = 2.5*(Θ - 1)*(Θ - 0.6)*Θ^2
  y₀ + dt*(k[1]*b1Θ + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ)
end

"""
Coefficients taken from RKSuite
"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::BS5ConstantCache)
  @unpack r016,r015,r014,r013,r012,r036,r035,r034,r033,r032,r046,r045,r044,r043,r042,r056,r055,r054,r053,r052,r066,r065,r064,r063,r062,r076,r075,r074,r073,r072,r086,r085,r084,r083,r082,r096,r095,r094,r093,r106,r105,r104,r103,r102,r116,r115,r114,r113,r112 = cache
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
#=
  bΘ6 = r056*k[5] +
  ((r106*k[10]+r086*k[8])+
  (r076*k[7]+r066*k[6])) +
  ((r046*k[4]+r096*k[9])+
  (r036*k[3]+r116*k[11])+
  r016*k[1])


  bΘ5 = (r105*k[10]+r095*k[9]) +
   ((r075*k[7]+r065*k[6])+
   r055*k[5]) + ((r045*k[4]+
   r085*k[8])+(r035*k[3]+r115*k[11])+r015*k[1])

 bΘ4 = ((r044*k[4]+r084*k[8])+
         (r074*k[7]+r064*k[6])+
         r054*k[5]) + ((r104*k[10]+
         r094*k[9])+(r034*k[3]+
         r114*k[11])+r014*k[1])


  bΘ3 = r053*k[5] + r063*k[6] +
         ((r033*k[3]+r093*k[9])+
         (r103*k[10]+r083*k[8])+r013*
         k[1])+((r043*k[4]+r113*
         k[11])+r073*k[7])

  bΘ2 = r052*k[5] + ((r062*k[6]+
         r082*k[8])+r012*k[1]) +
         ((r032*k[3]+r092*k[9])+
         r102*k[10]) + ((r042*k[4]+
         r112*k[11])+r072*k[7])

  return y₀ + dt*Θ*k[1] + dt*(bΘ2*Θ2 + Θ3*bΘ3 + Θ4*bΘ4 + Θ5*bΘ5 + Θ6*bΘ6)
=#

  b1Θ =           r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6
  b3Θ =           r032*Θ2 + r033*Θ3 + r034*Θ4 + r035*Θ5 + r036*Θ6
  b4Θ =           r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6
  b5Θ =           r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6
  b6Θ =           r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6
  b7Θ =           r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6
  b8Θ =           r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6
  b9Θ =                     r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6
  b10Θ=           r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6
  b11Θ=           r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6
  y₀ + dt*Θ*k[1] + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ  + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ)
end

"""
Coefficients taken from RKSuite
"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::BS5Cache)
  @unpack r016,r015,r014,r013,r012,r036,r035,r034,r033,r032,r046,r045,r044,r043,r042,r056,r055,r054,r053,r052,r066,r065,r064,r063,r062,r076,r075,r074,r073,r072,r086,r085,r084,r083,r082,r096,r095,r094,r093,r106,r105,r104,r103,r102,r116,r115,r114,r113,r112 = cache.tab
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
#=
  bΘ6 = r056*k[5] +
  ((r106*k[10]+r086*k[8])+
  (r076*k[7]+r066*k[6])) +
  ((r046*k[4]+r096*k[9])+
  (r036*k[3]+r116*k[11])+
  r016*k[1])


  bΘ5 = (r105*k[10]+r095*k[9]) +
   ((r075*k[7]+r065*k[6])+
   r055*k[5]) + ((r045*k[4]+
   r085*k[8])+(r035*k[3]+r115*k[11])+r015*k[1])

 bΘ4 = ((r044*k[4]+r084*k[8])+
         (r074*k[7]+r064*k[6])+
         r054*k[5]) + ((r104*k[10]+
         r094*k[9])+(r034*k[3]+
         r114*k[11])+r014*k[1])


  bΘ3 = r053*k[5] + r063*k[6] +
         ((r033*k[3]+r093*k[9])+
         (r103*k[10]+r083*k[8])+r013*
         k[1])+((r043*k[4]+r113*
         k[11])+r073*k[7])

  bΘ2 = r052*k[5] + ((r062*k[6]+
         r082*k[8])+r012*k[1]) +
         ((r032*k[3]+r092*k[9])+
         r102*k[10]) + ((r042*k[4]+
         r112*k[11])+r072*k[7])

  return y₀ + dt*Θ*k[1] + dt*(bΘ2*Θ2 + Θ3*bΘ3 + Θ4*bΘ4 + Θ5*bΘ5 + Θ6*bΘ6)
=#

  b1Θ =           r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6
  b3Θ =           r032*Θ2 + r033*Θ3 + r034*Θ4 + r035*Θ5 + r036*Θ6
  b4Θ =           r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6
  b5Θ =           r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6
  b6Θ =           r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6
  b7Θ =           r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6
  b8Θ =           r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6
  b9Θ =                     r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6
  b10Θ=           r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6
  b11Θ=           r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6
  for i in eachindex(out)
    out[i] = y₀[i] + dt*Θ*k[1][i] + dt*(k[1][i]*b1Θ  + k[3][i]*b3Θ + k[4][i]*b4Θ  + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ)
  end
end

"""

"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern6Cache)
  @unpack r011,r012,r013,r014,r015,r016,r042,r043,r044,r045,r046,r052,r053,r054,r055,r056,r062,r063,r064,r065,r066,r072,r073,r074,r075,r076,r082,r083,r084,r085,r086,r092,r093,r094,r095,r096,r102,r103,r104,r105,r106,r112,r113,r114,r115,r116,r122,r123,r124,r125,r126 = cache.tab
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6
  b4Θ =          r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6
  b5Θ =          r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6
  b6Θ =          r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6
  b7Θ =          r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6
  b10Θ=          r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6
  for i in eachindex(out)
    out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[4][i]*b4Θ + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ + k[12][i]*b12Θ)
  end
end

"""

"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern6ConstantCache)
  @unpack r011,r012,r013,r014,r015,r016,r042,r043,r044,r045,r046,r052,r053,r054,r055,r056,r062,r063,r064,r065,r066,r072,r073,r074,r075,r076,r082,r083,r084,r085,r086,r092,r093,r094,r095,r096,r102,r103,r104,r105,r106,r112,r113,r114,r115,r116,r122,r123,r124,r125,r126 = cache
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6
  b4Θ =          r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6
  b5Θ =          r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6
  b6Θ =          r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6
  b7Θ =          r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6
  b10Θ=          r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6
  y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ)
end

"""

"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern7ConstantCache)
  @unpack r011,r012,r013,r014,r015,r016,r017,r042,r043,r044,r045,r046,r047,r052,r053,r054,r055,r056,r057,r062,r063,r064,r065,r066,r067,r072,r073,r074,r075,r076,r077,r082,r083,r084,r085,r086,r087,r092,r093,r094,r095,r096,r097,r112,r113,r114,r115,r116,r117,r122,r123,r124,r125,r126,r127,r132,r133,r134,r135,r136,r137,r142,r143,r144,r145,r146,r147,r152,r153,r154,r155,r156,r157,r162,r163,r164,r165,r166,r167 = cache
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  Θ7 = Θ6*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6 + r017*Θ7
  b4Θ =          r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6 + r047*Θ7
  b5Θ =          r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6 + r057*Θ7
  b6Θ =          r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6 + r067*Θ7
  b7Θ =          r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6 + r077*Θ7
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6 + r087*Θ7
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6 + r097*Θ7
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6 + r117*Θ7
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6 + r127*Θ7
  b13Θ=          r132*Θ2 + r133*Θ3 + r134*Θ4 + r135*Θ5 + r136*Θ6 + r137*Θ7
  b14Θ=          r142*Θ2 + r143*Θ3 + r144*Θ4 + r145*Θ5 + r146*Θ6 + r147*Θ7
  b15Θ=          r152*Θ2 + r153*Θ3 + r154*Θ4 + r155*Θ5 + r156*Θ6 + r157*Θ7
  b16Θ=          r162*Θ2 + r163*Θ3 + r164*Θ4 + r165*Θ5 + r166*Θ6 + r167*Θ7
  y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ)
end

"""

"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern7Cache)
  @unpack r011,r012,r013,r014,r015,r016,r017,r042,r043,r044,r045,r046,r047,r052,r053,r054,r055,r056,r057,r062,r063,r064,r065,r066,r067,r072,r073,r074,r075,r076,r077,r082,r083,r084,r085,r086,r087,r092,r093,r094,r095,r096,r097,r112,r113,r114,r115,r116,r117,r122,r123,r124,r125,r126,r127,r132,r133,r134,r135,r136,r137,r142,r143,r144,r145,r146,r147,r152,r153,r154,r155,r156,r157,r162,r163,r164,r165,r166,r167 = cache.tab
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  Θ7 = Θ6*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6 + r017*Θ7
  b4Θ =          r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6 + r047*Θ7
  b5Θ =          r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6 + r057*Θ7
  b6Θ =          r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6 + r067*Θ7
  b7Θ =          r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6 + r077*Θ7
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6 + r087*Θ7
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6 + r097*Θ7
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6 + r117*Θ7
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6 + r127*Θ7
  b13Θ=          r132*Θ2 + r133*Θ3 + r134*Θ4 + r135*Θ5 + r136*Θ6 + r137*Θ7
  b14Θ=          r142*Θ2 + r143*Θ3 + r144*Θ4 + r145*Θ5 + r146*Θ6 + r147*Θ7
  b15Θ=          r152*Θ2 + r153*Θ3 + r154*Θ4 + r155*Θ5 + r156*Θ6 + r157*Θ7
  b16Θ=          r162*Θ2 + r163*Θ3 + r164*Θ4 + r165*Θ5 + r166*Θ6 + r167*Θ7
  for i in eachindex(out)
    out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[4][i]*b4Θ + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[11][i]*b11Θ + k[12][i]*b12Θ + k[13][i]*b13Θ + k[14][i]*b14Θ + k[15][i]*b15Θ + k[16][i]*b16Θ)
  end
end

"""

"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern8ConstantCache)
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r062,r063,r064,r065,r066,r067,r068,r072,r073,r074,r075,r076,r077,r078,r082,r083,r084,r085,r086,r087,r088,r092,r093,r094,r095,r096,r097,r098,r102,r103,r104,r105,r106,r107,r108,r112,r113,r114,r115,r116,r117,r118,r122,r123,r124,r125,r126,r127,r128,r142,r143,r144,r145,r146,r147,r148,r152,r153,r154,r155,r156,r157,r158,r162,r163,r164,r165,r166,r167,r168,r172,r173,r174,r175,r176,r177,r178,r182,r183,r184,r185,r186,r187,r188,r192,r193,r194,r195,r196,r197,r198,r202,r203,r204,r205,r206,r207,r208,r212,r213,r214,r215,r216,r217,r218 = cache
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  Θ7 = Θ6*Θ
  Θ8 = Θ7*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6 + r017*Θ7 + r018*Θ8
  b6Θ =          r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6 + r067*Θ7 + r068*Θ8
  b7Θ =          r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6 + r077*Θ7 + r078*Θ8
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6 + r087*Θ7 + r088*Θ8
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6 + r097*Θ7 + r098*Θ8
  b10Θ=          r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6 + r107*Θ7 + r108*Θ8
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6 + r117*Θ7 + r118*Θ8
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6 + r127*Θ7 + r128*Θ8
  b14Θ=          r142*Θ2 + r143*Θ3 + r144*Θ4 + r145*Θ5 + r146*Θ6 + r147*Θ7 + r148*Θ8
  b15Θ=          r152*Θ2 + r153*Θ3 + r154*Θ4 + r155*Θ5 + r156*Θ6 + r157*Θ7 + r158*Θ8
  b16Θ=          r162*Θ2 + r163*Θ3 + r164*Θ4 + r165*Θ5 + r166*Θ6 + r167*Θ7 + r168*Θ8
  b17Θ=          r172*Θ2 + r173*Θ3 + r174*Θ4 + r175*Θ5 + r176*Θ6 + r177*Θ7 + r178*Θ8
  b18Θ=          r182*Θ2 + r183*Θ3 + r184*Θ4 + r185*Θ5 + r186*Θ6 + r187*Θ7 + r188*Θ8
  b19Θ=          r192*Θ2 + r193*Θ3 + r194*Θ4 + r195*Θ5 + r196*Θ6 + r197*Θ7 + r198*Θ8
  b20Θ=          r202*Θ2 + r203*Θ3 + r204*Θ4 + r205*Θ5 + r206*Θ6 + r207*Θ7 + r208*Θ8
  b21Θ=          r212*Θ2 + r213*Θ3 + r214*Θ4 + r215*Θ5 + r216*Θ6 + r217*Θ7 + r218*Θ8
  y₀ + dt*(k[1]*b1Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ)
end

"""

"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern8Cache)
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r062,r063,r064,r065,r066,r067,r068,r072,r073,r074,r075,r076,r077,r078,r082,r083,r084,r085,r086,r087,r088,r092,r093,r094,r095,r096,r097,r098,r102,r103,r104,r105,r106,r107,r108,r112,r113,r114,r115,r116,r117,r118,r122,r123,r124,r125,r126,r127,r128,r142,r143,r144,r145,r146,r147,r148,r152,r153,r154,r155,r156,r157,r158,r162,r163,r164,r165,r166,r167,r168,r172,r173,r174,r175,r176,r177,r178,r182,r183,r184,r185,r186,r187,r188,r192,r193,r194,r195,r196,r197,r198,r202,r203,r204,r205,r206,r207,r208,r212,r213,r214,r215,r216,r217,r218 = cache.tab
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  Θ7 = Θ6*Θ
  Θ8 = Θ7*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6 + r017*Θ7 + r018*Θ8
  b6Θ =          r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6 + r067*Θ7 + r068*Θ8
  b7Θ =          r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6 + r077*Θ7 + r078*Θ8
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6 + r087*Θ7 + r088*Θ8
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6 + r097*Θ7 + r098*Θ8
  b10Θ=          r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6 + r107*Θ7 + r108*Θ8
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6 + r117*Θ7 + r118*Θ8
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6 + r127*Θ7 + r128*Θ8
  b14Θ=          r142*Θ2 + r143*Θ3 + r144*Θ4 + r145*Θ5 + r146*Θ6 + r147*Θ7 + r148*Θ8
  b15Θ=          r152*Θ2 + r153*Θ3 + r154*Θ4 + r155*Θ5 + r156*Θ6 + r157*Θ7 + r158*Θ8
  b16Θ=          r162*Θ2 + r163*Θ3 + r164*Θ4 + r165*Θ5 + r166*Θ6 + r167*Θ7 + r168*Θ8
  b17Θ=          r172*Θ2 + r173*Θ3 + r174*Θ4 + r175*Θ5 + r176*Θ6 + r177*Θ7 + r178*Θ8
  b18Θ=          r182*Θ2 + r183*Θ3 + r184*Θ4 + r185*Θ5 + r186*Θ6 + r187*Θ7 + r188*Θ8
  b19Θ=          r192*Θ2 + r193*Θ3 + r194*Θ4 + r195*Θ5 + r196*Θ6 + r197*Θ7 + r198*Θ8
  b20Θ=          r202*Θ2 + r203*Θ3 + r204*Θ4 + r205*Θ5 + r206*Θ6 + r207*Θ7 + r208*Θ8
  b21Θ=          r212*Θ2 + r213*Θ3 + r214*Θ4 + r215*Θ5 + r216*Θ6 + r217*Θ7 + r218*Θ8
  for i in eachindex(out)
    out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ + k[12][i]*b12Θ + k[14][i]*b14Θ + k[15][i]*b15Θ + k[16][i]*b16Θ + k[17][i]*b17Θ + k[18][i]*b18Θ + k[19][i]*b19Θ + k[20][i]*b20Θ + k[21][i]*b21Θ)
  end
end

"""

"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern9ConstantCache)
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r019,r082,r083,r084,r085,r086,r087,r088,r089,r092,r093,r094,r095,r096,r097,r098,r099,r102,r103,r104,r105,r106,r107,r108,r109,r112,r113,r114,r115,r116,r117,r118,r119,r122,r123,r124,r125,r126,r127,r128,r129,r132,r133,r134,r135,r136,r137,r138,r139,r142,r143,r144,r145,r146,r147,r148,r149,r152,r153,r154,r155,r156,r157,r158,r159,r172,r173,r174,r175,r176,r177,r178,r179,r182,r183,r184,r185,r186,r187,r188,r189,r192,r193,r194,r195,r196,r197,r198,r199,r202,r203,r204,r205,r206,r207,r208,r209,r212,r213,r214,r215,r216,r217,r218,r219,r222,r223,r224,r225,r226,r227,r228,r229,r232,r233,r234,r235,r236,r237,r238,r239,r242,r243,r244,r245,r246,r247,r248,r249,r252,r253,r254,r255,r256,r257,r258,r259,r262,r263,r264,r265,r266,r267,r268,r269 = cache
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  Θ7 = Θ6*Θ
  Θ8 = Θ7*Θ
  Θ9 = Θ8*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6 + r017*Θ7 + r018*Θ8 + r019*Θ9
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6 + r087*Θ7 + r088*Θ8 + r089*Θ9
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6 + r097*Θ7 + r098*Θ8 + r099*Θ9
  b10Θ=          r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6 + r107*Θ7 + r108*Θ8 + r109*Θ9
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6 + r117*Θ7 + r118*Θ8 + r119*Θ9
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6 + r127*Θ7 + r128*Θ8 + r129*Θ9
  b13Θ=          r132*Θ2 + r133*Θ3 + r134*Θ4 + r135*Θ5 + r136*Θ6 + r137*Θ7 + r138*Θ8 + r139*Θ9
  b14Θ=          r142*Θ2 + r143*Θ3 + r144*Θ4 + r145*Θ5 + r146*Θ6 + r147*Θ7 + r148*Θ8 + r149*Θ9
  b15Θ=          r152*Θ2 + r153*Θ3 + r154*Θ4 + r155*Θ5 + r156*Θ6 + r157*Θ7 + r158*Θ8 + r159*Θ9
  b17Θ=          r172*Θ2 + r173*Θ3 + r174*Θ4 + r175*Θ5 + r176*Θ6 + r177*Θ7 + r178*Θ8 + r179*Θ9
  b18Θ=          r182*Θ2 + r183*Θ3 + r184*Θ4 + r185*Θ5 + r186*Θ6 + r187*Θ7 + r188*Θ8 + r189*Θ9
  b19Θ=          r192*Θ2 + r193*Θ3 + r194*Θ4 + r195*Θ5 + r196*Θ6 + r197*Θ7 + r198*Θ8 + r199*Θ9
  b20Θ=          r202*Θ2 + r203*Θ3 + r204*Θ4 + r205*Θ5 + r206*Θ6 + r207*Θ7 + r208*Θ8 + r209*Θ9
  b21Θ=          r212*Θ2 + r213*Θ3 + r214*Θ4 + r215*Θ5 + r216*Θ6 + r217*Θ7 + r218*Θ8 + r219*Θ9
  b22Θ=          r222*Θ2 + r223*Θ3 + r224*Θ4 + r225*Θ5 + r226*Θ6 + r227*Θ7 + r228*Θ8 + r229*Θ9
  b23Θ=          r232*Θ2 + r233*Θ3 + r234*Θ4 + r235*Θ5 + r236*Θ6 + r237*Θ7 + r238*Θ8 + r239*Θ9
  b24Θ=          r242*Θ2 + r243*Θ3 + r244*Θ4 + r245*Θ5 + r246*Θ6 + r247*Θ7 + r248*Θ8 + r249*Θ9
  b25Θ=          r252*Θ2 + r253*Θ3 + r254*Θ4 + r255*Θ5 + r256*Θ6 + r257*Θ7 + r258*Θ8 + r259*Θ9
  b26Θ=          r262*Θ2 + r263*Θ3 + r264*Θ4 + r265*Θ5 + r266*Θ6 + r267*Θ7 + r268*Θ8 + r269*Θ9
  y₀ + dt*(k[1]*b1Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ + k[22]*b22Θ + k[23]*b23Θ + k[24]*b24Θ + k[25]*b25Θ + k[26]*b26Θ)
end

"""

"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern9Cache)
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r019,r082,r083,r084,r085,r086,r087,r088,r089,r092,r093,r094,r095,r096,r097,r098,r099,r102,r103,r104,r105,r106,r107,r108,r109,r112,r113,r114,r115,r116,r117,r118,r119,r122,r123,r124,r125,r126,r127,r128,r129,r132,r133,r134,r135,r136,r137,r138,r139,r142,r143,r144,r145,r146,r147,r148,r149,r152,r153,r154,r155,r156,r157,r158,r159,r172,r173,r174,r175,r176,r177,r178,r179,r182,r183,r184,r185,r186,r187,r188,r189,r192,r193,r194,r195,r196,r197,r198,r199,r202,r203,r204,r205,r206,r207,r208,r209,r212,r213,r214,r215,r216,r217,r218,r219,r222,r223,r224,r225,r226,r227,r228,r229,r232,r233,r234,r235,r236,r237,r238,r239,r242,r243,r244,r245,r246,r247,r248,r249,r252,r253,r254,r255,r256,r257,r258,r259,r262,r263,r264,r265,r266,r267,r268,r269 = cache.tab
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  Θ7 = Θ6*Θ
  Θ8 = Θ7*Θ
  Θ9 = Θ8*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6 + r017*Θ7 + r018*Θ8 + r019*Θ9
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6 + r087*Θ7 + r088*Θ8 + r089*Θ9
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6 + r097*Θ7 + r098*Θ8 + r099*Θ9
  b10Θ=          r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6 + r107*Θ7 + r108*Θ8 + r109*Θ9
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6 + r117*Θ7 + r118*Θ8 + r119*Θ9
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6 + r127*Θ7 + r128*Θ8 + r129*Θ9
  b13Θ=          r132*Θ2 + r133*Θ3 + r134*Θ4 + r135*Θ5 + r136*Θ6 + r137*Θ7 + r138*Θ8 + r139*Θ9
  b14Θ=          r142*Θ2 + r143*Θ3 + r144*Θ4 + r145*Θ5 + r146*Θ6 + r147*Θ7 + r148*Θ8 + r149*Θ9
  b15Θ=          r152*Θ2 + r153*Θ3 + r154*Θ4 + r155*Θ5 + r156*Θ6 + r157*Θ7 + r158*Θ8 + r159*Θ9
  b17Θ=          r172*Θ2 + r173*Θ3 + r174*Θ4 + r175*Θ5 + r176*Θ6 + r177*Θ7 + r178*Θ8 + r179*Θ9
  b18Θ=          r182*Θ2 + r183*Θ3 + r184*Θ4 + r185*Θ5 + r186*Θ6 + r187*Θ7 + r188*Θ8 + r189*Θ9
  b19Θ=          r192*Θ2 + r193*Θ3 + r194*Θ4 + r195*Θ5 + r196*Θ6 + r197*Θ7 + r198*Θ8 + r199*Θ9
  b20Θ=          r202*Θ2 + r203*Θ3 + r204*Θ4 + r205*Θ5 + r206*Θ6 + r207*Θ7 + r208*Θ8 + r209*Θ9
  b21Θ=          r212*Θ2 + r213*Θ3 + r214*Θ4 + r215*Θ5 + r216*Θ6 + r217*Θ7 + r218*Θ8 + r219*Θ9
  b22Θ=          r222*Θ2 + r223*Θ3 + r224*Θ4 + r225*Θ5 + r226*Θ6 + r227*Θ7 + r228*Θ8 + r229*Θ9
  b23Θ=          r232*Θ2 + r233*Θ3 + r234*Θ4 + r235*Θ5 + r236*Θ6 + r237*Θ7 + r238*Θ8 + r239*Θ9
  b24Θ=          r242*Θ2 + r243*Θ3 + r244*Θ4 + r245*Θ5 + r246*Θ6 + r247*Θ7 + r248*Θ8 + r249*Θ9
  b25Θ=          r252*Θ2 + r253*Θ3 + r254*Θ4 + r255*Θ5 + r256*Θ6 + r257*Θ7 + r258*Θ8 + r259*Θ9
  b26Θ=          r262*Θ2 + r263*Θ3 + r264*Θ4 + r265*Θ5 + r266*Θ6 + r267*Θ7 + r268*Θ8 + r269*Θ9
  for i in eachindex(out)
    out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ + k[12][i]*b12Θ + k[13][i]*b13Θ + k[14][i]*b14Θ + k[15][i]*b15Θ + k[17][i]*b17Θ + k[18][i]*b18Θ + k[19][i]*b19Θ + k[20][i]*b20Θ + k[21][i]*b21Θ + k[22][i]*b22Θ + k[23][i]*b23Θ + k[24][i]*b24Θ + k[25][i]*b25Θ + k[26][i]*b26Θ)
  end
end

"""

"""
function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP8ConstantCache)
  Θ1 = 1-Θ
  conpar = k[4] + Θ*(k[5] + Θ1*(k[6]+Θ*k[7]))
  y₀ + dt*Θ*(k[1] + Θ1*(k[2] + Θ*(k[3]+Θ1*conpar)))
end

"""

"""
function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::DP8Cache)
  Θ1 = 1-Θ
  for i in eachindex(out)
    out[i] = y₀[i] + dt*Θ*(k[1][i] + Θ1*(k[2][i] + Θ*(k[3][i]+Θ1*(k[4][i] + Θ*(k[5][i] + Θ1*(k[6][i]+Θ*k[7][i]))))))
  end
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Rosenbrock23ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<2 || calcVal
    dT = ForwardDiff.derivative(tf,t)
    J = ForwardDiff.derivative(uf,uprev)
    W = 1-dt*d*J
    k₁ = W\(integrator.fsalfirst + dt*d*dT)
    f₁ = f(t+dt/2,uprev+dt*k₁/2)
    k₂ = W\(f₁-k₁) + k₁
    copyat_or_push!(k,1,k₁)
    copyat_or_push!(k,2,k₂)
  end
  nothing
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Rosenbrock32ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<2 || calcVal
    dT = ForwardDiff.derivative(tf,t)
    J = ForwardDiff.derivative(uf,uprev)
    W = 1-dt*d*J
    k₁ = W\(integrator.fsalfirst + dt*d*dT)
    f₁ = f(t+dt/2,uprev+dt*k₁/2)
    k₂ = W\(f₁-k₁) + k₁
    copyat_or_push!(k,1,k₁)
    copyat_or_push!(k,2,k₂)
  end
  nothing
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Rosenbrock23Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<2 || calcVal
    @unpack k₁,k₂,k₃,du1,du2,f₁,vectmp,vectmp2,vectmp3,fsalfirst,fsallast,dT,J,W,tmp,tmp2,uf,tf,linsolve_tmp = cache
    @unpack c₃₂,d = cache.tab
    uidx = eachindex(uprev)

    #=

    ### Jacobian does not need to be re-evaluated after an event
    ### Since it's unchanged

    # Setup Jacobian Calc
    sizeu  = size(u)
    tf.vf.sizeu = sizeu
    tf.uprev = uprev
    uf.vfr.sizeu = sizeu
    uf.t = t

    ForwardDiff.derivative!(dT,tf,t) # Time derivative of each component
    ForwardDiff.jacobian!(J,uf,vec(du1),vec(uprev))
    =#

    for i in 1:length(uprev), j in 1:length(uprev)
      W[i,j] = I[i,j]-dt*d*J[i,j]
    end

    Wfact = cache.factorization(W)

    for i in uidx
      linsolve_tmp[i] = fsalfirst[i] + dt*d*dT[i]
    end

    @into! vectmp = Wfact\linsolve_tmp
    recursivecopy!(k₁,reshape(vectmp,size(u)...))
    for i in uidx
      tmp2[i]=uprev[i]+dt*k₁[i]/2
    end
    f(t+dt/2,tmp2,f₁)

    for i in uidx
      linsolve_tmp[i] = f₁[i]-k₁[i]
    end

    @into! vectmp2 = Wfact\linsolve_tmp
    for i in uidx
      k₂[i] = tmp[i] + k₁[i]
    end
    copyat_or_push!(k,1,k₁)
    copyat_or_push!(k,2,k₂)
  end
  nothing
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Rosenbrock32Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<2 || calcVal
    @unpack k₁,k₂,k₃,du1,du2,f₁,vectmp,vectmp2,vectmp3,fsalfirst,fsallast,dT,J,W,tmp,tmp2,uf,tf,linsolve_tmp = cache
    @unpack c₃₂,d = cache.tab
    uidx = eachindex(uprev)

    #=

    ### Jacobian does not need to be re-evaluated after an event
    ### Since it's unchanged

    # Setup Jacobian Calc
    sizeu  = size(u)
    tf.vf.sizeu = sizeu
    tf.uprev = uprev
    uf.vfr.sizeu = sizeu
    uf.t = t

    ForwardDiff.derivative!(dT,tf,t) # Time derivative of each component
    ForwardDiff.jacobian!(J,uf,vec(du1),vec(uprev))
    =#

    for i in 1:length(u), j in 1:length(u)
      W[i,j] = I[i,j]-dt*d*J[i,j]
    end

    Wfact = cache.factorization(W)

    for i in uidx
      linsolve_tmp[i] = fsalfirst[i] + dt*d*dT[i]
    end

    @into! vectmp = Wfact\linsolve_tmp
    recursivecopy!(k₁,reshape(vectmp,size(u)...))
    for i in uidx
      tmp2[i]=uprev[i]+dt*k₁[i]/2
    end
    f(t+dt/2,tmp2,f₁)

    for i in uidx
      linsolve_tmp[i] = f₁[i]-k₁[i]
    end

    @into! vectmp2 = Wfact\linsolve_tmp
    for i in uidx
      k₂[i] = tmp[i] + k₁[i]
    end
    copyat_or_push!(k,1,k₁)
    copyat_or_push!(k,2,k₂)
  end
  nothing
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::DP5ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<4 || calcVal
    @unpack a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a62,a63,a64,a65,a71,a73,a74,a75,a76,b1,b3,b4,b5,b6,b7,c1,c2,c3,c4,c5,c6 = cache
    @unpack d1,d3,d4,d5,d6,d7 = cache
    k1 = f(t,uprev)
    k2 = f(t+c1*dt,uprev+dt*(a21*k1))
    k3 = f(t+c2*dt,uprev+dt*(a31*k1+a32*k2))
    k4 = f(t+c3*dt,uprev+dt*(a41*k1+a42*k2+a43*k3))
    k5 = f(t+c4*dt,uprev+dt*(a51*k1+a52*k2+a53*k3+a54*k4))
    k6 = f(t+dt,uprev+dt*(a61*k1+a62*k2+a63*k3+a64*k4+a65*k5))
    update = a71*k1+a73*k3+a74*k4+a75*k5+a76*k6
    k7 = f(t+dt,uprev+dt*update)
    copyat_or_push!(k,1,update)
    bspl = k1 - update
    copyat_or_push!(k,2,bspl)
    copyat_or_push!(k,3,update - k7 - bspl)
    copyat_or_push!(k,4,d1*k1+d3*k3+d4*k4+d5*k5+d6*k6+d7*k7)
  end
  nothing
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::DP5Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<4 || calcVal
    @unpack a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a62,a63,a64,a65,a71,a73,a74,a75,a76,b1,b3,b4,b5,b6,b7,c1,c2,c3,c4,c5,c6 = cache.tab
    @unpack d1,d3,d4,d5,d6,d7 = cache.tab
    @unpack k1,k2,k3,k4,k5,k6,k7,dense_tmp3,dense_tmp4,update,bspl,utilde,tmp,atmp = cache
    rtmp = similar(k1)
    f(t,uprev,k1)
    f(t+c1*dt,uprev+dt*(a21*k1),k2)
    f(t+c2*dt,uprev+dt*(a31*k1+a32*k2),k3)
    f(t+c3*dt,uprev+dt*(a41*k1+a42*k2+a43*k3),k4)
    f(t+c4*dt,uprev+dt*(a51*k1+a52*k2+a53*k3+a54*k4),k5)
    f(t+dt,uprev+dt*(a61*k1+a62*k2+a63*k3+a64*k4+a65*k5),k6)
    rtmp = a71*k1+a73*k3+a74*k4+a75*k5+a76*k6
    f(t+dt,uprev+dt*rtmp,k7)
    copyat_or_push!(k,1,rtmp)
    bspl = k1 - rtmp
    copyat_or_push!(k,2,bspl)
    copyat_or_push!(k,3,rtmp - k7 - bspl)
    copyat_or_push!(k,4,d1*k1+d3*k3+d4*k4+d5*k5+d6*k6+d7*k7)
  end
  nothing
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::DP5ThreadedCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<4 || calcVal
    @unpack a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a62,a63,a64,a65,a71,a73,a74,a75,a76,b1,b3,b4,b5,b6,b7,c1,c2,c3,c4,c5,c6 = cache.tab
    @unpack d1,d3,d4,d5,d6,d7 = cache.tab
    @unpack k1,k2,k3,k4,k5,k6,k7,dense_tmp3,dense_tmp4,update,bspl,utilde,tmp,atmp = cache
    rtmp = similar(k1)
    f(t,uprev,k1)
    f(t+c1*dt,uprev+dt*(a21*k1),k2)
    f(t+c2*dt,uprev+dt*(a31*k1+a32*k2),k3)
    f(t+c3*dt,uprev+dt*(a41*k1+a42*k2+a43*k3),k4)
    f(t+c4*dt,uprev+dt*(a51*k1+a52*k2+a53*k3+a54*k4),k5)
    f(t+dt,uprev+dt*(a61*k1+a62*k2+a63*k3+a64*k4+a65*k5),k6)
    rtmp = a71*k1+a73*k3+a74*k4+a75*k5+a76*k6
    f(t+dt,uprev+dt*rtmp,k7)
    copyat_or_push!(k,1,rtmp)
    bspl = k1 - rtmp
    copyat_or_push!(k,2,bspl)
    copyat_or_push!(k,3,rtmp - k7 - bspl)
    copyat_or_push!(k,4,d1*k1+d3*k3+d4*k4+d5*k5+d6*k6+d7*k7)
  end
  nothing
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Tsit5ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<7 || calcVal
    @unpack c1,c2,c3,c4,c5,c6,a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a62,a63,a64,a65,a71,a72,a73,a74,a75,a76,b1,b2,b3,b4,b5,b6,b7 = cache
    copyat_or_push!(k,1,f(t,uprev))
    copyat_or_push!(k,2,f(t+c1*dt,uprev+dt*(a21*k[1])))
    copyat_or_push!(k,3,f(t+c2*dt,uprev+dt*(a31*k[1]+a32*k[2])))
    copyat_or_push!(k,4,f(t+c3*dt,uprev+dt*(a41*k[1]+a42*k[2]+a43*k[3])))
    copyat_or_push!(k,5,f(t+c4*dt,uprev+dt*(a51*k[1]+a52*k[2]+a53*k[3]+a54*k[4])))
    copyat_or_push!(k,6,f(t+dt,uprev+dt*(a61*k[1]+a62*k[2]+a63*k[3]+a64*k[4]+a65*k[5])))
    utmp = uprev+dt*(a71*k[1]+a72*k[2]+a73*k[3]+a74*k[4]+a75*k[5]+a76*k[6])
    copyat_or_push!(k,7,f(t+dt,utmp))
  end
  nothing
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Tsit5Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<7 || calcVal
    @unpack c1,c2,c3,c4,c5,c6,a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a62,a63,a64,a65,a71,a72,a73,a74,a75,a76,b1,b2,b3,b4,b5,b6,b7 = cache.tab
    rtmp = similar(cache.k1)
    f(t,uprev,rtmp); copyat_or_push!(k,1,rtmp)
    f(t+c1*dt,uprev+dt*(a21*k[1]),rtmp); copyat_or_push!(k,2,rtmp)
    f(t+c2*dt,uprev+dt*(a31*k[1]+a32*k[2]),rtmp); copyat_or_push!(k,3,rtmp)
    f(t+c3*dt,uprev+dt*(a41*k[1]+a42*k[2]+a43*k[3]),rtmp); copyat_or_push!(k,4,rtmp)
    f(t+c4*dt,uprev+dt*(a51*k[1]+a52*k[2]+a53*k[3]+a54*k[4]),rtmp); copyat_or_push!(k,5,rtmp)
    f(t+dt,uprev+dt*(a61*k[1]+a62*k[2]+a63*k[3]+a64*k[4]+a65*k[5]),rtmp); copyat_or_push!(k,6,rtmp)
    utmp = uprev+dt*(a71*k[1]+a72*k[2]+a73*k[3]+a74*k[4]+a75*k[5]+a76*k[6]);
    f(t+dt,utmp,rtmp); copyat_or_push!(k,7,rtmp)
  end
  nothing
end

"""
An Efficient Runge-Kutta (4,5) Pair by P.Bogacki and L.F.Shampine
 Computers and Mathematics with Applications, Vol. 32, No. 6, 1996, pages 15 to 28

Called to add the extra k9, k10, k11 steps for the Order 5 interpolation when needed
"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::BS5ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 8 || calcVal) || ((calcVal2 && length(k)< 11) || calcVal3)
  end

  if length(k) < 8 || calcVal
    @unpack c1,c2,c3,c4,c5,a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a62,a63,a64,a65,a71,a72,a73,a74,a75,a76,a81,a83,a84,a85,a86,a87,bhat1,bhat3,bhat4,bhat5,bhat6,btilde1,btilde2,btilde3,btilde4,btilde5,btilde6,btilde7,btilde8 = cache
    copyat_or_push!(k,1,f(t,uprev))
    copyat_or_push!(k,2,f(t+c1*dt,uprev+dt*a21*k[1]))
    copyat_or_push!(k,3,f(t+c2*dt,uprev+dt*(a31*k[1]+a32*k[2])))
    copyat_or_push!(k,4,f(t+c3*dt,uprev+dt*(a41*k[1]+a42*k[2]+a43*k[3])))
    copyat_or_push!(k,5,f(t+c4*dt,uprev+dt*(a51*k[1]+a52*k[2]+a53*k[3]+a54*k[4])))
    copyat_or_push!(k,6,f(t+c5*dt,uprev+dt*(a61*k[1]+a62*k[2]+a63*k[3]+a64*k[4]+a65*k[5])))
    copyat_or_push!(k,7,f(t+dt,uprev+dt*(a71*k[1]+a72*k[2]+a73*k[3]+a74*k[4]+a75*k[5]+a76*k[6])))
    copyat_or_push!(k,8,f(t+dt,uprev+dt*(a81*k[1]+a83*k[3]+a84*k[4]+a85*k[5]+a86*k[6]+a87*k[7])))
  end
  if (calcVal2 && length(k)< 11) || calcVal3 # Have not added the extra stages yet
    @unpack c6,c7,c8,a91,a92,a93,a94,a95,a96,a97,a98,a101,a102,a103,a104,a105,a106,a107,a108,a109,a111,a112,a113,a114,a115,a116,a117,a118,a119,a1110 = cache
    copyat_or_push!(k,9,f(t+c6*dt,uprev+dt*(a91*k[1]+a92*k[2]+a93*k[3]+a94*k[4]+a95*k[5]+a96*k[6]+a97*k[7]+a98*k[8])))
    copyat_or_push!(k,10,f(t+c7*dt,uprev+dt*(a101*k[1]+a102*k[2]+a103*k[3]+a104*k[4]+a105*k[5]+a106*k[6]+a107*k[7]+a108*k[8]+a109*k[9])))
    copyat_or_push!(k,11,f(t+c8*dt,uprev+dt*(a111*k[1]+a112*k[2]+a113*k[3]+a114*k[4]+a115*k[5]+a116*k[6]+a117*k[7]+a118*k[8]+a119*k[9]+a1110*k[10])))
  end
  nothing
end

"""
An Efficient Runge-Kutta (4,5) Pair by P.Bogacki and L.F.Shampine
 Computers and Mathematics with Applications, Vol. 32, No. 6, 1996, pages 15 to 28

Called to add the extra k9, k10, k11 steps for the Order 5 interpolation when needed
"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::BS5Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 8 || calcVal) || ((calcVal2 && length(k)< 11) || calcVal3)
    rtmp = similar(cache.k1)
  end

  if length(k) < 8 || calcVal
    @unpack c1,c2,c3,c4,c5,a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a62,a63,a64,a65,a71,a72,a73,a74,a75,a76,a81,a83,a84,a85,a86,a87,bhat1,bhat3,bhat4,bhat5,bhat6,btilde1,btilde2,btilde3,btilde4,btilde5,btilde6,btilde7,btilde8 = cache.tab
    f(t,uprev,rtmp); copyat_or_push!(k,1,rtmp)
    f(t+c1*dt,uprev+dt*a21*k[1],rtmp); copyat_or_push!(k,2,rtmp)
    f(t+c2*dt,uprev+dt*(a31*k[1]+a32*k[2]),rtmp); copyat_or_push!(k,3,rtmp)
    f(t+c3*dt,uprev+dt*(a41*k[1]+a42*k[2]+a43*k[3]),rtmp); copyat_or_push!(k,4,rtmp)
    f(t+c4*dt,uprev+dt*(a51*k[1]+a52*k[2]+a53*k[3]+a54*k[4]),rtmp); copyat_or_push!(k,5,rtmp)
    f(t+c5*dt,uprev+dt*(a61*k[1]+a62*k[2]+a63*k[3]+a64*k[4]+a65*k[5]),rtmp); copyat_or_push!(k,6,rtmp)
    f(t+dt,uprev+dt*(a71*k[1]+a72*k[2]+a73*k[3]+a74*k[4]+a75*k[5]+a76*k[6]),rtmp); copyat_or_push!(k,7,rtmp)
    f(t+dt,uprev+dt*(a81*k[1]+a83*k[3]+a84*k[4]+a85*k[5]+a86*k[6]+a87*k[7]),rtmp); copyat_or_push!(k,8,rtmp)
  end
  if (calcVal2 && length(k)< 11) || calcVal3 # Have not added the extra stages yet
    @unpack c6,c7,c8,a91,a92,a93,a94,a95,a96,a97,a98,a101,a102,a103,a104,a105,a106,a107,a108,a109,a111,a112,a113,a114,a115,a116,a117,a118,a119,a1110 = cache.tab
    f(t+c6*dt,uprev+dt*(a91*k[1]+a92*k[2]+a93*k[3]+a94*k[4]+a95*k[5]+a96*k[6]+a97*k[7]+a98*k[8]),rtmp); copyat_or_push!(k,9,rtmp)
    f(t+c7*dt,uprev+dt*(a101*k[1]+a102*k[2]+a103*k[3]+a104*k[4]+a105*k[5]+a106*k[6]+a107*k[7]+a108*k[8]+a109*k[9]),rtmp); copyat_or_push!(k,10,rtmp)
    f(t+c8*dt,uprev+dt*(a111*k[1]+a112*k[2]+a113*k[3]+a114*k[4]+a115*k[5]+a116*k[6]+a117*k[7]+a118*k[8]+a119*k[9]+a1110*k[10]),rtmp); copyat_or_push!(k,11,rtmp)
  end
  nothing
end


"""

"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Vern6ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 9 || calcVal) || ((calcVal2 && length(k)< 12) || calcVal3)
  end

  if length(k) < 9 || calcVal
    @unpack c1,c2,c3,c4,c5,c6,a21,a31,a32,a41,a43,a51,a53,a54,a61,a63,a64,a65,a71,a73,a74,a75,a76,a81,a83,a84,a85,a86,a87,a91,a94,a95,a96,a97,a98,b1,b4,b5,b6,b7,b8,b9= cache
    copyat_or_push!(k,1,f(t,uprev))
    copyat_or_push!(k,2,f(t+c1*dt,uprev+dt*(a21*k[1])))
    copyat_or_push!(k,3,f(t+c2*dt,uprev+dt*(a31*k[1]+a32*k[2])))
    copyat_or_push!(k,4,f(t+c3*dt,uprev+dt*(a41*k[1]       +a43*k[3])))
    copyat_or_push!(k,5,f(t+c4*dt,uprev+dt*(a51*k[1]       +a53*k[3]+a54*k[4])))
    copyat_or_push!(k,6,f(t+c5*dt,uprev+dt*(a61*k[1]       +a63*k[3]+a64*k[4]+a65*k[5])))
    copyat_or_push!(k,7,f(t+c6*dt,uprev+dt*(a71*k[1]       +a73*k[3]+a74*k[4]+a75*k[5]+a76*k[6])))
    copyat_or_push!(k,8,f(t+dt,uprev+dt*(a81*k[1]       +a83*k[3]+a84*k[4]+a85*k[5]+a86*k[6]+a87*k[7])))
    copyat_or_push!(k,9,f(t+dt,uprev+dt*(a91*k[1]+a94*k[4]+a95*k[5]+a96*k[6]+a97*k[7]+a98*k[8])))
  end
  if (calcVal2 && length(k)< 12) || calcVal3 # Have not added the extra stages yet
    @unpack c10,a1001,a1004,a1005,a1006,a1007,a1008,a1009,c11,a1101,a1102,a1103,a1104,a1105,a1106,a1107,a1108,a1109,a1110,c12,a1201,a1202,a1203,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211 = cache
    copyat_or_push!(k,10,f(t+c10*dt,uprev+dt*(a1001*k[1]+a1004*k[4]+a1005*k[5]+a1006*k[6]+a1007*k[7]+a1008*k[8]+a1009*k[9])))
    copyat_or_push!(k,11,f(t+c11*dt,uprev+dt*(a1101*k[1]+a1102*k[2]+a1103*k[3]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]+a1110*k[10])))
    copyat_or_push!(k,12,f(t+c12*dt,uprev+dt*(a1201*k[1]+a1202*k[2]+a1203*k[3]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1210*k[10]+a1211*k[11])))
  end
  nothing
end

"""

"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Vern6Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 9 || calcVal) || ((calcVal2 && length(k)< 12) || calcVal3)
    rtmp = similar(cache.k1)
  end

  if length(k) < 9 || calcVal
    @unpack c1,c2,c3,c4,c5,c6,a21,a31,a32,a41,a43,a51,a53,a54,a61,a63,a64,a65,a71,a73,a74,a75,a76,a81,a83,a84,a85,a86,a87,a91,a94,a95,a96,a97,a98,b1,b4,b5,b6,b7,b8,b9= cache.tab
    f(t,uprev,rtmp); copyat_or_push!(k,1,rtmp)
    f(t+c1*dt,uprev+dt*(a21*k[1]),rtmp); copyat_or_push!(k,2,rtmp)
    f(t+c2*dt,uprev+dt*(a31*k[1]+a32*k[2]),rtmp); copyat_or_push!(k,3,rtmp)
    f(t+c3*dt,uprev+dt*(a41*k[1]       +a43*k[3]),rtmp); copyat_or_push!(k,4,rtmp)
    f(t+c4*dt,uprev+dt*(a51*k[1]       +a53*k[3]+a54*k[4]),rtmp); copyat_or_push!(k,5,rtmp)
    f(t+c5*dt,uprev+dt*(a61*k[1]       +a63*k[3]+a64*k[4]+a65*k[5]),rtmp); copyat_or_push!(k,6,rtmp)
    f(t+c6*dt,uprev+dt*(a71*k[1]       +a73*k[3]+a74*k[4]+a75*k[5]+a76*k[6]),rtmp); copyat_or_push!(k,7,rtmp)
    f(t+dt,uprev+dt*(a81*k[1]       +a83*k[3]+a84*k[4]+a85*k[5]+a86*k[6]+a87*k[7]),rtmp); copyat_or_push!(k,8,rtmp)
    f(t+dt,uprev+dt*(a91*k[1]              +a94*k[4]+a95*k[5]+a96*k[6]+a97*k[7]+a98*k[8]),rtmp); copyat_or_push!(k,9,rtmp)
  end
  if (calcVal2 && length(k)< 12) || calcVal3 # Have not added the extra stages yet
    @unpack c10,a1001,a1004,a1005,a1006,a1007,a1008,a1009,c11,a1101,a1102,a1103,a1104,a1105,a1106,a1107,a1108,a1109,a1110,c12,a1201,a1202,a1203,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211 = cache.tab
    f(t+c10*dt,uprev+dt*(a1001*k[1]+a1004*k[4]+a1005*k[5]+a1006*k[6]+a1007*k[7]+a1008*k[8]+a1009*k[9]),rtmp); copyat_or_push!(k,10,rtmp)
    f(t+c11*dt,uprev+dt*(a1101*k[1]+a1102*k[2]+a1103*k[3]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]+a1110*k[10]),rtmp); copyat_or_push!(k,11,rtmp)
    f(t+c12*dt,uprev+dt*(a1201*k[1]+a1202*k[2]+a1203*k[3]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1210*k[10]+a1211*k[11]),rtmp); copyat_or_push!(k,12,rtmp)
  end
  nothing
end

"""

"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Vern7ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 10 || calcVal) || ((calcVal2 && length(k)< 16) || calcVal3)
  end

  if length(k) < 10 || calcVal
    @unpack c2,c3,c4,c5,c6,c7,c8,a021,a031,a032,a041,a043,a051,a053,a054,a061,a063,a064,a065,a071,a073,a074,a075,a076,a081,a083,a084,a085,a086,a087,a091,a093,a094,a095,a096,a097,a098,a101,a103,a104,a105,a106,a107,b1,b4,b5,b6,b7,b8,b9,bhat1,bhat4,bhat5,bhat6,bhat7,bhat10= cache
    copyat_or_push!(k,1,f(t,uprev))
    copyat_or_push!(k,2,f(t+c2*dt,uprev+dt*(a021*k[1])))
    copyat_or_push!(k,3,f(t+c3*dt,uprev+dt*(a031*k[1]+a032*k[2])))
    copyat_or_push!(k,4,f(t+c4*dt,uprev+dt*(a041*k[1]       +a043*k[3])))
    copyat_or_push!(k,5,f(t+c5*dt,uprev+dt*(a051*k[1]       +a053*k[3]+a054*k[4])))
    copyat_or_push!(k,6,f(t+c6*dt,uprev+dt*(a061*k[1]       +a063*k[3]+a064*k[4]+a065*k[5])))
    copyat_or_push!(k,7,f(t+c7*dt,uprev+dt*(a071*k[1]       +a073*k[3]+a074*k[4]+a075*k[5]+a076*k[6])))
    copyat_or_push!(k,8,f(t+c8*dt,uprev+dt*(a081*k[1]       +a083*k[3]+a084*k[4]+a085*k[5]+a086*k[6]+a087*k[7])))
    copyat_or_push!(k,9,f(t+dt,uprev+dt*(a091*k[1]          +a093*k[3]+a094*k[4]+a095*k[5]+a096*k[6]+a097*k[7]+a098*k[8])))
    copyat_or_push!(k,10,f(t+dt,uprev+dt*(a101*k[1]          +a103*k[3]+a104*k[4]+a105*k[5]+a106*k[6]+a107*k[7])))
  end
  if (calcVal2 && length(k)< 16) || calcVal3 # Have not added the extra stages yet
    @unpack c11,a1101,a1104,a1105,a1106,a1107,a1108,a1109,c12,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1211,c13,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1311,a1312,c14,a1401,a1404,a1405,a1406,a1407,a1408,a1409,a1411,a1412,a1413,c15,a1501,a1504,a1505,a1506,a1507,a1508,a1509,a1511,a1512,a1513,c16,a1601,a1604,a1605,a1606,a1607,a1608,a1609,a1611,a1612,a1613 = cache
    copyat_or_push!(k,11,f(t+c11*dt,uprev+dt*(a1101*k[1]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9])))
    copyat_or_push!(k,12,f(t+c12*dt,uprev+dt*(a1201*k[1]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1211*k[11])))
    copyat_or_push!(k,13,f(t+c13*dt,uprev+dt*(a1301*k[1]+a1304*k[4]+a1305*k[5]+a1306*k[6]+a1307*k[7]+a1308*k[8]+a1309*k[9]+a1311*k[11]+a1312*k[12])))
    copyat_or_push!(k,14,f(t+c14*dt,uprev+dt*(a1401*k[1]+a1404*k[4]+a1405*k[5]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1411*k[11]+a1412*k[12]+a1413*k[13])))
    copyat_or_push!(k,15,f(t+c15*dt,uprev+dt*(a1501*k[1]+a1504*k[4]+a1505*k[5]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1511*k[11]+a1512*k[12]+a1513*k[13])))
    copyat_or_push!(k,16,f(t+c16*dt,uprev+dt*(a1601*k[1]+a1604*k[4]+a1605*k[5]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1611*k[11]+a1612*k[12]+a1613*k[13])))
  end
  nothing
end

"""

"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Vern7Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 10 || calcVal) || ((calcVal2 && length(k)< 16) || calcVal3)
    rtmp = similar(cache.k1)
  end

  if length(k) < 10 || calcVal
    @unpack c2,c3,c4,c5,c6,c7,c8,a021,a031,a032,a041,a043,a051,a053,a054,a061,a063,a064,a065,a071,a073,a074,a075,a076,a081,a083,a084,a085,a086,a087,a091,a093,a094,a095,a096,a097,a098,a101,a103,a104,a105,a106,a107,b1,b4,b5,b6,b7,b8,b9,bhat1,bhat4,bhat5,bhat6,bhat7,bhat10= cache.tab
    f(t,uprev,rtmp); copyat_or_push!(k,1,rtmp)
    f(t+c2*dt,uprev+dt*(a021*k[1]),rtmp); copyat_or_push!(k,2,rtmp)
    f(t+c3*dt,uprev+dt*(a031*k[1]+a032*k[2]),rtmp); copyat_or_push!(k,3,rtmp)
    f(t+c4*dt,uprev+dt*(a041*k[1]       +a043*k[3]),rtmp); copyat_or_push!(k,4,rtmp)
    f(t+c5*dt,uprev+dt*(a051*k[1]       +a053*k[3]+a054*k[4]),rtmp); copyat_or_push!(k,5,rtmp)
    f(t+c6*dt,uprev+dt*(a061*k[1]       +a063*k[3]+a064*k[4]+a065*k[5]),rtmp); copyat_or_push!(k,6,rtmp)
    f(t+c7*dt,uprev+dt*(a071*k[1]       +a073*k[3]+a074*k[4]+a075*k[5]+a076*k[6]),rtmp); copyat_or_push!(k,7,rtmp)
    f(t+c8*dt,uprev+dt*(a081*k[1]       +a083*k[3]+a084*k[4]+a085*k[5]+a086*k[6]+a087*k[7]),rtmp); copyat_or_push!(k,8,rtmp)
    f(t+dt,uprev+dt*(a091*k[1]          +a093*k[3]+a094*k[4]+a095*k[5]+a096*k[6]+a097*k[7]+a098*k[8]),rtmp); copyat_or_push!(k,9,rtmp)
    f(t+dt,uprev+dt*(a101*k[1]          +a103*k[3]+a104*k[4]+a105*k[5]+a106*k[6]+a107*k[7]),rtmp); copyat_or_push!(k,10,rtmp)
  end
  if (calcVal2 && length(k)< 16) || calcVal3 # Have not added the extra stages yet
    @unpack c11,a1101,a1104,a1105,a1106,a1107,a1108,a1109,c12,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1211,c13,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1311,a1312,c14,a1401,a1404,a1405,a1406,a1407,a1408,a1409,a1411,a1412,a1413,c15,a1501,a1504,a1505,a1506,a1507,a1508,a1509,a1511,a1512,a1513,c16,a1601,a1604,a1605,a1606,a1607,a1608,a1609,a1611,a1612,a1613 = cache.tab
    f(t+c11*dt,uprev+dt*(a1101*k[1]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]),rtmp); copyat_or_push!(k,11,rtmp)
    f(t+c12*dt,uprev+dt*(a1201*k[1]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1211*k[11]),rtmp); copyat_or_push!(k,12,rtmp)
    f(t+c13*dt,uprev+dt*(a1301*k[1]+a1304*k[4]+a1305*k[5]+a1306*k[6]+a1307*k[7]+a1308*k[8]+a1309*k[9]+a1311*k[11]+a1312*k[12]),rtmp); copyat_or_push!(k,13,rtmp)
    f(t+c14*dt,uprev+dt*(a1401*k[1]+a1404*k[4]+a1405*k[5]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1411*k[11]+a1412*k[12]+a1413*k[13]),rtmp); copyat_or_push!(k,14,rtmp)
    f(t+c15*dt,uprev+dt*(a1501*k[1]+a1504*k[4]+a1505*k[5]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1511*k[11]+a1512*k[12]+a1513*k[13]),rtmp); copyat_or_push!(k,15,rtmp)
    f(t+c16*dt,uprev+dt*(a1601*k[1]+a1604*k[4]+a1605*k[5]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1611*k[11]+a1612*k[12]+a1613*k[13]),rtmp); copyat_or_push!(k,16,rtmp)
  end
  nothing
end

"""

"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Vern8ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 13 || calcVal) || ((calcVal2 && length(k)< 21) || calcVal3)
  end
  if length(k) <13 || calcVal
    @unpack c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0804,a0805,a0806,a0807,a0901,a0904,a0905,a0906,a0907,a0908,a1001,a1004,a1005,a1006,a1007,a1008,a1009,a1101,a1104,a1105,a1106,a1107,a1108,a1109,a1110,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1310,b1,b6,b7,b8,b9,b10,b11,b12,bhat1,bhat6,bhat7,bhat8,bhat9,bhat10,bhat13 = cache
    copyat_or_push!(k,1,f(t,uprev))
    copyat_or_push!(k,2,f(t+c2*dt ,uprev+dt*(a0201*k[1])))
    copyat_or_push!(k,3,f(t+c3*dt ,uprev+dt*(a0301*k[1]+a0302*k[2])))
    copyat_or_push!(k,4,f(t+c4*dt ,uprev+dt*(a0401*k[1]       +a0403*k[3])))
    copyat_or_push!(k,5,f(t+c5*dt ,uprev+dt*(a0501*k[1]       +a0503*k[3]+a0504*k[4])))
    copyat_or_push!(k,6,f(t+c6*dt ,uprev+dt*(a0601*k[1]                +a0604*k[4]+a0605*k[5])))
    copyat_or_push!(k,7,f(t+c7*dt ,uprev+dt*(a0701*k[1]                +a0704*k[4]+a0705*k[5]+a0706*k[6])))
    copyat_or_push!(k,8,f(t+c8*dt ,uprev+dt*(a0801*k[1]                +a0804*k[4]+a0805*k[5]+a0806*k[6]+a0807*k[7])))
    copyat_or_push!(k,9,f(t+c9*dt ,uprev+dt*(a0901*k[1]                +a0904*k[4]+a0905*k[5]+a0906*k[6]+a0907*k[7]+a0908*k[8])))
    copyat_or_push!(k,10,f(t+c10*dt,uprev+dt*(a1001*k[1]                +a1004*k[4]+a1005*k[5]+a1006*k[6]+a1007*k[7]+a1008*k[8]+a1009*k[9])))
    copyat_or_push!(k,11,f(t+c11*dt,uprev+dt*(a1101*k[1]                +a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]+a1110*k[10])))
    copyat_or_push!(k,12,f(t+    dt,uprev+dt*(a1201*k[1]                +a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1210*k[10]+a1211*k[11])))
    copyat_or_push!(k,13,f(t+    dt,uprev+dt*(a1301*k[1]                +a1304*k[4]+a1305*k[5]+a1306*k[6]+a1307*k[7]+a1308*k[8]+a1309*k[9]+a1310*k[10])))
  end
  if (calcVal2 && length(k)< 21) || calcVal3 # Have not added the extra stages yet
    @unpack c14,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,c15,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1514,c16,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1614,a1615,c17,a1701,a1706,a1707,a1708,a1709,a1710,a1711,a1712,a1714,a1715,a1716,c18,a1801,a1806,a1807,a1808,a1809,a1810,a1811,a1812,a1814,a1815,a1816,a1817,c19,a1901,a1906,a1907,a1908,a1909,a1910,a1911,a1912,a1914,a1915,a1916,a1917,c20,a2001,a2006,a2007,a2008,a2009,a2010,a2011,a2012,a2014,a2015,a2016,a2017,c21,a2101,a2106,a2107,a2108,a2109,a2110,a2111,a2112,a2114,a2115,a2116,a2117 = cache
    copyat_or_push!(k,14,f(t+c14*dt,uprev+dt*(a1401*k[1]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1410*k[10]+a1411*k[11]+a1412*k[12])))
    copyat_or_push!(k,15,f(t+c15*dt,uprev+dt*(a1501*k[1]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1510*k[10]+a1511*k[11]+a1512*k[12]+a1514*k[14])))
    copyat_or_push!(k,16,f(t+c16*dt,uprev+dt*(a1601*k[1]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1610*k[10]+a1611*k[11]+a1612*k[12]+a1614*k[14]+a1615*k[15])))
    copyat_or_push!(k,17,f(t+c17*dt,uprev+dt*(a1701*k[1]+a1706*k[6]+a1707*k[7]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1714*k[14]+a1715*k[15]+a1716*k[16])))
    copyat_or_push!(k,18,f(t+c18*dt,uprev+dt*(a1801*k[1]+a1806*k[6]+a1807*k[7]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1814*k[14]+a1815*k[15]+a1816*k[16]+a1817*k[17])))
    copyat_or_push!(k,19,f(t+c19*dt,uprev+dt*(a1901*k[1]+a1906*k[6]+a1907*k[7]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1914*k[14]+a1915*k[15]+a1916*k[16]+a1917*k[17])))
    copyat_or_push!(k,20,f(t+c20*dt,uprev+dt*(a2001*k[1]+a2006*k[6]+a2007*k[7]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2014*k[14]+a2015*k[15]+a2016*k[16]+a2017*k[17])))
    copyat_or_push!(k,21,f(t+c21*dt,uprev+dt*(a2101*k[1]+a2106*k[6]+a2107*k[7]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2114*k[14]+a2115*k[15]+a2116*k[16]+a2117*k[17])))
  end
  nothing
end

"""

"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Vern8Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 13 || calcVal) || ((calcVal2 && length(k)< 21) || calcVal3)
    rtmp = similar(cache.k1)
  end
  if length(k) <13 || calcVal
    @unpack c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0804,a0805,a0806,a0807,a0901,a0904,a0905,a0906,a0907,a0908,a1001,a1004,a1005,a1006,a1007,a1008,a1009,a1101,a1104,a1105,a1106,a1107,a1108,a1109,a1110,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1310,b1,b6,b7,b8,b9,b10,b11,b12,bhat1,bhat6,bhat7,bhat8,bhat9,bhat10,bhat13= cache.tab
    f(t,uprev,rtmp); copyat_or_push!(k,1,rtmp)
    f(t+c2*dt ,uprev+dt*(a0201*k[1]),rtmp); copyat_or_push!(k,2,rtmp)
    f(t+c3*dt ,uprev+dt*(a0301*k[1]+a0302*k[2]),rtmp); copyat_or_push!(k,3,rtmp)
    f(t+c4*dt ,uprev+dt*(a0401*k[1]       +a0403*k[3]),rtmp); copyat_or_push!(k,4,rtmp)
    f(t+c5*dt ,uprev+dt*(a0501*k[1]       +a0503*k[3]+a0504*k[4]),rtmp); copyat_or_push!(k,5,rtmp)
    f(t+c6*dt ,uprev+dt*(a0601*k[1]                +a0604*k[4]+a0605*k[5]),rtmp); copyat_or_push!(k,6,rtmp)
    f(t+c7*dt ,uprev+dt*(a0701*k[1]                +a0704*k[4]+a0705*k[5]+a0706*k[6]),rtmp); copyat_or_push!(k,7,rtmp)
    f(t+c8*dt ,uprev+dt*(a0801*k[1]                +a0804*k[4]+a0805*k[5]+a0806*k[6]+a0807*k[7]),rtmp); copyat_or_push!(k,8,rtmp)
    f(t+c9*dt ,uprev+dt*(a0901*k[1]                +a0904*k[4]+a0905*k[5]+a0906*k[6]+a0907*k[7]+a0908*k[8]),rtmp); copyat_or_push!(k,9,rtmp)
    f(t+c10*dt,uprev+dt*(a1001*k[1]                +a1004*k[4]+a1005*k[5]+a1006*k[6]+a1007*k[7]+a1008*k[8]+a1009*k[9]),rtmp); copyat_or_push!(k,10,rtmp)
    f(t+c11*dt,uprev+dt*(a1101*k[1]                +a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]+a1110*k[10]),rtmp); copyat_or_push!(k,11,rtmp)
    f(t+    dt,uprev+dt*(a1201*k[1]                +a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1210*k[10]+a1211*k[11]),rtmp); copyat_or_push!(k,12,rtmp)
    f(t+    dt,uprev+dt*(a1301*k[1]                +a1304*k[4]+a1305*k[5]+a1306*k[6]+a1307*k[7]+a1308*k[8]+a1309*k[9]+a1310*k[10]),rtmp); copyat_or_push!(k,13,rtmp)
  end
  if (calcVal2 && length(k)< 21) || calcVal3 # Have not added the extra stages yet
    @unpack c14,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,c15,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1514,c16,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1614,a1615,c17,a1701,a1706,a1707,a1708,a1709,a1710,a1711,a1712,a1714,a1715,a1716,c18,a1801,a1806,a1807,a1808,a1809,a1810,a1811,a1812,a1814,a1815,a1816,a1817,c19,a1901,a1906,a1907,a1908,a1909,a1910,a1911,a1912,a1914,a1915,a1916,a1917,c20,a2001,a2006,a2007,a2008,a2009,a2010,a2011,a2012,a2014,a2015,a2016,a2017,c21,a2101,a2106,a2107,a2108,a2109,a2110,a2111,a2112,a2114,a2115,a2116,a2117 = cache.tab
    f(t+c14*dt,uprev+dt*(a1401*k[1]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1410*k[10]+a1411*k[11]+a1412*k[12]),rtmp); copyat_or_push!(k,14,rtmp)
    f(t+c15*dt,uprev+dt*(a1501*k[1]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1510*k[10]+a1511*k[11]+a1512*k[12]+a1514*k[14]),rtmp); copyat_or_push!(k,15,rtmp)
    f(t+c16*dt,uprev+dt*(a1601*k[1]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1610*k[10]+a1611*k[11]+a1612*k[12]+a1614*k[14]+a1615*k[15]),rtmp); copyat_or_push!(k,16,rtmp)
    f(t+c17*dt,uprev+dt*(a1701*k[1]+a1706*k[6]+a1707*k[7]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1714*k[14]+a1715*k[15]+a1716*k[16]),rtmp); copyat_or_push!(k,17,rtmp)
    f(t+c18*dt,uprev+dt*(a1801*k[1]+a1806*k[6]+a1807*k[7]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1814*k[14]+a1815*k[15]+a1816*k[16]+a1817*k[17]),rtmp); copyat_or_push!(k,18,rtmp)
    f(t+c19*dt,uprev+dt*(a1901*k[1]+a1906*k[6]+a1907*k[7]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1914*k[14]+a1915*k[15]+a1916*k[16]+a1917*k[17]),rtmp); copyat_or_push!(k,19,rtmp)
    f(t+c20*dt,uprev+dt*(a2001*k[1]+a2006*k[6]+a2007*k[7]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2014*k[14]+a2015*k[15]+a2016*k[16]+a2017*k[17]),rtmp); copyat_or_push!(k,20,rtmp)
    f(t+c21*dt,uprev+dt*(a2101*k[1]+a2106*k[6]+a2107*k[7]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2114*k[14]+a2115*k[15]+a2116*k[16]+a2117*k[17]),rtmp); copyat_or_push!(k,21,rtmp)
  end
  nothing
end

"""

"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Vern9ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 16 || calcVal) || ((calcVal2 && length(k)< 26) || calcVal3)
  end
  if length(k) < 16 || calcVal
    @unpack c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0806,a0807,a0901,a0906,a0907,a0908,a1001,a1006,a1007,a1008,a1009,a1101,a1106,a1107,a1108,a1109,a1110,a1201,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1306,a1307,a1308,a1309,a1310,a1311,a1312,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,a1413,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1513,a1514,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1613,b1,b8,b9,b10,b11,b12,b13,b14,b15,bhat1,bhat8,bhat9,bhat10,bhat11,bhat12,bhat13,bhat16 = cache
    copyat_or_push!(k,1,f(t,uprev))
    copyat_or_push!(k,2,f(t+c1*dt,uprev+dt*(a0201*k[1])))
    copyat_or_push!(k,3,f(t+c2*dt,uprev+dt*(a0301*k[1]+a0302*k[2])))
    copyat_or_push!(k,4,f(t+c3*dt,uprev+dt*(a0401*k[1]       +a0403*k[3])))
    copyat_or_push!(k,5,f(t+c4*dt,uprev+dt*(a0501*k[1]       +a0503*k[3]+a0504*k[4])))
    copyat_or_push!(k,6,f(t+c5*dt,uprev+dt*(a0601*k[1]                +a0604*k[4]+a0605*k[5])))
    copyat_or_push!(k,7,f(t+c6*dt,uprev+dt*(a0701*k[1]                +a0704*k[4]+a0705*k[5]+a0706*k[6])))
    copyat_or_push!(k,8,f(t+c7*dt,uprev+dt*(a0801*k[1]                                  +a0806*k[6]+a0807*k[7])))
    copyat_or_push!(k,9,f(t+c8*dt,uprev+dt*(a0901*k[1]                                  +a0906*k[6]+a0907*k[7]+a0908*k[8])))
    copyat_or_push!(k,10,f(t+c9*dt,uprev+dt*(a1001*k[1]                                  +a1006*k[6]+a1007*k[7]+a1008*k[8]+a1009*k[9])))
    copyat_or_push!(k,11,f(t+c10*dt,uprev+dt*(a1101*k[1]                                  +a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]+a1110*k[10])))
    copyat_or_push!(k,12,f(t+c11*dt,uprev+dt*(a1201*k[1]                                  +a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1210*k[10]+a1211*k[11])))
    copyat_or_push!(k,13,f(t+c12*dt,uprev+dt*(a1301*k[1]                                  +a1306*k[6]+a1307*k[7]+a1308*k[8]+a1309*k[9]+a1310*k[10]+a1311*k[11]+a1312*k[12])))
    copyat_or_push!(k,14,f(t+c13*dt,uprev+dt*(a1401*k[1]                                  +a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1410*k[10]+a1411*k[11]+a1412*k[12]+a1413*k[13])))
    copyat_or_push!(k,15,f(t+dt,uprev+dt*(a1501*k[1]                                  +a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1510*k[10]+a1511*k[11]+a1512*k[12]+a1513*k[13]+a1514*k[14])))
    copyat_or_push!(k,16,f(t+dt,uprev+dt*(a1601*k[1]                                  +a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1610*k[10]+a1611*k[11]+a1612*k[12]+a1613*k[13])))
  end
  if (calcVal2 && length(k)< 26) || calcVal3 # Have not added the extra stages yet
    @unpack c17,a1701,a1708,a1709,a1710,a1711,a1712,a1713,a1714,a1715,c18,a1801,a1808,a1809,a1810,a1811,a1812,a1813,a1814,a1815,a1817,c19,a1901,a1908,a1909,a1910,a1911,a1912,a1913,a1914,a1915,a1917,a1918,c20,a2001,a2008,a2009,a2010,a2011,a2012,a2013,a2014,a2015,a2017,a2018,a2019,c21,a2101,a2108,a2109,a2110,a2111,a2112,a2113,a2114,a2115,a2117,a2118,a2119,a2120,c22,a2201,a2208,a2209,a2210,a2211,a2212,a2213,a2214,a2215,a2217,a2218,a2219,a2220,a2221,c23,a2301,a2308,a2309,a2310,a2311,a2312,a2313,a2314,a2315,a2317,a2318,a2319,a2320,a2321,c24,a2401,a2408,a2409,a2410,a2411,a2412,a2413,a2414,a2415,a2417,a2418,a2419,a2420,a2421,c25,a2501,a2508,a2509,a2510,a2511,a2512,a2513,a2514,a2515,a2517,a2518,a2519,a2520,a2521,c26,a2601,a2608,a2609,a2610,a2611,a2612,a2613,a2614,a2615,a2617,a2618,a2619,a2620,a2621 = cache
    copyat_or_push!(k,17,f(t+c17*dt,uprev+dt*(a1701*k[1]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1713*k[13]+a1714*k[14]+a1715*k[15])))
    copyat_or_push!(k,18,f(t+c18*dt,uprev+dt*(a1801*k[1]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1813*k[13]+a1814*k[14]+a1815*k[15]+a1817*k[17])))
    copyat_or_push!(k,19,f(t+c19*dt,uprev+dt*(a1901*k[1]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1913*k[13]+a1914*k[14]+a1915*k[15]+a1917*k[17]+a1918*k[18])))
    copyat_or_push!(k,20,f(t+c20*dt,uprev+dt*(a2001*k[1]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2013*k[13]+a2014*k[14]+a2015*k[15]+a2017*k[17]+a2018*k[18]+a2019*k[19])))
    copyat_or_push!(k,21,f(t+c21*dt,uprev+dt*(a2101*k[1]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2113*k[13]+a2114*k[14]+a2115*k[15]+a2117*k[17]+a2118*k[18]+a2119*k[19]+a2120*k[20])))
    copyat_or_push!(k,22,f(t+c22*dt,uprev+dt*(a2201*k[1]+a2208*k[8]+a2209*k[9]+a2210*k[10]+a2211*k[11]+a2212*k[12]+a2213*k[13]+a2214*k[14]+a2215*k[15]+a2217*k[17]+a2218*k[18]+a2219*k[19]+a2220*k[20]+a2221*k[21])))
    copyat_or_push!(k,23,f(t+c23*dt,uprev+dt*(a2301*k[1]+a2308*k[8]+a2309*k[9]+a2310*k[10]+a2311*k[11]+a2312*k[12]+a2313*k[13]+a2314*k[14]+a2315*k[15]+a2317*k[17]+a2318*k[18]+a2319*k[19]+a2320*k[20]+a2321*k[21])))
    copyat_or_push!(k,24,f(t+c24*dt,uprev+dt*(a2401*k[1]+a2408*k[8]+a2409*k[9]+a2410*k[10]+a2411*k[11]+a2412*k[12]+a2413*k[13]+a2414*k[14]+a2415*k[15]+a2417*k[17]+a2418*k[18]+a2419*k[19]+a2420*k[20]+a2421*k[21])))
    copyat_or_push!(k,25,f(t+c25*dt,uprev+dt*(a2501*k[1]+a2508*k[8]+a2509*k[9]+a2510*k[10]+a2511*k[11]+a2512*k[12]+a2513*k[13]+a2514*k[14]+a2515*k[15]+a2517*k[17]+a2518*k[18]+a2519*k[19]+a2520*k[20]+a2521*k[21])))
    copyat_or_push!(k,26,f(t+c26*dt,uprev+dt*(a2601*k[1]+a2608*k[8]+a2609*k[9]+a2610*k[10]+a2611*k[11]+a2612*k[12]+a2613*k[13]+a2614*k[14]+a2615*k[15]+a2617*k[17]+a2618*k[18]+a2619*k[19]+a2620*k[20]+a2621*k[21])))
  end
  nothing
end

"""

"""
function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::Vern9Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if (length(k) < 16 || calcVal) || ((calcVal2 && length(k)< 26) || calcVal3)
    rtmp = similar(cache.k1)
  end
  if length(k) < 16 || calcVal
    @unpack c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0806,a0807,a0901,a0906,a0907,a0908,a1001,a1006,a1007,a1008,a1009,a1101,a1106,a1107,a1108,a1109,a1110,a1201,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1306,a1307,a1308,a1309,a1310,a1311,a1312,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,a1413,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1513,a1514,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1613,b1,b8,b9,b10,b11,b12,b13,b14,b15,bhat1,bhat8,bhat9,bhat10,bhat11,bhat12,bhat13,bhat16 = cache.tab
    f(t,uprev,rtmp); copyat_or_push!(k,1,rtmp)
    f(t+c1*dt,uprev+dt*(a0201*k[1]),rtmp); copyat_or_push!(k,2,rtmp)
    f(t+c2*dt,uprev+dt*(a0301*k[1]+a0302*k[2]),rtmp); copyat_or_push!(k,3,rtmp)
    f(t+c3*dt,uprev+dt*(a0401*k[1]       +a0403*k[3]),rtmp); copyat_or_push!(k,4,rtmp)
    f(t+c4*dt,uprev+dt*(a0501*k[1]       +a0503*k[3]+a0504*k[4]),rtmp); copyat_or_push!(k,5,rtmp)
    f(t+c5*dt,uprev+dt*(a0601*k[1]                +a0604*k[4]+a0605*k[5]),rtmp); copyat_or_push!(k,6,rtmp)
    f(t+c6*dt,uprev+dt*(a0701*k[1]                +a0704*k[4]+a0705*k[5]+a0706*k[6]),rtmp); copyat_or_push!(k,7,rtmp)
    f(t+c7*dt,uprev+dt*(a0801*k[1]                                  +a0806*k[6]+a0807*k[7]),rtmp); copyat_or_push!(k,8,rtmp)
    f(t+c8*dt,uprev+dt*(a0901*k[1]                                  +a0906*k[6]+a0907*k[7]+a0908*k[8]),rtmp); copyat_or_push!(k,9,rtmp)
    f(t+c9*dt,uprev+dt*(a1001*k[1]                                  +a1006*k[6]+a1007*k[7]+a1008*k[8]+a1009*k[9]),rtmp); copyat_or_push!(k,10,rtmp)
    f(t+c10*dt,uprev+dt*(a1101*k[1]                                  +a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]+a1110*k[10]),rtmp); copyat_or_push!(k,11,rtmp)
    f(t+c11*dt,uprev+dt*(a1201*k[1]                                  +a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1210*k[10]+a1211*k[11]),rtmp); copyat_or_push!(k,12,rtmp)
    f(t+c12*dt,uprev+dt*(a1301*k[1]                                  +a1306*k[6]+a1307*k[7]+a1308*k[8]+a1309*k[9]+a1310*k[10]+a1311*k[11]+a1312*k[12]),rtmp); copyat_or_push!(k,13,rtmp)
    f(t+c13*dt,uprev+dt*(a1401*k[1]                                  +a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1410*k[10]+a1411*k[11]+a1412*k[12]+a1413*k[13]),rtmp); copyat_or_push!(k,14,rtmp)
    f(t+dt,uprev+dt*(a1501*k[1]                                  +a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1510*k[10]+a1511*k[11]+a1512*k[12]+a1513*k[13]+a1514*k[14]),rtmp); copyat_or_push!(k,15,rtmp)
    f(t+dt,uprev+dt*(a1601*k[1]                                  +a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1610*k[10]+a1611*k[11]+a1612*k[12]+a1613*k[13]),rtmp); copyat_or_push!(k,16,rtmp)
  end
  if (calcVal2 && length(k)< 26) || calcVal3 # Have not added the extra stages yet
    @unpack c17,a1701,a1708,a1709,a1710,a1711,a1712,a1713,a1714,a1715,c18,a1801,a1808,a1809,a1810,a1811,a1812,a1813,a1814,a1815,a1817,c19,a1901,a1908,a1909,a1910,a1911,a1912,a1913,a1914,a1915,a1917,a1918,c20,a2001,a2008,a2009,a2010,a2011,a2012,a2013,a2014,a2015,a2017,a2018,a2019,c21,a2101,a2108,a2109,a2110,a2111,a2112,a2113,a2114,a2115,a2117,a2118,a2119,a2120,c22,a2201,a2208,a2209,a2210,a2211,a2212,a2213,a2214,a2215,a2217,a2218,a2219,a2220,a2221,c23,a2301,a2308,a2309,a2310,a2311,a2312,a2313,a2314,a2315,a2317,a2318,a2319,a2320,a2321,c24,a2401,a2408,a2409,a2410,a2411,a2412,a2413,a2414,a2415,a2417,a2418,a2419,a2420,a2421,c25,a2501,a2508,a2509,a2510,a2511,a2512,a2513,a2514,a2515,a2517,a2518,a2519,a2520,a2521,c26,a2601,a2608,a2609,a2610,a2611,a2612,a2613,a2614,a2615,a2617,a2618,a2619,a2620,a2621 = cache.tab
    f(t+c17*dt,uprev+dt*(a1701*k[1]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1713*k[13]+a1714*k[14]+a1715*k[15]),rtmp); copyat_or_push!(k,17,rtmp)
    f(t+c18*dt,uprev+dt*(a1801*k[1]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1813*k[13]+a1814*k[14]+a1815*k[15]+a1817*k[17]),rtmp); copyat_or_push!(k,18,rtmp)
    f(t+c19*dt,uprev+dt*(a1901*k[1]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1913*k[13]+a1914*k[14]+a1915*k[15]+a1917*k[17]+a1918*k[18]),rtmp); copyat_or_push!(k,19,rtmp)
    f(t+c20*dt,uprev+dt*(a2001*k[1]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2013*k[13]+a2014*k[14]+a2015*k[15]+a2017*k[17]+a2018*k[18]+a2019*k[19]),rtmp); copyat_or_push!(k,20,rtmp)
    f(t+c21*dt,uprev+dt*(a2101*k[1]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2113*k[13]+a2114*k[14]+a2115*k[15]+a2117*k[17]+a2118*k[18]+a2119*k[19]+a2120*k[20]),rtmp); copyat_or_push!(k,21,rtmp)
    f(t+c22*dt,uprev+dt*(a2201*k[1]+a2208*k[8]+a2209*k[9]+a2210*k[10]+a2211*k[11]+a2212*k[12]+a2213*k[13]+a2214*k[14]+a2215*k[15]+a2217*k[17]+a2218*k[18]+a2219*k[19]+a2220*k[20]+a2221*k[21]),rtmp); copyat_or_push!(k,22,rtmp)
    f(t+c23*dt,uprev+dt*(a2301*k[1]+a2308*k[8]+a2309*k[9]+a2310*k[10]+a2311*k[11]+a2312*k[12]+a2313*k[13]+a2314*k[14]+a2315*k[15]+a2317*k[17]+a2318*k[18]+a2319*k[19]+a2320*k[20]+a2321*k[21]),rtmp); copyat_or_push!(k,23,rtmp)
    f(t+c24*dt,uprev+dt*(a2401*k[1]+a2408*k[8]+a2409*k[9]+a2410*k[10]+a2411*k[11]+a2412*k[12]+a2413*k[13]+a2414*k[14]+a2415*k[15]+a2417*k[17]+a2418*k[18]+a2419*k[19]+a2420*k[20]+a2421*k[21]),rtmp); copyat_or_push!(k,24,rtmp)
    f(t+c25*dt,uprev+dt*(a2501*k[1]+a2508*k[8]+a2509*k[9]+a2510*k[10]+a2511*k[11]+a2512*k[12]+a2513*k[13]+a2514*k[14]+a2515*k[15]+a2517*k[17]+a2518*k[18]+a2519*k[19]+a2520*k[20]+a2521*k[21]),rtmp); copyat_or_push!(k,25,rtmp)
    f(t+c26*dt,uprev+dt*(a2601*k[1]+a2608*k[8]+a2609*k[9]+a2610*k[10]+a2611*k[11]+a2612*k[12]+a2613*k[13]+a2614*k[14]+a2615*k[15]+a2617*k[17]+a2618*k[18]+a2619*k[19]+a2620*k[20]+a2621*k[21]),rtmp); copyat_or_push!(k,26,rtmp)
 end
  nothing
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::DP8ConstantCache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<7 || calcVal
    @unpack c7,c8,c9,c10,c11,c6,c5,c4,c3,c2,b1,b6,b7,b8,b9,b10,b11,b12,bhh1,bhh2,bhh3,er1,er6,er7,er8,er9,er10,er11,er12,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0804,a0805,a0806,a0807,a0901,a0904,a0905,a0906,a0907,a0908,a1001,a1004,a1005,a1006,a1007,a1008,a1009,a1101,a1104,a1105,a1106,a1107,a1108,a1109,a1110,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211 = cache
    @unpack c14,c15,c16,a1401,a1407,a1408,a1409,a1410,a1411,a1412,a1413,a1501,a1506,a1507,a1508,a1511,a1512,a1513,a1514,a1601,a1606,a1607,a1608,a1609,a1613,a1614,a1615 = cache
    @unpack d401,d406,d407,d408,d409,d410,d411,d412,d413,d414,d415,d416,d501,d506,d507,d508,d509,d510,d511,d512,d513,d514,d515,d516,d601,d606,d607,d608,d609,d610,d611,d612,d613,d614,d615,d616,d701,d706,d707,d708,d709,d710,d711,d712,d713,d714,d715,d716 = cache
    k1 = f(t,uprev)
    k2 = f(t+c2*dt,uprev+dt*(a0201*k1))
    k3 = f(t+c3*dt,uprev+dt*(a0301*k1+a0302*k2))
    k4 = f(t+c4*dt,uprev+dt*(a0401*k1       +a0403*k3))
    k5 = f(t+c5*dt,uprev+dt*(a0501*k1       +a0503*k3+a0504*k4))
    k6 = f(t+c6*dt,uprev+dt*(a0601*k1                +a0604*k4+a0605*k5))
    k7 = f(t+c7*dt,uprev+dt*(a0701*k1                +a0704*k4+a0705*k5+a0706*k6))
    k8 = f(t+c8*dt,uprev+dt*(a0801*k1                +a0804*k4+a0805*k5+a0806*k6+a0807*k7))
    k9 = f(t+c9*dt,uprev+dt*(a0901*k1                +a0904*k4+a0905*k5+a0906*k6+a0907*k7+a0908*k8))
    k10= f(t+c10*dt,uprev+dt*(a1001*k1                +a1004*k4+a1005*k5+a1006*k6+a1007*k7+a1008*k8+a1009*k9))
    k11= f(t+c11*dt,uprev+dt*(a1101*k1                +a1104*k4+a1105*k5+a1106*k6+a1107*k7+a1108*k8+a1109*k9+a1110*k10))
    k12= f(t+dt,uprev+dt*(a1201*k1                +a1204*k4+a1205*k5+a1206*k6+a1207*k7+a1208*k8+a1209*k9+a1210*k10+a1211*k11))
    kupdate= b1*k1+b6*k6+b7*k7+b8*k8+b9*k9+b10*k10+b11*k11+b12*k12
    update = dt*kupdate
    utmp = uprev + update
    k13 = f(t+dt,utmp)
    k14 = f(t+c14*dt,uprev+dt*(a1401*k1         +a1407*k7+a1408*k8+a1409*k9+a1410*k10+a1411*k11+a1412*k12+a1413*k13))
    k15 = f(t+c15*dt,uprev+dt*(a1501*k1+a1506*k6+a1507*k7+a1508*k8                   +a1511*k11+a1512*k12+a1513*k13+a1514*k14))
    k16 = f(t+c16*dt,uprev+dt*(a1601*k1+a1606*k6+a1607*k7+a1608*k8+a1609*k9                              +a1613*k13+a1614*k14+a1615*k15))
    udiff = kupdate
    copyat_or_push!(k,1,udiff)
    bspl = k1 - udiff
    copyat_or_push!(k,2,bspl)
    copyat_or_push!(k,3,udiff - k13 - bspl)
    copyat_or_push!(k,4,(d401*k1+d406*k6+d407*k7+d408*k8+d409*k9+d410*k10+d411*k11+d412*k12+d413*k13+d414*k14+d415*k15+d416*k16))
    copyat_or_push!(k,5,(d501*k1+d506*k6+d507*k7+d508*k8+d509*k9+d510*k10+d511*k11+d512*k12+d513*k13+d514*k14+d515*k15+d516*k16))
    copyat_or_push!(k,6,(d601*k1+d606*k6+d607*k7+d608*k8+d609*k9+d610*k10+d611*k11+d612*k12+d613*k13+d614*k14+d615*k15+d616*k16))
    copyat_or_push!(k,7,(d701*k1+d706*k6+d707*k7+d708*k8+d709*k9+d710*k10+d711*k11+d712*k12+d713*k13+d714*k14+d715*k15+d716*k16))
  end
end

function ode_addsteps!{calcVal,calcVal2,calcVal3}(k,t,uprev,u,dt,f,cache::DP8Cache,always_calc_begin::Type{Val{calcVal}} = Val{false},allow_calc_end::Type{Val{calcVal2}} = Val{true},force_calc_end::Type{Val{calcVal3}} = Val{false})
  if length(k)<7 || calcVal
    @unpack c7,c8,c9,c10,c11,c6,c5,c4,c3,c2,b1,b6,b7,b8,b9,b10,b11,b12,bhh1,bhh2,bhh3,er1,er6,er7,er8,er9,er10,er11,er12,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0804,a0805,a0806,a0807,a0901,a0904,a0905,a0906,a0907,a0908,a1001,a1004,a1005,a1006,a1007,a1008,a1009,a1101,a1104,a1105,a1106,a1107,a1108,a1109,a1110,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211 = cache.tab
    @unpack c14,c15,c16,a1401,a1407,a1408,a1409,a1410,a1411,a1412,a1413,a1501,a1506,a1507,a1508,a1511,a1512,a1513,a1514,a1601,a1606,a1607,a1608,a1609,a1613,a1614,a1615 = cache.tab
    @unpack d401,d406,d407,d408,d409,d410,d411,d412,d413,d414,d415,d416,d501,d506,d507,d508,d509,d510,d511,d512,d513,d514,d515,d516,d601,d606,d607,d608,d609,d610,d611,d612,d613,d614,d615,d616,d701,d706,d707,d708,d709,d710,d711,d712,d713,d714,d715,d716 = cache.tab
    @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13,k14,k15,k16,update,udiff,bspl,dense_tmp3,dense_tmp4,dense_tmp5,dense_tmp6,dense_tmp7,kupdate,utilde,tmp,atmp,atmp2 = cache
    utmp = utilde
    k = [cache.udiff,cache.bspl,cache.dense_tmp3,cache.dense_tmp4,cache.dense_tmp5,cache.dense_tmp6,cache.dense_tmp7]
    uidx = eachindex(u)
    f(t,uprev,k1)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a0201*k1[i])
    end
    f(t+c2*dt,tmp,k2)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a0301*k1[i]+a0302*k2[i])
    end
    f(t+c3*dt,tmp,k3)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a0401*k1[i]+a0403*k3[i])
    end
    f(t+c4*dt,tmp,k4)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a0501*k1[i]+a0503*k3[i]+a0504*k4[i])
    end
    f(t+c5*dt,tmp,k5)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a0601*k1[i]+a0604*k4[i]+a0605*k5[i])
    end
    f(t+c6*dt,tmp,k6)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a0701*k1[i]+a0704*k4[i]+a0705*k5[i]+a0706*k6[i])
    end
    f(t+c7*dt,tmp,k7)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a0801*k1[i]+a0804*k4[i]+a0805*k5[i]+a0806*k6[i]+a0807*k7[i])
    end
    f(t+c8*dt,tmp,k8)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a0901*k1[i]+a0904*k4[i]+a0905*k5[i]+a0906*k6[i]+a0907*k7[i]+a0908*k8[i])
    end
    f(t+c9*dt,tmp,k9)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a1001*k1[i]+a1004*k4[i]+a1005*k5[i]+a1006*k6[i]+a1007*k7[i]+a1008*k8[i]+a1009*k9[i])
    end
    f(t+c10*dt,tmp,k10)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a1101*k1[i]+a1104*k4[i]+a1105*k5[i]+a1106*k6[i]+a1107*k7[i]+a1108*k8[i]+a1109*k9[i]+a1110*k10[i])
    end
    f(t+c11*dt,tmp,k11)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a1201*k1[i]+a1204*k4[i]+a1205*k5[i]+a1206*k6[i]+a1207*k7[i]+a1208*k8[i]+a1209*k9[i]+a1210*k10[i]+a1211*k11[i])
    end
    f(t+dt,tmp,k12)
    for i in uidx
      kupdate[i] = b1*k1[i]+b6*k6[i]+b7*k7[i]+b8*k8[i]+b9*k9[i]+b10*k10[i]+b11*k11[i]+b12*k12[i]
      update[i] = dt*kupdate[i]
      utmp[i] = uprev[i] + update[i]
    end
    f(t+dt,utmp,k13)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a1401*k1[i]+a1407*k7[i]+a1408*k8[i]+a1409*k9[i]+a1410*k10[i]+a1411*k11[i]+a1412*k12[i]+a1413*k13[i])
    end
    f(t+c14*dt,tmp,k14)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a1501*k1[i]+a1506*k6[i]+a1507*k7[i]+a1508*k8[i]+a1511*k11[i]+a1512*k12[i]+a1513*k13[i]+a1514*k14[i])
    end
    f(t+c15*dt,tmp,k15)
    for i in uidx
      tmp[i] = uprev[i]+dt*(a1601*k1[i]+a1606*k6[i]+a1607*k7[i]+a1608*k8[i]+a1609*k9[i]+a1613*k13[i]+a1614*k14[i]+a1615*k15[i])
    end
    f(t+c16*dt,tmp,k16)
    for i in uidx
      udiff[i]= kupdate[i]
      bspl[i] = k1[i] - udiff[i]
      k[3][i] = udiff[i] - k13[i] - bspl[i]
      k[4][i] = (d401*k1[i]+d406*k6[i]+d407*k7[i]+d408*k8[i]+d409*k9[i]+d410*k10[i]+d411*k11[i]+d412*k12[i]+d413*k13[i]+d414*k14[i]+d415*k15[i]+d416*k16[i])
      k[5][i] = (d501*k1[i]+d506*k6[i]+d507*k7[i]+d508*k8[i]+d509*k9[i]+d510*k10[i]+d511*k11[i]+d512*k12[i]+d513*k13[i]+d514*k14[i]+d515*k15[i]+d516*k16[i])
      k[6][i] = (d601*k1[i]+d606*k6[i]+d607*k7[i]+d608*k8[i]+d609*k9[i]+d610*k10[i]+d611*k11[i]+d612*k12[i]+d613*k13[i]+d614*k14[i]+d615*k15[i]+d616*k16[i])
      k[7][i] = (d701*k1[i]+d706*k6[i]+d707*k7[i]+d708*k8[i]+d709*k9[i]+d710*k10[i]+d711*k11[i]+d712*k12[i]+d713*k13[i]+d714*k14[i]+d715*k15[i]+d716*k16[i])
    end
  end
end
