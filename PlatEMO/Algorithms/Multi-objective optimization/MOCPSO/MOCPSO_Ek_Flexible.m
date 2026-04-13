classdef MOCPSO_Ek_Flexible < ALGORITHM
% <multi> <real/binary/permutation> <constrained/none>
% MOCPSO_Ek_Flexible: MOCPSO with Optional Dimension Exploration Contribution
% 
% 新增参数：
%   useEk - 是否启用维度探索贡献机制（默认true）
%     - true:  使用E_k机制（原MOCPSO_Ek行为）
%     - false: 不使用E_k机制（回退到原始MOCPSO行为）
%
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes.
%--------------------------------------------------------------------------
properties
    lambda = 0.5;                 % E_k影响权重 (0~1)
    c_guide = 0.3;                % 引导粒子权重
    useDynamicGrouping = false;   % 是否使用动态分组比例
    useDynamicMutation = false;   % 是否使用动态变异率
    useEk = true;                 % 是否启用E_k机制（新增）
end

methods
    function main(Algorithm, Problem)
        
        %% 参数设置
        [lambda, c_guide, useDynamicGrouping, useDynamicMutation, useEk] = Algorithm.ParameterSet(0.5, 0.3, false, false, true);
        Algorithm.lambda = lambda;
        Algorithm.c_guide = c_guide;
        Algorithm.useDynamicGrouping = useDynamicGrouping;
        Algorithm.useDynamicMutation = useDynamicMutation;
        Algorithm.useEk = useEk;
        
        %% Generate random population
        [V,~] = UniformPoint(Problem.N * 10, Problem.M);
        Population = Problem.Initialization();
        
        % 根据useEk选择环境选择函数
        if useEk
            Population = EnvironmentalSelectionWithEk(Population, V, (Problem.FE/Problem.maxFE)^2, lambda);
        else
            Population = EnvironmentalSelection(Population, V, (Problem.FE/Problem.maxFE)^2);
        end
        
        % 如果环境选择后种群为空（无可行解），最多重试5次
        maxRetries = 5;
        retryCount = 0;
        while isempty(Population) && retryCount < maxRetries
            warning('环境选择后种群为空（无可行解），重新初始化（重试 %d/%d）', retryCount + 1, maxRetries);
            Population = Problem.Initialization();
            if useEk
                Population = EnvironmentalSelectionWithEk(Population, V, (Problem.FE/Problem.maxFE)^2, lambda);
            else
                Population = EnvironmentalSelection(Population, V, (Problem.FE/Problem.maxFE)^2);
            end
            retryCount = retryCount + 1;
        end
        
        if isempty(Population)
            warning('重试5次后仍无可行解，算法返回空种群（0个解）');
            return;  % 直接返回，不再继续优化
        end
        
        % 打印初始种群信息
        CV = sum(max(0, Population.cons), 2);
        numFeasible = sum(CV == 0);
        numInfeasible = sum(CV > 0);
        fprintf('初始种群: 可行解=%d, 不可行解=%d, 总计=%d (useEk=%d)\n', numFeasible, numInfeasible, length(Population), useEk);
        
        %% Optimization
        iteration = 0;
        while Algorithm.NotTerminated(Population)
            iteration = iteration + 1;
            isLastIteration = (Problem.FE >= Problem.maxFE * 0.99) || (Problem.maxFE - Problem.FE < 10);
            
            if size(Population, 2) < 3 || isempty(Population)
                % 种群为空或太小的处理
                if isempty(Population)
                    warning('迭代 %d: 种群为空（无可行解），尝试重新初始化', iteration);
                    tempPopulation = Problem.Initialization();
                    if useEk
                        Population = EnvironmentalSelectionWithEk(tempPopulation, V, (Problem.FE/Problem.maxFE)^2, lambda, isLastIteration);
                    else
                        Population = EnvironmentalSelection(tempPopulation, V, (Problem.FE/Problem.maxFE)^2);
                    end
                    if isempty(Population)
                        warning('迭代 %d: 重新初始化后仍无可行解，算法终止', iteration);
                        return;  % 无可行解，直接返回
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
                    if useEk
                        Population = EnvironmentalSelectionWithEk([Population, Offspring], V, (Problem.FE/Problem.maxFE)^2, lambda, isLastIteration);
                    else
                        Population = EnvironmentalSelection([Population, Offspring], V, (Problem.FE/Problem.maxFE)^2);
                    end
                    
                    if isempty(Population)
                        warning('迭代 %d: 环境选择后种群为空（无可行解），尝试保留所有子代', iteration);
                        Population = Offspring;
                        % 再次筛选，如果仍为空则终止
                        if useEk
                            Population = EnvironmentalSelectionWithEk(Population, V, (Problem.FE/Problem.maxFE)^2, lambda, isLastIteration);
                        else
                            Population = EnvironmentalSelection(Population, V, (Problem.FE/Problem.maxFE)^2);
                        end
                        if isempty(Population)
                            warning('迭代 %d: 子代中也无可行解，算法终止', iteration);
                            return;
                        end
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
                    ratio = [2, 1, 1];
                elseif t < 0.75
                    ratio = [1, 1, 1];
                else
                    ratio = [1, 1, 2];
                end
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
            
            % ========== 根据useEk决定是否使用引导粒子 ==========
            if useEk
                [E_k, ~, ~, ~, guideIdx] = calculateDimensionExploration(Population);
                GuideDec = Population(guideIdx).decs;
                % 动态引导权重（前期强，后期弱）
                c_guide_dynamic = c_guide * (1 - t);
            else
                E_k = zeros(length(Population), 1);  % 不使用E_k
                GuideDec = [];  % 不使用引导粒子
                c_guide_dynamic = 0;  % 禁用引导权重
            end
            
            % 更新操作（带引导粒子和动态变异率）
            [Offspring1, Offspring2, Offspring3] = Operator_WithGuide(Population(Loser1), Population(Loser2), Population(Winner), GuideDec, c_guide_dynamic, Problem, mutationRateMultiplier);
            
            % 环境选择
            if useEk
                Population = EnvironmentalSelectionWithEk([Population, Offspring1, Offspring2, Offspring3], V, (Problem.FE/Problem.maxFE)^2, lambda, isLastIteration);
            else
                Population = EnvironmentalSelection([Population, Offspring1, Offspring2, Offspring3], V, (Problem.FE/Problem.maxFE)^2);
            end
            
            if isempty(Population)
                warning('迭代 %d: 环境选择后种群为空（无可行解），尝试保留所有子代', iteration);
                Population = [Offspring1, Offspring2, Offspring3];
                % 再次筛选，如果仍为空则终止
                if useEk
                    Population = EnvironmentalSelectionWithEk(Population, V, (Problem.FE/Problem.maxFE)^2, lambda, isLastIteration);
                else
                    Population = EnvironmentalSelection(Population, V, (Problem.FE/Problem.maxFE)^2);
                end
                if isempty(Population)
                    warning('迭代 %d: 子代中也无可行解，算法终止', iteration);
                    return;
                end
            end
            
            % 打印迭代信息
            CV = sum(max(0, Population.cons), 2);
            numFeasible = sum(CV == 0);
            numInfeasible = sum(CV > 0);
            if useEk
                fprintf('迭代 %d (FE=%d/%d): 可行解=%d, 不可行解=%d, 总计=%d, E_k均值=%.4f\n', ...
                    iteration, Problem.FE, Problem.maxFE, numFeasible, numInfeasible, length(Population), mean(E_k));
            else
                fprintf('迭代 %d (FE=%d/%d): 可行解=%d, 不可行解=%d, 总计=%d (E_k disabled)\n', ...
                    iteration, Problem.FE, Problem.maxFE, numFeasible, numInfeasible, length(Population));
            end
            
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
    fprintf('\n========== 算法即将结束，筛选帕累托前沿 ==========\n');
    fprintf('迭代结束时种群大小: %d\n', length(Population));
    
    [FrontNo, ~] = NDSort(Population.objs, Population.cons, inf);
    ParetoFront = Population(FrontNo == 1);
    
    fprintf('帕累托前沿大小: %d\n', length(ParetoFront));
    
    CV_final = sum(max(0, ParetoFront.cons), 2);
    numFeasible_final = sum(CV_final == 0);
    numInfeasible_final = sum(CV_final > 0);
    fprintf('帕累托前沿: 可行解=%d, 不可行解=%d, 总计=%d\n', ...
        numFeasible_final, numInfeasible_final, length(ParetoFront));
    fprintf('=============================================\n\n');
end
