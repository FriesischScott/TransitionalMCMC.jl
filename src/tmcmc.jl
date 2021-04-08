###
#   An implmentation of Transitional Markov Chain Monte Carlo in Julia
#
#            Institute for Risk and Uncertainty, Uni of Liverpool
#
#                       Authors: Ander Gray, Adolphus Lye
#
#                       Email: Ander.Gray@liverpool.ac.uk, 
#                              Adolphus.Lye@liverpool.ac.uk
#
#
#   This Transitional MCMC algorithm is inspirted by OpenCOSSAN: 
#                   https://github.com/cossan-working-group/OpenCossan
#
#
#   Algorithm originally proposed by: 
#           J. Ching, and Y. Chen (2007). Transitional Markov Chain Monte Carlo method 
#           for Bayesian model updating, Model class selection, and Model averaging. 
#           Journal of Engineering Mechanics, 133(7), 816-832. 
#           doi:10.1061/(asce)0733-9399(2007)133:7(816)
#
###

function tmcmc(log_fD_T, fT, sample_fT, Nsamples, burnin= 20, thin=3, beta2 = 0.01)

    j1 = 0;                     # Iteration number
    βj = 0;                     # Tempering parameter
    θ_j = sample_fT(Nsamples);  # Samples of prior
    Lp_j = zeros(Nsamples,1);   # Log liklihood of first iteration

    Log_ev = 0                  # Log Evidence

    Ndims = size(θ_j,2)         # Number of dimensions (input)
    

    while βj < 1

        j1 = j1 + 1
        println()
        println("Beginning iteration $j1")

        ###
        # Compute likelihood values (to be parallelised)
        ###
        print("Computing likelihood of samples....")
        Lp_j = log_fD_T(θ_j')                         
        #Lp_j = pamp(log_fD_T,θ_j')                         
        println("Done!")

        ###
        #   Computing new βj
        #   Uses bisection method
        ###
        println("Computing Bj")

        low_β = βj; hi_β = 2; Lp_adjust = maximum(Lp_j);
        x1 = (hi_β + low_β)/2;

        while (hi_β - low_β)/((hi_β + low_β)/2) > 1e-6
            x1 = (hi_β + low_β)/2;
            wj_test = exp.((x1 .- βj ) .* (Lp_j .- Lp_adjust));
            cov_w   = std(wj_test)/mean(wj_test);
            if cov_w > 1; hi_β = x1; else; low_β = x1; end
        end
        
        βj1 = min(1,x1)
        println("B_$(j1) = $(βj1)")

        ###
        #   Computation of normalised weights
        ###
        println("Computing weights")

        w_j = exp.((βj1 - βj) .* (Lp_j .- Lp_adjust))       # Nominal weights from likilhood and βjs

        Log_ev = log(mean(w_j)) + (βj1 - βj) * Lp_adjust + Log_ev   # Log evidence in current iteration
        
        # Normalised weights
        wn_j = w_j ./sum(w_j);

        Th_wm = θ_j .* wn_j                 # Weighted mean of samples

        ###
        #   Calculation of COV matrix of proposal
        ###
        SIGMA_j = zeros(Ndims, Ndims)
        
        for l = 1:Nsamples
            SIGMA_j = SIGMA_j + beta2 .* wn_j[l] .* (θ_j[l,:]' .- Th_wm)' * (θ_j[l,:]' .- Th_wm)
        end
        
        # Ensure that cov is symetric
        SIGMA_j = (SIGMA_j' + SIGMA_j)/2

        prop = mu -> proprnd(mu, SIGMA_j, fT)           # Anonymous function for proposal

        target = x -> log_fD_T(x) .* βj1 .+ log.(fT(x)) # Anonymous function for transitional distribution

        # Weighted resampling of θj (indecies with replacement)
        randIndex = sample(1:Nsamples, Weights(wn_j), Nsamples, replace=true)

        θ_j1 = zeros(Nsamples, Ndims)
        α = zeros(Nsamples)                 # acceptance rates

        print("Markov chains...")
        for i = 1:Nsamples
            samps, αs = MHsampleSimple(target, prop, θ_j[randIndex[i], :], 1, burnin, thin)
            θ_j1[i,:] = samps
            α[i] = αs
        end
        println("Done!")
        meanα = mean(α)

        #println("Mean α = $(meanα)")
        
        βj = βj1
        θ_j = θ_j1
    end
    return θ_j, Log_ev
end

function proprnd(mu, covMat, prior)

    samp = rand(MvNormal(mu, covMat), 1)
    while iszero(prior(samp))
        samp = rand(MvNormal(mu, covMat),1)
    end
    return samp[:]
end
