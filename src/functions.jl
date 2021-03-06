#       ------------------------------------------------
#                  Defining general functions 
#       ------------------------------------------------

#--- w_Log: Function to write the log ---
function w_Log( msg::String, path::String , flagConsole::Int = 1, flagLog::Int = 1 , logName = "dispatch.log" , wType = "a" )
    
    if flagLog == 1
        logFile = open( joinpath( path , logName ) , wType )
        write( logFile , string( msg , "\n" ) )
        Base.close( logFile )
    end

    if flagConsole == 1
        Base.print( string( msg , "\n" ) )
    end

    return nothing
end

#--- stringConv: Function to convert read strings to another type ---

function string_converter( self::String , tipo::Type , msg::String ) 
    try
        parse( tipo , self )
    catch
        @show self
        error( msg )
    end
end;

function string_converter( self::SubString{String} , tipo::Type , msg::String ) 
    try
        parse( tipo , self )
    catch
        @show self
        error( msg )
    end
end;

#--- getPaths: Function to get paths ---
function get_paths( path::String = pwd() )
    
    local aux_path::String
    local path_case::String
    
    try
        aux_path = readlines( joinpath( path , "path.dat" ) )[2][27:end]
    catch
        Base.print("  ERROR: File not found (path.dat)")
        exit()
    end
    
    if is_windows()
        path_case  = normpath( string( aux_path, "\\") ) ;
    else    
        path_case  = normpath( string( aux_path, "/") );
    end

    if isdir( path_case ) == false
        Base.print("  ERROR: Directory doesnt exist $(path_case)")
        exit()
    end

    return path_case
end

#--- getvalue: Function to get value from model and symbol ---
function getvalue( model::JuMP.Model, s::Symbol )
    JuMP.getvalue( JuMP.getindex( model , s ) )
end

#--- get_contingency_scenarios: Function to create arrays with contingencies scenarios based on users input ----
function get_contingency_scenarios( case::Case )
    
    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local k::Int            # Local variable to loop over contingency scenarios
    local nCen::Int         # Local variable to buffer the number of contingency scenarios
    local nElements::Int    # Local variable to buffer number of elements that are in the contingency arrays
    local n_zeros::Int      # Auxiliar variable
    local n_ones::Int       # Auxiliar variable
    local linha::Int        # Auxiliar variable

    local ag::Array{Int}    # Local variable to buffer the array with contingency scenarios for generators
    local al::Array{Int}    # Local variable to buffer the array with contingency scenarios for circuits

    #-------------------------------
    #--- Interpreting the inputs ---
    #-------------------------------

    #--- Checking if there is no contingency to test
    if case.Flag_Cont == 0
        return( 0 , ones( case.nGen , 1 ) , ones( case.nCir , 1 ) )
    end

    #--- Get the number of elements to create contingency arrays
    if case.Flag_Cont == 1
        nElements = case.nCir + case.nGen  
    elseif case.Flag_Cont == 2
        nElements = case.nGen          
    elseif case.Flag_Cont == 3
        nElements = case.nCir
    end

    #--- Get the number of possible combinations
    for k in 1:case.Flag_nCont
        nCen = binomial(nElements, k)
    end

    #-------------------------------------------------------------
    #--- Build array of permutation vectors for each scenario  ---
    #-------------------------------------------------------------

    ag = ones( Int, nCen+1 , case.nGen )
    al = ones( Int, nCen+1 , case.nCir )
    
    linha = 0

    for k in 0:case.Flag_nCont  
        
        #- Reset contingencies to match criteria G+T, T or G
        
        if case.Flag_Cont == 1 # G+T
            
            n_zeros = k
            n_ones  = nElements - k
            v       = [ ones( Int , n_ones ) ; zeros( Int , n_zeros ) ]
            per     = unique( multiset_permutations( v , nElements ) )

            for ( idx , i ) in enumerate( per )
                linha += 1
                ag[linha,:] = i[1:case.nGen]
                al[linha,:] = i[case.nGen+1:nElements]
            end

        elseif case.Flag_Cont == 2 # G

            n_zeros = k
            n_ones  = case.nGen - k
            v       = [ ones( Int , n_ones ) ; zeros( Int , n_zeros ) ]
            per     = unique(multiset_permutations(v, nElements))

            for ( idx , i ) in enumerate(per)
                linha += 1
                ag[linha,:] = i[1:case.nGen]
            end

        elseif case.Flag_Cont == 3 # T

            n_zeros = k
            n_ones  = case.nCir - k
            v       = [ ones( Int , n_ones ) ; zeros( Int , n_zeros )]
            per     = unique( multiset_permutations( v , nElements ) )

            for ( idx , i ) in enumerate( per )
                linha += 1
                al[linha,:] = i[1:case.nCir]
            end

        end
    end

    return( nCen , ag' , al' )
