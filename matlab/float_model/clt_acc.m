%% clt_acc.m — Central Limit Theorem Accumulator (floating-point reference)
%
% Tích lũy A samples Box-Muller → 1 sample output.
% Theo Boutillon ICECS'00:
%   BM_A = Σ_{i=0}^{A-1} BM_1[i]
%   mean(BM_A) ≈ 0 (float mode)
%   std(BM_A)  = √A
%
% Sau đó normalize → N(0,1):
%   output = BM_A / √A
%
% Usage:
%   y = clt_acc(x, A)
%   - x:  Nx1 vector Gaussian (từ box_muller)
%   - A:  số samples tích lũy (mặc định 4)
%   - y:  (N/A)x1 vector, xấp xỉ N(0,1) tốt hơn x
%
% Author: [Tên bạn]
% Date:   2026-05-20
% Ref:    Boutillon ICECS'00, eq.(9),(10)

function y = clt_acc(x, A)
    if nargin < 2
        A = 4;
    end
    
    N = length(x);
    assert(mod(N, A) == 0, 'Chiều dài x phải chia hết cho A=%d', A);
    
    M = N / A;  % số output samples
    
    % Reshape → A hàng × M cột, sum theo cột
    x_reshaped = reshape(x, A, M);
    y_sum = sum(x_reshaped, 1)';   % Mx1
    
    % Normalize: std(y_sum) = √A → chia √A để về N(0,1)
    y = y_sum / sqrt(A);
end
