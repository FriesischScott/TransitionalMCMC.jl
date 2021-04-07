using PyPlot

lb  = -15
ub  = 15

prior(x) = pdf(Uniform(lb,ub), x[1,:]) .* pdf(Uniform(lb,ub), x[2,:])
priorRnd(Nsamples) = rand(Uniform(lb,ub), 2, Nsamples)

function LogLik(x)
    return log.(pdf(MvNormal([0,0],[1 -0.5; -0.5 1]), x))
end

Nsamples = 2000


samps, acc = tmcmc(LogLik, prior, priorRnd, Nsamples)

plt.scatter(samps[1,:], samps[2,:])