end

#--------------------------------------------------------
#----           Functions to read data base          ----
#--------------------------------------------------------

#--- read_options: Function to read model options ---
function read_options( path::String , file_name::String = "dispatch.dat" )
    
    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local iofile::IOStream                  # Local variable to buffer connection to gencos.dat file
    local iodata::Array{String,1}           # Local variable to buffer information from read gencos.dat file
    local flag_res::Int                     # Local variable to buffer reserve option
    local flag_ang::Int                     # Local variable to buffer angular diff option
    local flag_cont::Int                    # Local variable to buffer contingency option
    local flag_cont_crit::Int               # Local variable to buffer contingency criteria option

    #---------------------------------
    #--- Reading file (gencos.dat) ---
    #---------------------------------

    iofile = open( joinpath( path , file_name ) , "r" )
    iodata = readlines( iofile );
    Base.close( iofile )

    #-----------------------
    #--- Assigning data  ---
    #-----------------------
    
    flag_ang       = string_converter( iodata[1][27:30]  , Int , "Invalid entry for angular diff option")
    flag_res       = string_converter( iodata[2][27:30]  , Int , "Invalid entry for reserve option")
    flag_cont      = string_converter( iodata[3][27:30]  , Int , "Invalid entry for contingency option")
    flag_cont_crit = string_converter( iodata[4][27:30]  , Int , "Invalid entry for contingency criteria option")

    #--- Checking user input consistency

    #- Reserve option
    if (flag_res != 0) & (flag_res != 1)
        exit()
    end

    #- Angular diff option
    if (flag_ang != 0) & (flag_ang != 1)
        exit()
    end

    #- Contingency option
    if (flag_cont != 0) & (flag_cont != 1) & (flag_cont != 2) & (flag_cont != 3)
        exit()
    end

    return( flag_res , flag_ang , flag_cont, flag_cont_crit )
end 

