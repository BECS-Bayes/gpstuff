function eloo = gpep_looe(w, gp, x, y, varargin)
% GPEP_LOOE Evaluate the mean negative log leave-one-out predictive 
%           density, assuming Gaussian observation model.
%
%  Description
%    LOOE = GPEP_LOOE(W, GP, X, Y, OPTIONS) takes a parameter
%    vector W, Gaussian process structure GP, a matrix X of input
%    vectors and a matrix Y of targets, and evaluates the mean
%    negative log leave-one-out predictive density
%      LOOE = - 1/n sum log p(Y_i | X, Y_{\i}, th) 
%    where th represents the parameters (lengthScale,
%    magnSigma2...), X is inputs and Y is observations.
%
%    EP leave-one-out is approximated by leaving-out site-term and
%    using cavity distribution as leave-one-out posterior for the
%    ith latent value.
%
%    OPTIONS is optional parameter-value pair
%      z - optional observed quantity in triplet (x_i,y_i,z_i)
%          Some likelihoods may use this. For example, in case of
%          Poisson likelihood we have z_i=E_i, that is, expected
%          value for ith case.
%
%  See also
%    GP_LOOE, GPEP_LOOPRED, GPEP_E
%

% Copyright (c) 2010 Aki Vehtari

% This software is distributed under the GNU General Public
% License (version 2 or later); please refer to the file
% License.txt, included with the software, for details.

gp=gp_unpak(gp, w);
ncf = length(gp.cf);
n=length(x);

ip=inputParser;
ip.FunctionName = 'GPEP_LOOE';
ip.addRequired('w', @(x) isempty(x) || ...
               isvector(x) && isreal(x) && all(isfinite(x)));
ip.addRequired('gp', @(x) isstruct(x) || iscell(x));
ip.addRequired('x', @(x) ~isempty(x) && isreal(x) && all(isfinite(x(:))))
ip.addRequired('y', @(x) ~isempty(x) && isreal(x) && all(isfinite(x(:))))
ip.addParamValue('z', [], @(x) isreal(x) && all(isfinite(x(:))))
ip.parse(w, gp, x, y, varargin{:});
z=ip.Results.z;

[~,~,~,~,~,~,~,~,~,~,Z_i] = gpep_e(gp_pak(gp), gp, x, y, 'z', z);
eloo=-mean(log(Z_i));