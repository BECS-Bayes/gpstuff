%DEMO_MULTICLASS  Classification problem demonstration for 3 classes
%                 using Gaussian process prior
%
%  Description
%    The data used in the demonstration program is the same used by
%    Radford M. Neal in his three-way classification example in
%    Software for Flexible Bayesian Modeling
%    (http://www.cs.toronto.edu/~radford/fbm.software.html) The
%    data consists of 1000 4-D vectors which are classified into
%    three classes. The data is generated by drawing the components
%    of vector, x1, x2, x3 and x4, uniformly form (0,1). The class
%    of each vector is selected according to the first two
%    components of the vector, x_1 and x_2. After this a Gaussian
%    noise with standard deviation of 0.1 has been added to every
%    component of the vector. Because there are two irrelevant
%    components in the input vector a prior with ARD should be of
%    help.
%
%    The data is divided into two parts, trainig set of 400 units
%    and test set of 600 units.
%
%    The latent values for N training points and C classes are
%    f=(f1_1,f2_1,...,fN_1,f1_2,f2_2,...,fN_2,...,f1_C,f2_C,...,fN_C)^T,
%    and are given a zero mean Gaussian process prior
%      
%      f ~ N(0, K),
%
%    where K is a block diagonal covariance matrix with blocks
%    K_1,...,K_C whose elements are given by K_ij = k(x_i, x_j |
%    th). The function k(x_i, x_j | th) is covariance function and
%    th its parameters.
%
%    In this demo we approximate the posterior distribution with
%    Laplace approximation.
%

% Copyright (c) 2010 Jaakko Riihim�ki, Jarno Vanhatalo, Aki Vehtari

% This software is distributed under the GNU General Public 
% License (version 2 or later); please refer to the file 
% License.txt, included with the software, for details.

% Load the data
S = which('demo_multiclass');
L = strrep(S,'demo_multiclass.m','demos/cdata.txt');
x=load(L);
y=repmat(0,size(x,1),3);
y(x(:,5)==0,1) = 1;
y(x(:,5)==1,2) = 1;
y(x(:,5)==2,3) = 1;
x(:,end)=[];

% Divide the data into training and test parts.
xt = x(401:end,:);
x=x(1:400,:);
yt=y(401:end,:);
y=y(1:400,:);

[n, nin] = size(x);

% Create covariance functions
gpcf1 = gpcf_sexp('lengthScale', ones(1,nin), 'magnSigma2', 1);
% Set the prior for the parameters of covariance functions
pl = prior_t('s2',10,'nu',10);
pm = prior_sqrtt('s2',10,'nu',10);
gpcf1 = gpcf_sexp(gpcf1, 'lengthScale_prior', pl,'magnSigma2_prior', pm);

% Create the GP structure
gp = gp_set('lik', lik_softmax2, 'cf', {gpcf1}, 'jitterSigma2', 1e-2);

% ------- Laplace approximation --------
fprintf(['Softmax model with Laplace integration over the latent\n' ...
         'values and MAP estimate for the parameters\n'])

% Set the approximate inference method
gp = gp_set(gp, 'latent_method', 'Laplace');
[Eft, Varft, lpyt] = gp_pred(gp, x, y, xt, 'yt', ones(size(yt)));

% gp2 = gp_set('lik', lik_softmax2, 'cf', {gpcf1 gpcf1 gpcf1}, 'jitterSigma2', 1e-2);
% gp2 = gp_set(gp2, 'latent_method', 'Laplace');
% gp2.comp_cf = {1 2 3};
% [Eft2, Varft2, ~, ~, pyt2] = gp_pred(gp2, x, y, xt, 'yt', ones(size(yt)));

% Set the options for the scaled conjugate optimization
opt=optimset('TolFun',1e-4,'TolX',1e-4,'Display','iter','MaxIter',100,'Derivativecheck','on');
% Optimize with the scaled conjugate gradient method
gp=gp_optim(gp,x,y,'opt',opt);

% make the prediction for test points
[Eft, Varft, lpyt] = gp_pred(gp, x, y, xt, 'yt', ones(size(yt)));

% calculate the percentage of misclassified points
tt = exp(lpyt)==repmat(max(exp(lpyt),[],2),1,size(exp(pyt),2));
missed = (sum(sum(abs(tt-yt)))/2)/size(yt,1)

% grid for making prediction
xtg1 = meshgrid(linspace(min(x(:,1))-.1, max(x(:,1))+.1, 30)); 
xtg2 = meshgrid(linspace(min(x(:,2))-.1, max(x(:,2))+.1, 30))';
xtg=[xtg1(:) xtg2(:) repmat(mean(x(:,3:4)), size(xtg1(:),1),1)];

[Eft, Covft, pg] = gp_pred(gp, x, y, xtg, 'yt', ones(size(xtg,1),3));

% plot the train data o=0, x=1
figure, set(gcf, 'color', 'w'), hold on
plot(x(y(:,1)==1,1),x(y(:,1)==1,2),'ro', 'linewidth', 2);
plot(x(y(:,2)==1,1),x(y(:,2)==1,2),'x', 'linewidth', 2);
plot(x(y(:,3)==1,1),x(y(:,3)==1,2),'kd', 'linewidth', 2);
axis([-0.4 1.4 -0.4 1.4])
contour(xtg1, xtg2, reshape(exp(pg(:,1)),30,30),'r', 'linewidth', 2)
contour(xtg1, xtg2, reshape(exp(pg(:,2)),30,30),'b', 'linewidth', 2)
contour(xtg1, xtg2, reshape(exp(pg(:,3)),30,30),'k', 'linewidth', 2)

% MCMC approach

% Set the approximate inference method
% Note that MCMC for latent values requires often more jitter
lat = gp_pred(gp, x, y, x);
gp = gp_set(gp, 'latent_method', 'MCMC', 'jitterSigma2', 1e-4);
gp = gp_set(gp, 'latent_opt', struct('method',@scaled_mh_mo));
gp.latentValues = lat(:);

gp_mo_e(gp_pak(gp), gp, x,y)
gp_mo_g(gp_pak(gp), gp, x,y)
gradcheck(randn(size(gp_pak(gp))), @gp_mo_e, @gp_mo_g, gp, x, y);

% Set the parameters for MCMC...
hmc_opt.steps=10;
hmc_opt.stepadj=0.001;
hmc_opt.nsamples=1;
latent_opt.display=0;
latent_opt.repeat = 20;
latent_opt.sample_latent_scale = 0.05;
hmc2('state', sum(100*clock))

% Sample
[r,g,opt]=gp_mo_mc(gp, x, y, 'hmc_opt', hmc_opt, 'latent_opt', latent_opt, 'nsamples', 1, 'repeat', 15);

% re-set some of the sampling options
hmc_opt.repeat=1;
hmc_opt.steps=4;
hmc_opt.stepadj=0.02;
latent_opt.repeat = 5;
hmc2('state', sum(100*clock));

% Sample 
[rgp,g,opt]=gp_mo_mc(gp, x, y, 'nsamples', 400, 'hmc_opt', hmc_opt, 'latent_opt', latent_opt, 'record', r);
% Remove burn-in
rgp=thin(rgp,102);

% Make predictions
%[Efs_mc, Varfs_mc, Eys_mc, Varys_mc, Pys_mc] = gpmc_mo_preds(rgp, x, y, xt, 'yt', ones(size(xt,1),1) );
[Efs_mc, Varfs_mc, pgs_mc] = gpmc_mo_preds(rgp, x, y, xtg, 'yt', ones(size(xtg,1),3));

Ef_mc = reshape(mean(Efs_mc,2),900,3);
pg_mc = reshape(mean(exp(pgs_mc),2),900,3);

figure, set(gcf, 'color', 'w'), hold on
plot(x(y(:,1)==1,1),x(y(:,1)==1,2),'ro', 'linewidth', 2);
plot(x(y(:,2)==1,1),x(y(:,2)==1,2),'x', 'linewidth', 2);
plot(x(y(:,3)==1,1),x(y(:,3)==1,2),'kd', 'linewidth', 2);
axis([-0.4 1.4 -0.4 1.4])
contour(xtg1, xtg2, reshape(pg_mc(:,1),30,30),'r', 'linewidth', 2)
contour(xtg1, xtg2, reshape(pg_mc(:,2),30,30),'b', 'linewidth', 2)
contour(xtg1, xtg2, reshape(pg_mc(:,3),30,30),'k', 'linewidth', 2)



% With scaled HMCS



gp2 = gp_set(gp, 'latent_opt', struct('method',@scaled_hmc_mo));
gp2.latentValues = lat(:);

% Set the parameters for MCMC...
hmc_opt.steps=10;
hmc_opt.stepadj=0.001;
hmc_opt.nsamples=1;

% latent opt
latent_opt.nsamples=1;
latent_opt.nomit=0;
latent_opt.persistence=0;
latent_opt.repeat=20;
latent_opt.steps=20;
latent_opt.stepadj=0.15;
latent_opt.window=5;

% Here we make an initialization with 
% slow sampling parameters
[rgp2,gp2,opt]=gp_mo_mc(gp2, x, y, 'hmc_opt', hmc_opt, 'latent_opt', latent_opt, 'nsamples', 1, 'repeat', 15);




hmc2('state', sum(100*clock))

% Sample
[r,g,opt]=gp_mo_mc(gp, x, y, 'hmc_opt', hmc_opt, 'latent_opt', latent_opt, 'nsamples', 1, 'repeat', 15);

% re-set some of the sampling options
hmc_opt.repeat=1;
hmc_opt.steps=4;
hmc_opt.stepadj=0.02;
latent_opt.repeat = 5;
hmc2('state', sum(100*clock));

% Sample 
[rgp,g,opt]=gp_mo_mc(gp, x, y, 'nsamples', 400, 'hmc_opt', hmc_opt, 'latent_opt', latent_opt, 'record', r);
% Remove burn-in
rgp=thin(rgp,102);

% Make predictions
%[Efs_mc, Varfs_mc, Eys_mc, Varys_mc, Pys_mc] = gpmc_mo_preds(rgp, x, y, xt, 'yt', ones(size(xt,1),1) );
[Efs_mc, Varfs_mc, ~, ~, pgs_mc] = gpmc_mo_preds(rgp, x, y, xtg, 'yt', ones(size(xtg,1),3));

Ef_mc = reshape(mean(Efs_mc,2),900,3);
pg_mc = reshape(mean(pgs_mc,2),900,3);

figure, set(gcf, 'color', 'w'), hold on
plot(x(y(:,1)==1,1),x(y(:,1)==1,2),'ro', 'linewidth', 2);
plot(x(y(:,2)==1,1),x(y(:,2)==1,2),'x', 'linewidth', 2);
plot(x(y(:,3)==1,1),x(y(:,3)==1,2),'kd', 'linewidth', 2);
axis([-0.4 1.4 -0.4 1.4])
contour(xtg1, xtg2, reshape(pg_mc(:,1),30,30),'r', 'linewidth', 2)
contour(xtg1, xtg2, reshape(pg_mc(:,2),30,30),'b', 'linewidth', 2)
contour(xtg1, xtg2, reshape(pg_mc(:,3),30,30),'k', 'linewidth', 2)