function read_gencos( path::String , file_name::String = "gencos.csv")

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local iofile::IOStream                      # Local variable to buffer connection to gencos.dat file
    local iodata::Array{String,1}               # Local variable to buffer information from read gencos.dat file
    local auxdata::Array{SubString{String},1}   # Local variable to buffer information after parsing
    local u::Int                                # Local variable to loop over gencos 
    local nGen::Int                             # Local variable to buffer the number of gencos
    local gencos::Gencos                        # Local variable to buffer gencos information
    
    #---------------------------------
    #--- Reading file (gencos.dat) ---
    #---------------------------------
    iofile = open( joinpath( path , file_name ) , "r" )
    iodata = readlines( iofile );
    Base.close( iofile )

    #- Removing header
    iodata = iodata[2:end]

    #-----------------------
    #--- Assigning data  ---
    #-----------------------

    #- Get the number of simulated gencos
    nGen = length( iodata )

    #- Create struct to buffer gencos information

    gencos                 = Gencos()
    gencos.Num             = Array{Int}(nGen)
    gencos.Name            = Array{String}(nGen)
    gencos.Bus             = Array{Int}(nGen)
    gencos.PotMin          = Array{Float64}(nGen)
    gencos.PotMax          = Array{Float64}(nGen)
    gencos.PotPat1         = Array{Float64}(nGen)
    gencos.PotPat2         = Array{Float64}(nGen)
    gencos.StartUpRamp     = Array{Float64}(nGen)
    gencos.RampUp          = Array{Float64}(nGen)
    gencos.ShutdownRamp    = Array{Float64}(nGen)
    gencos.RampDown        = Array{Float64}(nGen)
    gencos.ReserveUp       = Array{Float64}(nGen)
    gencos.ReserveDown     = Array{Float64}(nGen)
    gencos.UpTime          = Array{Int}(nGen)
    gencos.DownTime        = Array{Int}(nGen)
    gencos.CVU             = Array{Float64}(nGen)
    gencos.CVUPat1         = Array{Float64}(nGen)
    gencos.CVUPat2         = Array{Float64}(nGen)
    gencos.CVUPat3         = Array{Float64}(nGen)
    gencos.StartUpCost_1   = Array{Float64}(nGen)
    gencos.StartUpCost_2   = Array{Float64}(nGen)
    gencos.StartUpCost_3   = Array{Float64}(nGen)
    gencos.ShutdownCost    = Array{Float64}(nGen)
    gencos.ReserveUpCost   = Array{Float64}(nGen)
    gencos.ReserveDownCost = Array{Float64}(nGen)
    
    #- Looping over the read information from gencos.dat 

    for u in 1:nGen
        auxdata = split( iodata[u] , "," )
        gencos.Num[u]             = string_converter( auxdata[1]  , Int , "Invalid entry for the number of genco $(u) ")
        gencos.Name[u]            = strip( auxdata[2] )
        gencos.Bus[u]             = string_converter( auxdata[3]  , Int     , "Invalid entry for the bus of genco $(u)")
        gencos.PotMin[u]          = string_converter( auxdata[4]  , Float64 , "Invalid entry for the min pot of genco $(u) ")
        gencos.PotMax[u]          = string_converter( auxdata[5]  , Float64 , "Invalid entry for the max pot of genco $(u) ")
        gencos.PotPat1[u]         = string_converter( auxdata[6]  , Float64 , "Invalid entry for the Pot Pat 1 of genco $(u) ")
        gencos.PotPat2[u]         = string_converter( auxdata[7]  , Float64 , "Invalid entry for the Pot Pat 2 of genco $(u) ")
        gencos.StartUpRamp[u]     = string_converter( auxdata[8]  , Float64 , "Invalid entry for the Start-Up Ramp of genco $(u) ")
        gencos.RampUp[u]          = string_converter( auxdata[9]  , Float64 , "Invalid entry for the Ramp-Up of genco $(u) ")
        gencos.ShutdownRamp[u]    = string_converter( auxdata[10]  , Float64 , "Invalid entry for the Shutdown Ramp of genco $(u) ")
        gencos.RampDown[u]        = string_converter( auxdata[11]  , Float64 , "Invalid entry for the Ramp-Down of genco $(u) ")
        gencos.ReserveUp[u]       = string_converter( auxdata[12]  , Float64 , "Invalid entry for the Reserve-Up of genco $(u) ")
        gencos.ReserveDown[u]     = string_converter( auxdata[13]  , Float64 , "Invalid entry for the Reserve-Down of genco $(u) ")
        gencos.UpTime[u]          = string_converter( auxdata[14]  , Int     , "Invalid entry for the Up Time of genco $(u) ")
        gencos.DownTime[u]        = string_converter( auxdata[15]  , Int     , "Invalid entry for the Down Time of genco $(u) ")
        gencos.CVU[u]             = string_converter( auxdata[16]  , Float64 , "Invalid entry for the CVU of genco $(u) ")
        gencos.CVUPat1[u]         = string_converter( auxdata[17]  , Float64 , "Invalid entry for the CVU Pat 1 of genco $(u) ")
        gencos.CVUPat2[u]         = string_converter( auxdata[18]  , Float64 , "Invalid entry for the CVU Pat 2 of genco $(u) ")
        gencos.CVUPat3[u]         = string_converter( auxdata[19]  , Float64 , "Invalid entry for the CVU Pat 3 of genco $(u) ")
        gencos.StartUpCost_1[u]   = string_converter( auxdata[20]  , Float64 , "Invalid entry for the Start-Up Cost 1 of genco $(u) ")
        gencos.StartUpCost_2[u]   = string_converter( auxdata[21]  , Float64 , "Invalid entry for the Start-Up Cost 2 of genco $(u) ")
        gencos.StartUpCost_3[u]   = string_converter( auxdata[22]  , Float64 , "Invalid entry for the Start-Up Cost 3 of genco $(u) ")
        gencos.ShutdownCost[u]    = string_converter( auxdata[23]  , Float64 , "Invalid entry for the Shutdown Cost of genco $(u) ")
        gencos.ReserveUpCost[u]   = string_converter( auxdata[24]  , Float64 , "Invalid entry for the Reserve Up Cost of genco $(u) ")
        gencos.ReserveDownCost[u] = string_converter( auxdata[25]  , Float64 , "Invalid entry for the Reserve Down Cost of genco $(u) ")
        
    end

    return( nGen , gencos )

end

