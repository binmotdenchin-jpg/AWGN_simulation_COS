%% taus_urng.m — Combined Tausworthe URNG (L'Ecuyer taus88)
%
% Port từ C code: L'Ecuyer, "Maximally Equidistributed Combined
% Tausworthe Generators," Math. Comp., vol.65, no.213, pp.203-213, 1996.
%
% 3-component combined generator:
%   P1: k=31, q=13, s_shift=(13,19,12), mask=0xFFFFFFFE
%   P2: k=29, q=2,  s_shift=(2,25,4),   mask=0xFFFFFFF8
%   P3: k=28, q=3,  s_shift=(3,11,17),  mask=0xFFFFFFF0
%
% Period ≈ 2^88
%
% Usage:
%   [samples, state] = taus_urng(N, seed)
%   - N:     số samples cần sinh
%   - seed:  [s1, s2, s3] (uint32), s1>1, s2>7, s3>15
%   - samples: Nx1 vector, uniform trong [0, 1)
%   - state:   [s1, s2, s3] cuối cùng (để tiếp tục sinh)
%
% Ví dụ:
%   [u, st] = taus_urng(1e6, [uint32(12345), uint32(67891), uint32(11213)]);
%   histogram(u, 100);  % kỳ vọng uniform
%
% Author: [Tên bạn]
% Date:   2026-05-20
% Ref:    L'Ecuyer 1996, Fig.1

function [samples, state] = taus_urng(N, seed)
    % Validate seed
    assert(numel(seed) == 3, 'Seed phải có 3 phần tử [s1, s2, s3]');
    s1 = uint32(seed(1));
    s2 = uint32(seed(2));
    s3 = uint32(seed(3));
    assert(s1 > 1,  's1 phải > 1');
    assert(s2 > 7,  's2 phải > 7');
    assert(s3 > 15, 's3 phải > 15');
    
    samples = zeros(N, 1);
    SCALE = 2.3283064365386963e-10;  % 1 / 2^32
    
    for i = 1:N
        % Component 1: k=31, q=13
        b  = bitxor(bitshift(s1, 13), s1);
        b  = bitshift(b, -19);
        s1 = bitxor(bitshift(bitand(s1, uint32(4294967294)), 12), b);
        
        % Component 2: k=29, q=2
        b  = bitxor(bitshift(s2, 2), s2);
        b  = bitshift(b, -25);
        s2 = bitxor(bitshift(bitand(s2, uint32(4294967288)), 4), b);
        
        % Component 3: k=28, q=3
        b  = bitxor(bitshift(s3, 3), s3);
        b  = bitshift(b, -11);
        s3 = bitxor(bitshift(bitand(s3, uint32(4294967280)), 17), b);
        
        % Combined output
        combined = bitxor(bitxor(s1, s2), s3);
        samples(i) = double(combined) * SCALE;
    end
    
    state = [s1, s2, s3];
end
