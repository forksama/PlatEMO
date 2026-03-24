classdef MOCPSO_Ek < ALGORITHM
% <multi> <real/binary/permutation> <constrained/none>
% MOCPSO_Ek: MOCPSO with Dimension Exploration Contribution
% 
% 在原始MOCPSO基础上引入维度探索贡献机制：
% 1. Range_j = max(x_k,j) - min(x_k,j)  维度j的探索范围
% 2. W_j = Range_j / sum(Range_i)       维度j的归一化探索度
% 3. E_k = sum((1-W_j) * |x_k,j - x_center,j|)  粒子k的维度探索贡献
% 4. APD_k = (1 + tau_k) * d_k / (1 + lambda * E_k)  改进的角度惩罚距离
%
% 改进点：
% - 环境选择中使用改进的APD公式，E_k作为奖励因子
% - 从所有粒子中基于E_k选择引导粒子
% - 在DSS和CSS更新公式中加入向引导粒子的权重项
%
%------------------------------- Reference --------------------------------
% Based on: Zhang, Y., Li, B., Hong, W., & Zhou, A.
% "MOCPSO: A multi-objective cooperative particle swarm optimization algorithm 
% with dual search strategies." 
% Neurocomputing 562 (2023): 126892.
%
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------
properties
    lambda = 0.5;                 % E_k影响权重 (0~1)
    c_guide = 0.3;                % 引导粒子权重
    useDynamicGrouping = false;   % 是否使用动态分组比例
    useDynamicMutation = false;   % 是否使用动态变异率
end