#--- read_demands: Function to read demands configuration ---
function read_demands( path::String , file_name::String = "demand.csv")

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local iofile::IOStream                      # Local variable to buffer connection to demands.dat file
    local iodata::Array{String,1}               # Local variable to buffer information from read demands.dat file
    local auxdata::Array{SubString{String},1}   # Local variable to buffer information after parsing
    local d::Int                                # Local variable to loop over loads 
    local t::Int                                # Local variable to loop over periods
    local nDem::Int                             # Local variable to buffer the number of demands
    local demands::Demands                      # Local variable to buffer demands information
    
    #---------------------------------
    #--- Reading file (demand.dat) ---
    #---------------------------------

    iofile = open( joinpath( path , file_name ) , "r" )
    iodata = readlines( iofile );
    Base.close( iofile )

    #- Removing header
    iodata = iodata[2:end]

    #-----------------------
    #--- Assigning data  ---
    #-----------------------

    #- Get the number of simulated demand
    nDem = length( iodata )

    #- Create struct to buffer demands information
    demands         = Demands()
    demands.Num     = Array{Int}(nDem)
    demands.Name    = Array{String}(nDem)
    demands.Bus     = Array{Int}(nDem)
    demands.Dem     = Array{Float64}(nDem)
    demands.Profile = Array{Float64}(nDem,24)

    #- Looping over the read information from demand.dat 
    for d in 1:nDem
        auxdata         = split( iodata[d] , "," )
        demands.Num[d]  = string_converter( auxdata[1]  , Int , "Invalid entry for the number of demand $(d)")  
        demands.Name[d] = strip( auxdata[2] ) 
        demands.Bus[d]  = string_converter( auxdata[3]  , Int     , "Invalid entry for the demand bus $(d)") 
        demands.Dem[d]  = string_converter( auxdata[4]  , Float64 , "Invalid entry for the load of demand $(d)")
        for t in 1:24
            demands.Profile[d,t] = string_converter( auxdata[4+t]  , Float64 , "Invalid entry for the load profile of demand $(d) in hour $(t)")
        end
    end

    return( nDem , demands )
end

#--- read_circuits: Function to read circuits configuration ---
function read_circuits( path::String , file_name::String = "circs.csv")

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local iofile::IOStream                      # Local variable to buffer connection to circs.dat file
    local iodata::Array{String,1}               # Local variable to buffer information from read circs.dat file
    local auxdata::Array{SubString{String},1}   # Local variable to buffer information after parsing
    local l::Int                                # Local variable to loop over circuits 
    local nCir::Int                             # Local variable to buffer the number of circuits
    local circuits::Circuits                    # Local variable to buffer circuits information
    
    #---------------------------------
    #--- Reading file (gencos.dat) ---
    #---------------------------------

    iofile = open( joinpath( path , file_name ) , "r" )
    iodata = readlines( iofile );
    Base.close( iofile )

    #- Removing header
    iodata = iodata[2:end]

    #-----------------------
    #--- Assigning data  ---
    #-----------------------

    #- Get the number of simulated gencos
    nCir = length( iodata )

    #- Create struct to buffer gencos information

    circuits         = Circuits()
    circuits.Num     = Array{Int}(nCir)
    circuits.Name    = Array{String}(nCir)
    circuits.Cap     = Array{Float64}(nCir)
    circuits.Reat    = Array{Float64}(nCir)
    circuits.BusFrom = Array{Int}(nCir)
    circuits.BusTo   = Array{Int}(nCir)
    
    #- Looping over the read information from circs.dat 
    for l in 1:nCir
        auxdata              = split( iodata[l] , "," )
        circuits.Num[l]      = string_converter( auxdata[1]  , Int , "Invalid entry for the number of CIRCUIT")
        circuits.Name[l]     = strip( auxdata[2] )
        circuits.Cap[l]      = string_converter( auxdata[3]  , Float64 , "Invalid entry for the CIRCUIT capacity" )
        circuits.Reat[l]     = string_converter( auxdata[4]  , Float64 , "Invalid entry for the CIRCUIT reactance" )
        circuits.BusFrom[l]  = string_converter( auxdata[5]  , Int     , "Invalid entry for the CIRCUIT bus from" )
        circuits.BusTo[l]    = string_converter( auxdata[6]  , Int     , "Invalid entry for the CIRCUIT bus to" )
    end

    return( nCir , circuits )

end

