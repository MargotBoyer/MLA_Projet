# Mathis Azéma et Michel Sénégas
using JuMP
using CPLEX

function main_stable(n::Int, m::Int, cost_connection::Matrix{Int})
    p=2 #Nombre de sites à ouvrir (pas dans les données)

    distances_K_D = distances_triées(n::Int, m::Int, cost_connection)
    K, D = distances_K_D[1], distances_K_D[2]
    kup=K
    klb=1
    while kup-klb>1
        delta= D[Int(floor((kup+klb)/2))]
        Arcs_Gp=creation_graphe_Gp(n,m ,cost_connection, delta)
        val=resolution_stable_max(n, Arcs_Gp)
        if val<=p
            kup=Int(floor((kup+klb)/2))
        else
            klb=Int(floor((kup+klb)/2))
        end
    end
    if kup==2
        delta= D[1]
        Arcs_Gp=creation_graphe_Gp(n,m ,cost_connection, delta)
        val=resolution_stable_max(n, Arcs_Gp)
        return D[1]
    else
        return D[kup]
    end
end 

function distances_triées(n::Int, m::Int, distances::Matrix{Int})
    """Renvoit les distances différentes triées et leur nombre K"""
    # n nombre de clients
    # m nombre de sites
    
    distances_différentes = []
    for i in 1:n
        for j in 1:m
            if !(distances[i,j] in distances_différentes)
                push!(distances_différentes,distances[i,j])
            end
        end
    end
    
    distances_différentes = sort(distances_différentes)
    K = length(distances_différentes)

    return (K,distances_différentes)
end

function resolution_stable_max(n::Int, Arcs_Gp::Vector{Any})
    """Calcul le stable dans le graphe Gp"""
    # n nombre de clients
    # Arcs G_p les arcs du graphe Gp
    
    model = Model(CPLEX.Optimizer)
    set_silent(model)

    @variable(model, x[1:n], Bin)

    
    @constraint(model, [(i, ip) in Arcs_Gp], x[i]+x[ip] <= 1)
    @objective(model, Max, sum(x[i] for i in 1:n))

    optimize!(model)

    return objective_value(model)
end

function creation_graphe_Gp(n::Int, m::Int, cost_connection::Matrix{Int}, delta::Int)
    """Calcul les arcs du graphe Gp."""
    # n nombre de clients, m le nombre de sites
    # delta distance pour créer le graphe G
    Arcs_G=[]
    sites_clients_delta=[[] for j in 1:m]
    for i in 1:n
        for j in 1:m
            if cost_connection[i,j]<= delta #Il existe un arc dans le graphe G si le site j est à moins de delta du client i
                push!(Arcs_G, (i,j))
                push!(sites_clients_delta[j], i)
            end
        end
    end
    Arcs_Gp=[]
    Arcs_Gp_exist=[[0 for ip in 1:n] for i in 1:n]
    for j in 1:m
        for i in sites_clients_delta[j]
            for ip in sites_clients_delta[j]
                if ip>i && Arcs_Gp_exist[i][ip]==0 # Il existe un arc dans Gp si (i,ip) ont un voisin commun dans le graphe G
                    push!(Arcs_Gp, (i,ip))
                    Arcs_Gp_exist[i][ip]=1
                end
            end
        end
    end
    return Arcs_Gp
end

"""Résout le problème de set cover."""
function set_cover(distances::Matrix{Int},δ::Int)
    n,m = size(distances)

    model = Model(CPLEX.Optimizer)
    set_silent(model)

    @variable(model,y[1:m],Bin)

    @constraint(model,[i in 1:n],sum(y[j] for j in 1:m if distances[i,j] ≤ δ) ≥ 1)

    @objective(model,MIN_SENSE,sum(y))

    optimize!(model)

    return objective_value(model),value.(y)
end
"""Résout la relaxation continue du problème de set cover en O(mn²)"""
function set_cover_relax(distances::Matrix{Int},δ::Int)
    n,m = size(distances)
    A = falses(n,m)
    setsize = zeros(Int,n)
    for j in 1:m
        for i in 1:n
            if distances[i,j] ≤ δ
                A[i,j] = true
                setsize[i] += 1
            end
        end
    end
    b = ones(n)
    y = zeros(m)
    nbunassigned = m

    while nbunassigned ≠ 0
        i = argmin(ii -> setsize[ii] / b[ii],1:n)
        nbunassigned -= setsize[i]
        v = b[i] / setsize[i]
        for j in 1:m
            if A[i,j]
                y[j] = v
                for ii in 1:n
                    if A[ii,j]
                        setsize[ii] -= 1
                        b[ii] -= v
                        A[ii,j] = false
                    end
                end
            end
        end
        setsize[i] = 1
    end
    return sum(y),y
end
