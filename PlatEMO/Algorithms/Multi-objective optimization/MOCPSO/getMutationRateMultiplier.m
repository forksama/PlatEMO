function multiplier = getMutationRateMultiplier(t)
% getMutationRateMultiplier - 根据迭代进度计算变异率乘数
%
% 输入:
%   t - 迭代进度 (0~1), 通常为 Problem.FE / Problem.maxFE
%
% 输出:
%   multiplier - 变异率乘数
%
% 动态策略:
%   0-20%:    multiplier = 2.0   (强化探索)
%   20-40%:   multiplier = 1.5
%   40-60%:   multiplier = 1.0   (标准)
%   60-80%:   multiplier = 0.75
%   80-100%:  multiplier = 0.5   (强化收敛)
%
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    if t < 0.2
        % 前20%：强化探索
        multiplier = 2.0;
    elseif t < 0.4
        % 20-40%：较强探索
        multiplier = 1.5;
    elseif t < 0.6
        % 40-60%：标准
        multiplier = 1.0;
    elseif t < 0.8
        % 60-80%：开始收敛
        multiplier = 0.75;
    else
        % 80-100%：强化收敛
        multiplier = 0.5;
    end
end
