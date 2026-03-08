classdef MOCPSO < ALGORITHM
% <multi> <real/binary/permutation> <constrained/none>
% MOCPSO: A Multi-Objective Cooperative Particle Swarm Optimization Algorithm with Dual Search Strategies
% Zhang, Yan and Li, Bingdong and Hong, Wenjing and Zhou, Aimin
%
%------------------------------- Reference --------------------------------
% Zhang, Y., Li, B., Hong, W., & Zhou, A.
% "MOCPSO: A multi-objective cooperative particle swarm optimization algorithm 
% with dual search strategies." 
% Neurocomputing 562 (2023): 126892.
% https://github.com/ilog-ecnu/MOCPSO.git
%
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------
methods
    function main(Algorithm,Problem)

        %% TODO
        % 1. 目前算法中在适应度以及环境筛选中，都进行了归一化，对多目标没有进行权重设置

        
        % 算法中的适应度计算负责 "前期分组"，判断粒子的 "相对优秀程度"
        % 评估的是 "粒子在当前种群中的相对位置"
        % 根据适应度为粒子划分DSS（探险）或 CSS（追优）策略

        % 算法中的环境筛选负责 "后期选优"，判断粒子的 "绝对优秀程度"
        % 评估的是 "粒子的绝对质量"
        % APD 越小，粒子越靠近理想点（收敛性好）且越匹配参考向量（多样性好）

        % 关于Population.decs，这个是决策变量，表示粒子的位置
        % 关于PROBLEM.CalDec，这个是决策变量修复函数，用于修复决策变量中的无效解（直接修改决策变量）
        % 关于Population.cons，这个是约束值，表示解的约束违反程度
        % 关于PROBLEM.CalCon，这个是约束函数，用于计算解的约束违反程度
        % 约束违反程度若计算出来大于0，则表示这是一个不可行解，在存在可行解的情况下，永远不会被选择，建议使用CalDec代替CalCon的场景


        %% Generate random population
        % 生成三倍于N的参考向量
        [V,~] = UniformPoint(Problem.N,Problem.M);
        Population = Problem.Initialization();
        Population = EnvironmentalSelection(Population,V,(Problem.FE/Problem.maxFE)^2);
        
        % 如果环境选择后种群为空（所有解都不可行），重新初始化
        maxRetries = 10;  % 最多重试10次
        retryCount = 0;
        while isempty(Population) && retryCount < maxRetries
            warning('环境选择后种群为空（所有解都不可行），重新初始化种群（重试 %d/%d）', retryCount + 1, maxRetries);
            Population = Problem.Initialization();
            Population = EnvironmentalSelection(Population,V,(Problem.FE/Problem.maxFE)^2);
            retryCount = retryCount + 1;
        end
        
        % 如果仍然为空，使用所有解（包括不可行解）作为初始种群
        if isempty(Population)
            warning('重试后种群仍为空，使用所有解（包括不可行解）作为初始种群');
            Population = Problem.Initialization();
            % 不进行环境选择，直接使用所有初始解
        end
        
        % 打印初始种群的可行解和不可行解数量
        CV = sum(max(0,Population.cons),2);
        numFeasible = sum(CV == 0);
        numInfeasible = sum(CV > 0);
        fprintf('初始种群: 可行解=%d, 不可行解=%d, 总计=%d\n', numFeasible, numInfeasible, length(Population));

        % Optimization
        iteration = 0;
        while Algorithm.NotTerminated(Population)
            iteration = iteration + 1;
            % 判断是否是最后一次迭代（FE即将达到或超过maxFE）
            isLastIteration = (Problem.FE >= Problem.maxFE * 0.99) || (Problem.maxFE - Problem.FE < 10);
            
            if size(Population,2) < 3 || isempty(Population)
                % 如果种群为空或太小，重新初始化
                if isempty(Population)
                    warning('迭代 %d: 种群为空，重新初始化', iteration);
                    Population = Problem.Initialization();
                    Population = EnvironmentalSelection(Population,V,(Problem.FE/Problem.maxFE)^2,isLastIteration);
                    % 如果仍然为空，使用所有初始解
                    if isempty(Population)
                        Population = Problem.Initialization();
                    end
                end
                
                if ~isempty(Population)
                    disp(size(Population));
                    [N,D]     = size(Population.decs);
                    PopVel  = Population.adds(zeros(N,D));
                    Offspring = Polynomial_mutation(Problem,Population.decs,PopVel,N/2,D);
                    Population = EnvironmentalSelection([Population, Offspring],V,(Problem.FE/Problem.maxFE)^2,isLastIteration);
                    
                    % 检查环境选择后是否为空
                    if isempty(Population)
                        warning('迭代 %d: 环境选择后种群为空，使用所有解（包括不可行解）', iteration);
                        Population = [Population, Offspring];
                    end
                else
                    warning('迭代 %d: 无法生成有效种群，跳过本次迭代', iteration);
                    continue;
                end
                
                % 打印选择的可行解和不可行解数量
                CV = sum(max(0,Population.cons),2);
                numFeasible = sum(CV == 0);
                numInfeasible = sum(CV > 0);
                fprintf('迭代 %d (FE=%d/%d): 可行解=%d, 不可行解=%d, 总计=%d\n', ...
                    iteration, Problem.FE, Problem.maxFE, numFeasible, numInfeasible, length(Population));
                
                % 如果是最后一次迭代，在循环结束前进行最终过滤
                if true
                    CV = sum(max(0,Population.cons),2);
                    if any(CV > 0)
                        Population = EnvironmentalSelection(Population,V,1,true);
                        CV = sum(max(0,Population.cons),2);
                        numFeasible = sum(CV == 0);
                        numInfeasible = sum(CV > 0);
                        fprintf('最终过滤后: 可行解=%d, 不可行解=%d, 总计=%d\n', numFeasible, numInfeasible, length(Population));
                    end
                end
                continue;
            end

            % 检查种群是否为空
            if isempty(Population)
                warning('迭代 %d: 种群为空，重新初始化', iteration);
                Population = Problem.Initialization();
                Population = EnvironmentalSelection(Population,V,(Problem.FE/Problem.maxFE)^2,isLastIteration);
                if isempty(Population)
                    Population = Problem.Initialization();
                end
                continue;
            end
            
            FitValue = calFitness(Population.objs);
            Rank = randperm(length(Population),floor((length(Population))/3)*3);
            Loser1 = Rank(1:end/3);
            Loser2 = Rank(end/3+1:end/3*2);
            Winner = Rank(end/3*2+1:end);
            [Loser1, Loser2] = swapWL(Loser1,Loser2,FitValue);
            [Winner, Loser1] = swapWL(Winner,Loser1,FitValue);
            [Loser1, Loser2] = swapWL(Loser1,Loser2,FitValue);
            [Offspring1,Offspring2, Offspring3]      = Operator(Population(Loser1),Population(Loser2),Population(Winner));
            Population     = EnvironmentalSelection([Population,Offspring1,Offspring2,Offspring3],V,(Problem.FE/Problem.maxFE)^2,isLastIteration);
            
            % 检查环境选择后是否为空
            if isempty(Population)
                warning('迭代 %d: 环境选择后种群为空，使用所有解（包括不可行解）', iteration);
                Population = [Population,Offspring1,Offspring2,Offspring3];
            end
            
            % 打印选择的可行解和不可行解数量
            CV = sum(max(0,Population.cons),2);
            numFeasible = sum(CV == 0);
            numInfeasible = sum(CV > 0);
            fprintf('迭代 %d (FE=%d/%d): 可行解=%d, 不可行解=%d, 总计=%d\n', ...
                iteration, Problem.FE, Problem.maxFE, numFeasible, numInfeasible, length(Population));
            
            % 如果是最后一次迭代，在循环结束前进行最终过滤
            if true
                CV = sum(max(0,Population.cons),2);
                if any(CV > 0)
                    Population = EnvironmentalSelection(Population,V,1,true);
                    CV = sum(max(0,Population.cons),2);
                    numFeasible = sum(CV == 0);
                    numInfeasible = sum(CV > 0);
                    fprintf('最终过滤后: 可行解=%d, 不可行解=%d, 总计=%d\n', numFeasible, numInfeasible, length(Population));
                end
            end
        end
    end
end
end

function [Winner,Loser] = swapWL(Winner, Loser,FitValue)
    Change = FitValue(Loser) >= FitValue(Winner);
    Temp   = Winner(Change);
    Winner(Change) = Loser(Change);
    Loser(Change)  = Temp;
end
