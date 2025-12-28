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

        
        % 算法中的适应度计算负责 “前期分组”，判断粒子的 “相对优秀程度”
        % 评估的是 “粒子在当前种群中的相对位置”
        % 根据适应度为粒子划分DSS（探险）或 CSS（追优）策略

        % 算法中的环境筛选负责 “后期选优”，判断粒子的 “绝对优秀程度”
        % 评估的是 “粒子的绝对质量”
        % APD 越小，粒子越靠近理想点（收敛性好）且越匹配参考向量（多样性好）

        % 关于Population.decs，这个是决策变量，表示粒子的位置
        % 关于PROBLEM.CalDec，这个是决策变量修复函数，用于修复决策变量中的无效解（直接修改决策变量）
        % 关于Population.cons，这个是约束值，表示解的约束违反程度
        % 关于PROBLEM.CalCon，这个是约束函数，用于计算解的约束违反程度
        % 约束违反程度若计算出来大于0，则表示这是一个不可行解，在存在可行解的情况下，永远不会被选择，建议使用CalDec代替CalCon的场景


        %% Generate random population
        [V,Problem.N] = UniformPoint(Problem.N,Problem.M);
        Population = Problem.Initialization();
        Population = EnvironmentalSelection(Population,V,(Problem.FE/Problem.maxFE)^2);

        % Optimization
        while Algorithm.NotTerminated(Population)
            if size(Population,2) < 3
                disp(size(Population));
                [N,D]     = size(Population.decs);
                PopVel  = Population.adds(zeros(N,D));
                Offspring = Polynomial_mutation(Problem,Population.decs,PopVel,N/2,D);
                Population = EnvironmentalSelection([Population, Offspring],V,(Problem.FE/Problem.maxFE)^2);
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
            Population     = EnvironmentalSelection([Population,Offspring1,Offspring2,Offspring3],V,(Problem.FE/Problem.maxFE)^2);
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