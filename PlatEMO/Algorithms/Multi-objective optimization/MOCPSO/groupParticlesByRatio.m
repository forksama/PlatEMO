function [Winner, Loser1, Loser2] = groupParticlesByRatio(Population, FitValue, ratio)
% groupParticlesByRatio - 按比例对粒子进行分组
%
% 根据给定的比例(ratio)将粒子分为Winner, Loser1, Loser2三组
% 方法：将粒子分成若干批次，每批次按适应度排序后按比例分配
%
% 输入：
%   Population - SOLUTION对象数组
%   FitValue   - 粒子适应度值 (N x 1)
%   ratio      - 分组比例 [a, b, c]，表示 Winner:Loser1:Loser2 = a:b:c
%
% 输出：
%   Winner  - Winner组粒子索引
%   Loser1  - Loser1组粒子索引
%   Loser2  - Loser2组粒子索引
%
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    N = length(Population);
    a = ratio(1);  % Winner比例
    b = ratio(2);  % Loser1比例
    c = ratio(3);  % Loser2比例
    totalRatio = a + b + c;
    
    % 计算可用粒子数（能被totalRatio整除）
    numUsable = floor(N / totalRatio) * totalRatio;
    
    % 随机打乱粒子索引
    shuffledIdx = randperm(N, numUsable);
    
    % 计算每批次的大小
    batchSize = totalRatio;
    numBatches = numUsable / batchSize;
    
    % 初始化三个组的索引数组
    Winner = [];
    Loser1 = [];
    Loser2 = [];
    
    % 对每个批次进行排序和分配
    for batchIdx = 1:numBatches
        % 获取当前批次的粒子索引
        startIdx = (batchIdx - 1) * batchSize + 1;
        endIdx = batchIdx * batchSize;
        batchParticles = shuffledIdx(startIdx:endIdx);
        
        % 获取当前批次粒子的适应度
        batchFitness = FitValue(batchParticles);
        
        % 按适应度降序排序（适应度越大越好）
        [~, sortedOrder] = sort(batchFitness, 'descend');
        sortedBatchParticles = batchParticles(sortedOrder);
        
        % 按比例分配到三个组
        % Winner: 前a个（适应度最高）
        Winner = [Winner, sortedBatchParticles(1:a)];
        % Loser1: 中间b个（适应度中等）
        Loser1 = [Loser1, sortedBatchParticles(a+1:a+b)];
        % Loser2: 最后c个（适应度最低）
        Loser2 = [Loser2, sortedBatchParticles(a+b+1:a+b+c)];
    end
    
end
