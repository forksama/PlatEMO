function [E_k, Range, W, center, guideIdx] = calculateDimensionExploration(Population, selectGuide)
% calculateDimensionExploration - 计算种群中每个粒子的维度探索贡献度
%
% 基于以下公式：
%   Range_j = max(x_k,j) - min(x_k,j)  维度j的探索范围
%   W_j = Range_j / sum(Range_i)       维度j的归一化探索度
%   E_k = sum((1-W_j) * |x_k,j - x_center,j|)  粒子k的维度探索贡献
%
% 输入：
%   Population   - SOLUTION对象数组或包含.decs属性的种群
%   selectGuide  - 可选，是否选择引导粒子（默认true）
%
% 输出：
%   E_k      - 每个粒子的维度探索贡献度 (N x 1向量)
%   Range    - 每个维度的探索范围 (1 x D向量)
%   W        - 每个维度的归一化探索度 (1 x D向量)
%   center   - 粒子群中心位置 (1 x D向量)
%   guideIdx - 被选中的引导粒子索引（仅当selectGuide=true时返回）
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
    if nargin < 2
        selectGuide = true;
    end
    
    % 提取决策变量矩阵
    if isa(Population, 'SOLUTION')
        PopDec = Population.decs;
        % 检查是否有 cons 属性（使用 all 确保返回标量）
        hasCons = all(isprop(Population, 'cons')) && ~isempty(Population(1).cons);
        if hasCons
            % 计算每个粒子的约束违反度（CV）
            CV = sum(max(0, Population.cons), 2);
        else
            CV = zeros(size(PopDec, 1), 1);
        end
    else
        PopDec = Population;
        CV = zeros(size(PopDec, 1), 1);
    end
    
    [N, D] = size(PopDec);
    
    % 检查种群是否为空
    if N == 0
        E_k = [];
        Range = [];
        W = [];
        center = [];
        guideIdx = [];
        return;
    end
    
    %% 公式1: 计算每个维度的探索范围 Range_j
    % Range_j = max(x_k,j) - min(x_k,j)  对所有 k ∈ S
    Range = max(PopDec, [], 1) - min(PopDec, [], 1);  % 1 x D
    
    %% 公式2: 计算每个维度的归一化探索度 W_j
    % W_j = Range_j / sum(Range_i)
    % W_j 越大，表示该维度已被充分探索
    % W_j 越小，表示该维度探索不足
    sumRange = sum(Range);
    if sumRange > 0
        W = Range / sumRange;  % 1 x D
    else
        % 如果所有维度范围都为0（所有粒子在同一位置）
        W = ones(1, D) / D;
    end
    
    %% 计算粒子群中心
    % x_center,j = mean(x_k,j) 对所有 k
    center = mean(PopDec, 1);  % 1 x D
    
    %% 公式3: 计算每个粒子的维度探索贡献度 E_k
    % E_k = sum((1-W_j) * |x_k,j - x_center,j|)
    % 
    % 解释：
    % - (1-W_j) 越大，表示维度j探索不足
    % - |x_k,j - x_center,j| 越大，表示粒子k在维度j上偏离中心
    % - 因此，E_k 越高，表示粒子k在探索不足的维度上偏离中心，探索贡献大
    
    % 计算每个粒子在每个维度上偏离中心的距离
    deviation = abs(PopDec - repmat(center, N, 1));  % N x D
    
    % 加权求和：探索不足的维度权重更高
    oneMinusW = 1 - W;  % 1 x D
    E_k = sum(deviation .* repmat(oneMinusW, N, 1), 2);  % N x 1
    
    % 归一化 E_k 到 [0, 1] 范围
    if max(E_k) > min(E_k)
        E_k_normalized = (E_k - min(E_k)) / (max(E_k) - min(E_k));
    else
        E_k_normalized = zeros(N, 1);
    end
    
    E_k = E_k_normalized;  % 返回归一化的E_k
    
    %% 选择引导粒子
    if selectGuide
        % 质量筛选：优先从可行解中选择，如果可行解不足则选择低CV的粒子
        feasibleIdx = find(CV == 0);
        
        if length(feasibleIdx) >= max(1, floor(N * 0.3))
            % 可行解充足，从可行解中基于E_k选择
            candidateIdx = feasibleIdx;
        else
            % 可行解不足，保留约束违反度最小的50%粒子
            [~, sortedIdx] = sort(CV);
            candidateIdx = sortedIdx(1:max(1, floor(N * 0.5)));
        end
        
        % 候选粒子的E_k值
        E_k_candidate = E_k(candidateIdx);
        
        % 基于E_k的概率选择（E_k越高，被选中概率越大）
        if sum(E_k_candidate) > 0
            prob = E_k_candidate / sum(E_k_candidate);
        else
            prob = ones(length(candidateIdx), 1) / length(candidateIdx);
        end
        
        % 从候选粒子中选择引导粒子
        selectedLocalIdx = randsample(1:length(candidateIdx), 1, true, prob);
        guideIdx = candidateIdx(selectedLocalIdx);
    else
        guideIdx = [];
    end
    
end