#--- read_buses: Function to read buses configuration ---
function read_buses( path::String , file_name::String = "buses.csv")

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local iofile::IOStream                      # Local variable to buffer connection to buses.dat file
    local iodata::Array{String,1}               # Local variable to buffer information from read buses.dat file
    local auxdata::Array{SubString{String},1}   # Local variable to buffer information after parsing
    local b::Int                                # Local variable to loop over buses 
    local nGen::Int                             # Local variable to buffer the number of buses
    local buses::Buses                          # Local variable to buffer buses information
   
    #---------------------------------
    #--- Reading file (buses.dat) ---
    #---------------------------------

    iofile = open( joinpath( path , file_name ) , "r" )
    iodata = readlines( iofile );
    Base.close( iofile )

    #- Removing header
    iodata = iodata[2:end]

    #-----------------------
    #--- Assigning data  ---
    #-----------------------

    #- Get the number of simulated gencos
    nBus = length( iodata )

    #- Create struct to buffer gencos information
    buses         = Buses()
    buses.Num     = Array{Int}(nBus)
    buses.Name    = Array{String}(nBus)

    #- Looping over the read information from buses.dat 
    for b in 1:nBus
        auxdata        = split( iodata[b] , "," )
        buses.Num[b]   = string_converter( auxdata[1]  , Int , "Invalid entry for the number of BUS")
        buses.Name[b]  = strip( auxdata[2] )
    end

    return( nBus , buses )

end

#--- read_data_base: Function to load all data base ---
function read_data_base( path::String )

    CASE = Case();

    #---- Loading case configuration ----
    w_Log("     Case configuration", path );
    CASE.Flag_Res , CASE.Flag_Ang , CASE.Flag_Cont , CASE.Flag_nCont = read_options(  path );

    #---- Loading generators configuration ----
    w_Log("     Generators configuration", path );
    CASE.nGen , GENCOS                             = read_gencos(   path );

    #---- Loading loads configuration ----
    w_Log("     Loads configuration", path );
    CASE.nDem , DEMANDS                            = read_demands(  path );

    #---- Loading circuits configuration ----
    w_Log("     Circuits configuration", path );
    CASE.nCir , CIRCUITS                           = read_circuits( path );

    #---- Loading buses configuration ----
    w_Log("     Buses configuration", path );
    CASE.nBus , BUSES                              = read_buses(    path );

    return ( CASE , GENCOS , DEMANDS , CIRCUITS , BUSES )
end



# todo parsing street
#-----------------------------------------------------
#----           Functions to build model          ----
#-----------------------------------------------------

#--- create_model: This function creates the JuMP model and its variables ---
function create_model( case::Case )
    
    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local myModel::JuMP.Model                  # Local variable to create optmization model

    #-----------------------
    #---  Creating model ---
    #-----------------------

    myModel = Model( solver = ClpSolver( ) );

    @variable(myModel, f[1:case.nCir, 1:(case.nContScen+1)] );
    @variable(myModel, g[1:case.nGen, 1:(case.nContScen+1)] >= 0);
    @variable(myModel, delta[1:case.nBus, 1:(case.nContScen+1)] >= 0);

    if case.Flag_Ang == 1
        @variable(myModel, theta[1:case.nBus, 1:(case.nContScen+1)]);        
    end

    if case.Flag_Res == 1
        @variable(myModel, resup[1:case.nGen] >= 0);
        @variable(myModel, resdown[1:case.nGen] >= 0);
    end

    return( myModel)
end

#--- add_grid_constraint!: This function creates the maximum and minimum flow constraint ---
function add_grid_constraint!( model::JuMP.Model , case::Case , circuits::Circuits )

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local l::Int                                        # Local variable to loop over lines
    local f::Array{JuMP.Variable,2}                     # Local variable to represent flow decision variable
 
    #- Assigning values
    f = model[:f]
    al = case.al

    #-----------------------------------------
    #---  Adding constraints in the model  ---
    #-----------------------------------------

    @constraint( model , max_circ_cap[l=1:case.nCir,c=1:(case.nContScen+1)] , f[l,c]  <= circuits.Cap[l] * al[l,c]  )
    @constraint( model , min_circ_cap[l=1:case.nCir,c=1:(case.nContScen+1)] , -circuits.Cap[l] * al[l,c] <= f[l,c]  )

end

#--- add_angle_constraint!: This function creates the angle diff constraint ---
function add_angle_constraint!( model::JuMP.Model , case::Case , circuits::Circuits )

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local l::Int                                    # Local variable to loop over lines

    local f::Array{JuMP.Variable,2}                 # Local variable to represent flow decision variable of model
    local theta::Array{JuMP.Variable,2}             # Local variable to represent angle decision variable of model
    local al::Array{Int,2}                          # Local variable to represent contingency

    local angle_lag::Array{JuMP.ConstraintRef,2}    # Local variable to represent angle lag constraint reference
    
    #- Assigning values

    f     = model[:f]
    theta = model[:theta]
    al    = case.al

    #-----------------------------------------
    #---  Adding constraints in the model  ---
    #-----------------------------------------
    @constraint( model , angle_lag[l=1:case.nCir, c=1:(case.nContScen+1)], f[l,c] == ( al[l,c] / circuits.Reat[l] ) * ( theta[circuits.BusFrom[l],c] - theta[circuits.BusTo[l],c] ) )