methods
    function main(Algorithm, Problem)
        
        %% 参数设置
        [lambda, c_guide, useDynamicGrouping, useDynamicMutation] = Algorithm.ParameterSet(0.5, 0.3, false, false);
        Algorithm.lambda = lambda;
        Algorithm.c_guide = c_guide;
        Algorithm.useDynamicGrouping = useDynamicGrouping;
        Algorithm.useDynamicMutation = useDynamicMutation;
        
        %% Generate random population
        [V,~] = UniformPoint(Problem.N * 100, Problem.M);
        Population = Problem.Initialization();
        Population = EnvironmentalSelectionWithEk(Population, V, (Problem.FE/Problem.maxFE)^2, lambda);
        
        % 如果环境选择后种群为空，重新初始化
        maxRetries = 10;
        retryCount = 0;
        while isempty(Population) && retryCount < maxRetries
            warning('环境选择后种群为空，重新初始化（重试 %d/%d）', retryCount + 1, maxRetries);
            Population = Problem.Initialization();
            Population = EnvironmentalSelectionWithEk(Population, V, (Problem.FE/Problem.maxFE)^2, lambda);
            retryCount = retryCount + 1;
        end
        
        if isempty(Population)
            warning('重试后种群仍为空，使用所有解作为初始种群');
            Population = Problem.Initialization();
        end
        
        % 打印初始种群信息
        CV = sum(max(0, Population.cons), 2);
        numFeasible = sum(CV == 0);
        numInfeasible = sum(CV > 0);
        fprintf('初始种群: 可行解=%d, 不可行解=%d, 总计=%d\n', numFeasible, numInfeasible, length(Population));
        
        %% Optimization
        iteration = 0;
        while Algorithm.NotTerminated(Population)
            iteration = iteration + 1;
            isLastIteration = (Problem.FE >= Problem.maxFE * 0.99) || (Problem.maxFE - Problem.FE < 10);
            
            if size(Population, 2) < 3 || isempty(Population)
                % 种群为空或太小的处理
                if isempty(Population)
                    warning('迭代 %d: 种群为空，重新初始化', iteration);
                    Population = Problem.Initialization();
                    Population = EnvironmentalSelectionWithEk(Population, V, (Problem.FE/Problem.maxFE)^2, lambda, isLastIteration);
                    if isempty(Population)
                        Population = Problem.Initialization();
                    end
                end
                
                if ~isempty(Population)
                    [N,D] = size(Population.decs);
                    PopVel = Population.adds(zeros(N,D));
                    % 根据开关决定是否使用动态变异率
                    if useDynamicMutation
                        t = Problem.FE / Problem.maxFE;
                        mutationRateMultiplier = getMutationRateMultiplier(t);
                    else
                        mutationRateMultiplier = 1.0;  % 使用固定变异率
                    end
                    Offspring = Polynomial_mutation(Problem, Population.decs, PopVel, N/2, D, mutationRateMultiplier);
                    Population = EnvironmentalSelectionWithEk([Population, Offspring], V, (Problem.FE/Problem.maxFE)^2, lambda, isLastIteration);
                    
                    if isempty(Population)
                        warning('迭代 %d: 环境选择后种群为空', iteration);
                        Population = [Population, Offspring];
                    end
                else
                    warning('迭代 %d: 无法生成有效种群，跳过', iteration);
                    continue;
                end
                
                CV = sum(max(0, Population.cons), 2);
                numFeasible = sum(CV == 0);
                numInfeasible = sum(CV > 0);
                fprintf('迭代 %d (FE=%d/%d): 可行解=%d, 不可行解=%d, 总计=%d\n', ...
                    iteration, Problem.FE, Problem.maxFE, numFeasible, numInfeasible, length(Population));
                
                % ========== 修复：在continue之前检查是否需要筛选帕累托前沿 ==========
                if Problem.FE >= Problem.maxFE
                    Population = filterParetoFront(Population, iteration);
                end
                
                continue;
            end
            
            % ========== 计算适应度并分组 ==========
            FitValue = calFitness(Population.objs);
            
            % ========== 计算迭代进度 ==========
            t = Problem.FE / Problem.maxFE;
            
            % ========== 根据开关决定是否使用动态变异率 ==========
            if useDynamicMutation
                mutationRateMultiplier = getMutationRateMultiplier(t);
            else
                mutationRateMultiplier = 1.0;  % 使用固定变异率
            end
            
            if useDynamicGrouping
                % 动态分组比例方案
                if t < 0.25
                    % 0-25%: 强化多样性 (更多Winner，更多探索)
                    ratio = [2, 1, 1];
                elseif t < 0.75
                    % 25-75%: 均衡探索与收敛
                    ratio = [1, 1, 1];
                else
                    % 75-100%: 强化收敛 (更多Loser2，更多收敛学习)
                    ratio = [1, 1, 2];
                end
                
                % 使用动态分组方法
                [Winner, Loser1, Loser2] = groupParticlesByRatio(Population, FitValue, ratio);
            else
                % 原始分组方法（1:1:1 + swapWL）
                Rank = randperm(length(Population), floor((length(Population))/3)*3);
                Loser1 = Rank(1:end/3);
                Loser2 = Rank(end/3+1:end/3*2);
                Winner = Rank(end/3*2+1:end);
                [Loser1, Loser2] = swapWL(Loser1, Loser2, FitValue);
                [Winner, Loser1] = swapWL(Winner, Loser1, FitValue);
                [Loser1, Loser2] = swapWL(Loser1, Loser2, FitValue);
            end
            
            % ========== 新增：计算E_k并选择引导粒子 ==========
            [E_k, ~, ~, ~, guideIdx] = calculateDimensionExploration(Population);
            GuideDec = Population(guideIdx).decs;
            
            % 动态引导权重（前期强，后期弱）
            c_guide_dynamic = c_guide * (1 - t);
            
            % 更新操作（带引导粒子和动态变异率）
            [Offspring1, Offspring2, Offspring3] = Operator_WithGuide(Population(Loser1), Population(Loser2), Population(Winner), GuideDec, c_guide_dynamic, Problem, mutationRateMultiplier);
            
            % 环境选择（使用改进的APD公式）
            Population = EnvironmentalSelectionWithEk([Population, Offspring1, Offspring2, Offspring3], V, (Problem.FE/Problem.maxFE)^2, lambda, isLastIteration);
            
            if isempty(Population)
                warning('迭代 %d: 环境选择后种群为空', iteration);
                Population = [Population, Offspring1, Offspring2, Offspring3];
            end
            
            % 打印迭代信息
            CV = sum(max(0, Population.cons), 2);
            numFeasible = sum(CV == 0);
            numInfeasible = sum(CV > 0);
            fprintf('迭代 %d (FE=%d/%d): 可行解=%d, 不可行解=%d, 总计=%d, E_k均值=%.4f\n', ...
                iteration, Problem.FE, Problem.maxFE, numFeasible, numInfeasible, length(Population), mean(E_k));
            
            % ========== 检查是否是最后一次迭代，如果是则筛选帕累托前沿 ==========
            % 【关键】必须在NotTerminated之前筛选，因为NotTerminated会保存Population
            if Problem.FE >= Problem.maxFE
                Population = filterParetoFront(Population, iteration);
            end
        end
    end
end
end

function [Winner, Loser] = swapWL(Winner, Loser, FitValue)
    Change = FitValue(Loser) >= FitValue(Winner);
    Temp = Winner(Change);
    Winner(Change) = Loser(Change);
    Loser(Change) = Temp;
end

function ParetoFront = filterParetoFront(Population, iteration)
    % 筛选帕累托前沿（第一前沿）
    %
    % 输入：
    %   Population - 当前种群
    %   iteration - 当前迭代次数（用于打印信息）
    %
    % 输出：
    %   ParetoFront - 帕累托前沿（第一前沿）
    
    fprintf('\n========== 算法即将结束，筛选帕累托前沿 ==========\n');
    fprintf('迭代结束时种群大小: %d\n', length(Population));
    
    % 使用PlatEMO内置的非支配排序
    [FrontNo, ~] = NDSort(Population.objs, Population.cons, inf);
    
    % 只保留第一前沿（FrontNo == 1）
    ParetoFront = Population(FrontNo == 1);
    
    fprintf('帕累托前沿大小: %d\n', length(ParetoFront));
    
    % 打印帕累托前沿信息
    CV_final = sum(max(0, ParetoFront.cons), 2);
    numFeasible_final = sum(CV_final == 0);
    numInfeasible_final = sum(CV_final > 0);
    fprintf('帕累托前沿: 可行解=%d, 不可行解=%d, 总计=%d\n', ...
        numFeasible_final, numInfeasible_final, length(ParetoFront));
    fprintf('=============================================\n\n');
end
