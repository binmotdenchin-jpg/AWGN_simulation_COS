%% box_muller.m — Box-Muller Transform (floating-point reference)
%
% Biến đổi cặp (u0, u1) uniform [0,1) → (x0, x1) Gaussian N(0,1).
%
% Công thức:
%   e  = -2·ln(u0)
%   f  = √e
%   g0 = sin(2π·u1)
%   g1 = cos(2π·u1)
%   x0 = f · g0
%   x1 = f · g1
%
% Usage:
%   [x0, x1] = box_muller(u0, u1)
%   - u0, u1: Nx1 vectors, uniform (0,1) — u0 KHÔNG được = 0 (ln(0) = -Inf)
%   - x0, x1: Nx1 vectors, Gaussian N(0,1)
%
% Author: [Tên bạn]
% Date:   2026-05-20
% Ref:    Box & Muller, "A Note on the Generation of Random Normal Deviates,"
%         Annals Math. Statistics, vol.29, pp.610-611, 1958.

function [x0, x1] = box_muller(u0, u1)
    % Guard: tránh ln(0)
    u0(u0 == 0) = eps;
    
    % Radial component
    e = -2 * log(u0);          % (1)
    f = sqrt(e);                % (2)
    
    % Angular component
    theta = 2 * pi * u1;
    g0 = sin(theta);            % (3)
    g1 = cos(theta);            % (4)
    
    % Gaussian outputs
    x0 = f .* g0;               % (5)
    x1 = f .* g1;               % (6)
end