end

#--- add_gen_constraint!: This function creates the maximum and minimum generation constraint ---
function add_gen_constraint!( model::JuMP.Model , case::Case , generators::Gencos )

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local u::Int                                    # Local variable to loop over generators
    
    local g::Array{JuMP.Variable,2}                 # Local variable to represent generation decision variable
    local resup::Array{JuMP.Variable,1}               # Local variable to represent reserve up decision variable
    local resdown::Array{JuMP.Variable,1}             # Local variable to represent reserve down decision variable
     
    local max_gen::Array{JuMP.ConstraintRef,1}      # Local variable to represent maximum generation constraint reference
    local min_gen::Array{JuMP.ConstraintRef,1}      # Local variable to represent minimum generation constraint reference

    #- Assigning values

    g = model[:g]

    if case.Flag_Res == 1
        resup   = model[:resup]
        resdown = model[:resdown]
    end
    
    #-----------------------------------------
    #---  Adding constraints in the model  ---
    #-----------------------------------------
    
    if case.Flag_Res == 1
        @constraint(model, max_gen[u=1:case.nGen],   g[u,1] + resup[u] <= generators.PotMax[u] )

        @constraint(model, min_gen[u=1:case.nGen],  0 <=  g[u,1] - resdown[u] )
    else
        @constraint(model, max_gen[u=1:case.nGen],   g[u,1] <= generators.PotMax[u] )
    end
end

#--- add_reserve_constraint!: This function creates the maximum and minimum reserve constraint ---
function add_reserve_constraint!( model::JuMP.Model , case::Case , generators::Gencos )

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local u::Int                                    # Local variable to loop over generators
    
    local resup::Array{JuMP.Variable,1}               # Local variable to represent reserve up decision variable
    local resdown::Array{JuMP.Variable,1}             # Local variable to represent reserve down decision variable
    
    local max_resup::Array{JuMP.ConstraintRef,1}      # Local variable to represent maximum reserve up constraint reference
    local max_resdown::Array{JuMP.ConstraintRef,1}    # Local variable to represent maximum reserve down constraint reference

    #- Assigning values

    resup   = model[:resup]
    resdown = model[:resdown]
    
    #-----------------------------------------
    #---  Adding constraints in the model  ---
    #-----------------------------------------

    @constraint(model, max_resup[u=1:case.nGen]   ,  resup[u] <= generators.ReserveUp[u]    )
    @constraint(model, max_resdown[u=1:case.nGen] , resdown[u] <= generators.ReserveDown[u] )
end

#--- add_load_balance_constraint!: This function creates the load balance constraint ---
function add_load_balance_constraint!( model::JuMP.Model , case::Case , generators::Gencos , circuits::Circuits , demands::Demands )

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local u::Int                                                    # Local variable to loop over generators
    local l::Int                                                    # Local variable to loop over lines
    local b::Int                                                    # Local variable to loop over buses
    local d::Int                                                    # Local variable to loop over demands

    local g::Array{JuMP.Variable,2}                                 # Local variable to represent generation decision variable
    local f::Array{JuMP.Variable,2}                                 # Local variable to represent flow decision variable
    local delta::Array{JuMP.Variable,2}                                 # Local variable to represent deficit variable

    local load_balance::Array{JuMP.ConstraintRef,2}                 # Local variable to represent load balance constraint reference

    #- Assigning values

    g     = model[:g]
    f     = model[:f]
    delta = model[:delta]

    #-----------------------------------------
    #---  Adding constraints in the model  ---
    #-----------------------------------------

    @constraint(model, load_balance[b=1:case.nBus, c=1:(case.nContScen+1)], 
    + sum(g[u,c] for u in 1:case.nGen if generators.Bus[u] == b) 
    + sum(f[l,c] for l in 1:case.nCir if circuits.BusTo[l] == b)
    - sum(f[l,c] for l in 1:case.nCir if circuits.BusFrom[l] == b)
    ==  sum(demands.Dem[d] for d in 1:case.nDem if demands.Bus[d] == b) 
    )
    
end

