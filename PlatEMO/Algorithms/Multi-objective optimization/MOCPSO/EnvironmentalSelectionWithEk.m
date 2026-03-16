function Population = EnvironmentalSelectionWithEk(Population, V, theta, lambda, forceFeasible)
% EnvironmentalSelectionWithEk - 基于维度探索贡献的环境选择
%
% 将维度探索贡献度 E_k 作为奖励因子融入 APD 计算：
%   APD_k = (1 + tau_k) * d_k / (1 + lambda * E_k)
%
% 其中：
%   tau_k = M * theta * Angle_k / gamma  (角度惩罚项)
%   d_k = sqrt(sum(PopObj_k.^2))         (距离项，收敛性)
%   E_k = 维度探索贡献度                   (奖励因子)
%   lambda = E_k的影响权重
%
% 解释：
%   - E_k 越高，分母越大，APD 越小，越容易被选中
%   - 这样可以保护那些在稀疏维度上探索成功的粒子
%
% 输入参数：
%   Population   - SOLUTION对象数组
%   V            - 参考向量矩阵 (NV x M)
%   theta        - APD参数，控制角度惩罚程度
%   lambda       - E_k影响权重 (0~1，默认0.5)
%   forceFeasible - 可选，已废弃
%
% 输出：
%   Population   - 选择后的种群
%
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 参数处理
    if nargin < 4 || isempty(lambda)
        lambda = 0.5;  % 默认E_k权重
    end
    if nargin < 5
        forceFeasible = false;
    end
    
    % 检查输入种群是否为空
    if isempty(Population)
        warning('EnvironmentalSelectionWithEk: 输入种群为空');
        return;
    end
    
    PopObj = Population.objs;
    [N, M] = size(PopObj);
    NV = size(V, 1);
    
    %% Translate the population (平移到理想点)
    PopObj = PopObj - repmat(min(PopObj, [], 1), N, 1);
    
    %% Calculate the degree of violation of each solution (约束违反度)
    CV = sum(max(0, Population.cons), 2);
    
    %% Calculate the smallest angle value between each vector and others
    cosine = 1 - pdist2(V, V, 'cosine');
    cosine(logical(eye(length(cosine)))) = 0;
    gamma = min(acos(cosine), [], 2);
    
    %% Associate each solution to a reference vector
    Angle = acos(1 - pdist2(PopObj, V, 'cosine'));
    [~, associate] = min(Angle, [], 2);
    
    %% ========== 新增：计算维度探索贡献度 E_k ==========
    E_k = calculateDimensionExploration(Population);  % N x 1
    
    %% Select one solution for each reference vector
    % 只从可行解中筛选参考向量的对应解
    Next = zeros(1, NV);
    
    for i = unique(associate)'
        % 只考虑可行解（CV==0）
        current = find(associate == i & CV == 0);
        
        if ~isempty(current)
            %% 原始APD计算
            % tau_k = M * theta * Angle_k / gamma
            tau = M * theta * Angle(current, i) / gamma(i);
            
            % d_k = sqrt(sum(PopObj_k.^2)) (到理想点的距离)
            d = sqrt(sum(PopObj(current, :).^2, 2));
            
            %% 新的APD公式：将E_k作为奖励因子
            % APD_k = (1 + tau_k) * d_k / (1 + lambda * E_k)
            % E_k 越高，分母越大，APD 越小，越容易被选中
            APD = (1 + tau) .* d ./ (1 + lambda * E_k(current));
            
            % Select the one with the minimum APD value
            [~, best] = min(APD);
            Next(i) = current(best);
        end
        % 如果某个参考向量没有对应的可行解，则Next(i)保持为0
    end
    
    % Population for next generation
    Population = Population(Next(Next ~= 0));
    
end