#--- add_contingency_constraint!: this function creates the contingency constraint
function add_contingency_constraint!( model::JuMP.Model , case::Case , generators::Gencos )
    
    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local u::Int                                    # Local variable to loop over generators
    
    local g::Array{JuMP.Variable,2}                 # Local variable to represent generation decision variable
    local resup::Array{JuMP.Variable,1}             # Local variable to represent reserve up decision variable
    local resdown::Array{JuMP.Variable,1}           # Local variable to represent reserve down decision variable
    local ag::Array{Int,2}                          # Local variable to represent contingency variable
    
    #- Assigning values

    g = model[:g]
    ag = case.ag

    if case.Flag_Res == 1
        resup   = model[:resup]
        resdown = model[:resdown]
    end
    
    #-----------------------------------------
    #---  Adding constraints in the model  ---
    #-----------------------------------------
    @constraint(model, cont_max_gen[u=1:case.nGen,c=2:(case.nContScen+1)],   g[u,c] <= (g[u,1] + resup[u])*ag[u,c])
    
    @constraint(model, cont_min_gen[u=1:case.nGen,c=2:(case.nContScen+1)], (g[u,1] - resdown[u])*ag[u,c] <= g[u,c]) 
end

#--- add_obj_fun!: This function creates and append the objective function to the model ---
function add_obj_fun!( model::JuMP.Model , case::Case , generators::Gencos )

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local u::Int                                                    # Local variable to loop over generators
    
    local g::Array{JuMP.Variable,2}                                 # Local variable to represent generation decision variable
    local resup::Array{JuMP.Variable,1}                               # Local variable to represent reserve up decision variable
    local resdown::Array{JuMP.Variable,1}                             # Local variable to represent reserve down decision variable

    local obj_fun::JuMP.GenericAffExpr{Float64,JuMP.Variable}       # Local variable to represent objective function
    local syst_cost::JuMP.GenericAffExpr{Float64,JuMP.Variable}     # Local variable to represent system total cost
    
    #- Assigning values

    g = model[:g]

    if case.Flag_Res == 1
        resup   = model[:resup]
        resdown = model[:resdown]
    end

    #-----------------------------------
    #---  Adding objective function  ---
    #-----------------------------------

    obj_fun = 0

    if case.Flag_Res == 1
        @objective(  model , Min       , 
        + sum(g[u,1] * generators.CVU[u] for u in 1:case.nGen)
        + sum(resup[u] * generators.ReserveUpCost[u] for u in 1:case.nGen)
        + sum(resdown[u] * generators.ReserveDownCost[u] for u in 1:case.nGen)
        )
    else
        @objective(  model , Min       , 
        + sum(g[u,1] * generators.CVU[u] for u in 1:case.nGen)
        )
    end

    nothing
end

#--- solve_dispatch: This function calls the solver and write output into .log file ---
function solve_dispatch( path::String , model::JuMP.Model , case::Case , circuits::Circuits , generators::Gencos , buses::Buses )

    #---------------------------
    #---  Defining variables ---
    #---------------------------

    local b::Int                            # Local variable to loop over buses
    local u::Int                            # Local variable to loop over generators
    local l::Int                            # Local variable to loop over lines

    local status::Symbol                    # Local variable to represent optmization status

    local prices::Array{Float64}            # Local variable to buffer dual variable (prices) after optmization
    local generation::Array{Float64}        # Local variable to buffer optimal generation
    local cir_flow::Array{Float64}          # Local variable to buffer optimal circuit flow
    local res_up_gen::Array{Float64}        # Local variable to buffer optimal up reserve
    local res_down_gen::Array{Float64}      # Local variable to buffer optimal down reserve
    local bus_ang::Array{Float64}           # Local variable to buffer optimal angle diff


    #--- Creating optmization problem
    JuMP.build( model );

    #--- Solving optmization problem
    status = JuMP.solve( model );

    #--- Reporting results
    if status  == :Optimal

        prices = getdual(getindex(model, :load_balance))
        generation = getvalue( model, :g )
        cir_flow   = getvalue( model, :f )

        if case.Flag_Res == 1
            res_up_gen   = getvalue( model, :resup )
            res_down_gen = getvalue( model, :resdown )
        end
        
        if case.Flag_Ang == 1
            bus_ang = getvalue( model, :theta )
        end

        #--- Writing to log the optimal solution

        w_Log("\n     Optimal solution found!\n" , path )

        for b in 1:case.nBus
            w_Log("     Marginal cost for the bus $(buses.Name[b]): $(round(sum(prices[b,:]),2)) R\$/MWh" , path )
        end

        w_Log( " " , path )

        for u in 1:case.nGen
            w_Log("     Optimal generation of $(generators.Name[u]): $(round(generation[u,1],2)) MWh" , path )
        end

        w_Log( " " , path )

        for l in 1:case.nCir
            w_Log("     Optimal flow in line $(circuits.Name[l]): $(round(cir_flow[l,1],2)) MW" , path )
        end

        if case.Flag_Res == 1

            w_Log( " " , path )

            for u in 1:case.nGen
                w_Log("     Optimal Reserve Up of $(generators.Name[u]): $(round(res_up_gen[u],2)) MWh" , path )
            end

            w_Log( " " , path )

            for u in 1:case.nGen
                w_Log("     Optimal Reserve Down of $(generators.Name[u]): $(round(res_down_gen[u],2)) MWh" , path )
            end

        end

        if case.Flag_Ang == 1
            
            w_Log( " " , path )

            for b in 1:case.nBus
                w_Log("     Optimal bus angle $(buses.Name[b]): $(round(bus_ang[b,1],2)) grad" , path )
            end
        end
    

    defcit = getvalue( model, :delta )
    w_Log("\n    Total cost = $(round(getobjectivevalue(model)/1000,2)) k\$" ,  path)

    elseif status == :Infeasible
        
        w_Log("\n     No solution found!\n\n     This problem is Infeasible!" , path )
        # w_Log("\n     $(case.ag)" , path )
        # w_Log("\n     $(case.al)" , path )
    end

end

#--- build_dispatch: This function call all other functions associate with the dispatch optmization problem ---
function build_dispatch( path::String , case:: Case, circuits::Circuits , generators::Gencos , demands::Demands , buses::Buses )
    
    #--- Creating constraint ref
    CONSTR = Constr()

    #---- Set number of contingency scenarios ----
    case.nContScen, case.ag, case.al = get_contingency_scenarios( case )

    #--- Creating optmization problem
    MODEL = create_model( case )

    #- Add grid constraints
    add_grid_constraint!(  MODEL , case , circuits )

    #- Add angle lag constraints

    if case.Flag_Ang == 1
        add_angle_constraint!( MODEL , case , circuits )
    end

    #- Add maximum and minimum generation constraints
    add_gen_constraint!( MODEL , case , generators )

    #- Add maximum and minimum reserve constraints

    if case.Flag_Res == 1
        add_reserve_constraint!( MODEL , case , generators )
    end

    #- Add load balance constraints
    add_load_balance_constraint!( MODEL , case , generators , circuits , demands )

    if case.Flag_Cont!=0
        add_contingency_constraint!(  MODEL , case , generators)
    end
    #- Add objetive function
    add_obj_fun!( MODEL , case , generators )

    #- Writing LP
    writeLP(MODEL, joinpath( path , "dispatch.lp") , genericnames = false)

    #- Build and solve optmization problem
    solve_dispatch( path , MODEL , case , circuits , generators , buses )
end

#------------------------------------------
#----           Main function          ----
#------------------------------------------

function dispatch( path::String )
    
    PATH_CASE = get_paths( path );

    #--- Remove preveous log file ---
    if isfile( joinpath( PATH_CASE , "dispatch.log" ) )
        rm( joinpath( PATH_CASE , "dispatch.log" ) )
    else
        w_Log( "" , PATH_CASE , 0 , 1 , "dispatch.log" , "w" )
    end

    w_Log( "\n  #-----------------------------------------#"            , PATH_CASE );
    w_Log( "  #              DISPATCH MODEL             #"              , PATH_CASE );
    w_Log( "  #-----------------------------------------#\n"            , PATH_CASE );
    w_Log( "  Execution date: $(Dates.format(now(),"dd-u-yyyy HH:MM"))" , PATH_CASE );
    w_Log( "  Directory:      $PATH_CASE \n"                            , PATH_CASE );

    #--------------------------------
    #----     Loading inputs     ----
    #--------------------------------

    w_Log( "  Loading inputs" , PATH_CASE );

    time_counter = @elapsed ( CASE , GENCOS , DEMANDS , CIRCUITS , BUSES ) = read_data_base( PATH_CASE );

    w_Log( "\n  Loading data took $(round(time_counter,3)) seconds\n" , PATH_CASE );

    #--------------------------------------------------
    #----     Solving optimal dispatch problem     ----
    #--------------------------------------------------

    w_Log( "  Solving dispatch problem" , PATH_CASE );

    time_counter = @elapsed build_dispatch( PATH_CASE , CASE , CIRCUITS , GENCOS , DEMANDS , BUSES );

    w_Log( "\n  Optmization process took $(round(time_counter,3)) seconds" , PATH_CASE );

end