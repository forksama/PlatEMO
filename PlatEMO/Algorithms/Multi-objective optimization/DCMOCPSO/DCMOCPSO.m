classdef DCMOCPSO < ALGORITHM
% <multi> <real> <constrained/none>
% Divide-and-Conquer MOCPSO: 将大问题拆分成多个小问题，使用MOCPSO_Ek分别求解
% 
% 算法描述：
% 将UAVPathPlanning问题按照航点序列拆分成多个子问题，每个子问题包含
% 较少的航点。顺序求解每个子问题，每段路径从前一段的每条路径出发，
% 保证路径连续性。
% 
% 参数说明：
% numSegments --- 5 --- 将问题分成多少段（子问题数量）
% segmentOverlap --- 1 --- 相邻段之间的重叠航点数（用于平滑连接）
% lambda --- 0.5 --- E_k影响权重（MOCPSO_Ek参数，0~1）
% c_guide --- 0.3 --- 引导粒子权重（MOCPSO_Ek参数）
% useDynamicGrouping --- false --- 是否使用动态分组比例（MOCPSO_Ek参数）
%   false: 使用原始1:1:1均匀分组 + swapWL竞争
%   true:  使用动态分组比例 (0-25%:2:1:1, 25-75%:1:1:1, 75-100%:1:1:2)
% useDynamicMutation --- false --- 是否使用动态变异率（MOCPSO_Ek参数）
%   false: 使用固定变异率 1/D
%   true:  使用动态变异率 (0-20%:2x, 20-40%:1.5x, 40-60%:1x, 60-80%:0.75x, 80-100%:0.5x)
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
    numSegments = 5;                % 分段数量
    segmentOverlap = 1;             % 相邻段之间的重叠航点数
    lambda = 0.5;                   % E_k影响权重 (MOCPSO_Ek参数)
    c_guide = 0.3;                  % 引导粒子权重 (MOCPSO_Ek参数)
    useDynamicGrouping = false;     % 是否使用动态分组比例 (MOCPSO_Ek参数)
    useDynamicMutation = false;     % 是否使用动态变异率 (MOCPSO_Ek参数)
end

methods
    function main(Algorithm, Problem)
        %% 参数设置
        [numSegments, segmentOverlap, lambda, c_guide, useDynamicGrouping, useDynamicMutation] = Algorithm.ParameterSet(5, 1, 0.5, 0.3, false, false);
        Algorithm.numSegments = numSegments;
        Algorithm.segmentOverlap = segmentOverlap;
        Algorithm.lambda = lambda;
        Algorithm.c_guide = c_guide;
        Algorithm.useDynamicGrouping = useDynamicGrouping;
        Algorithm.useDynamicMutation = useDynamicMutation;
        
        % 检查问题类型
        if ~isa(Problem, 'UAVPathPlanning')
            error('DCMOCPSO只能用于UAVPathPlanning问题');
        end
        
        % 获取航点数量
        numWaypoints = Problem.D / 3;  % D = numWaypoints * 3 (x, y, z)
        
        % 确保段数合理
        maxSegments = floor(numWaypoints / 2);
        if numSegments > maxSegments
            warning('段数(%d)过多，每段至少需要2个航点。自动调整为%d段', numSegments, maxSegments);
            numSegments = max(1, maxSegments);
        end
        
        if numSegments < 1
            numSegments = 1;
        end
        
        fprintf('DCMOCPSO: 将%d个航点分成%d段，每段重叠%d个航点\n', ...
            numWaypoints, numSegments, segmentOverlap);
        
        %% 计算每段的航点范围
        segmentRanges = DCMOCPSO.calculateSegmentRanges(numWaypoints, numSegments, segmentOverlap);
        
        %% 初始化完整路径
        try
            fullWaypoints = Problem.presetWaypoints;
            if isempty(fullWaypoints)
                fullWaypoints = Problem.generateUniformWaypoints();
            end
        catch
            fullWaypoints = Problem.generateUniformWaypoints();
        end
        
        %% 顺序求解每个子问题，每段从前一段的每条路径出发
        AllSolutions = [];  % 存储当前所有路径
        
        for segIdx = 1:numSegments
            fprintf('\n========== 求解第 %d/%d 段 ==========\n', segIdx, numSegments);
            
            startIdx = segmentRanges(segIdx, 1);
            endIdx = segmentRanges(segIdx, 2);
            segmentSize = endIdx - startIdx + 1;
            
            fprintf('段 %d: 航点索引 %d-%d (共%d个航点)\n', segIdx, startIdx, endIdx, segmentSize);
            
            if segmentSize <= 1
                warning('段 %d 只有%d个航点，跳过优化', segIdx, segmentSize);
                continue;
            end
            
            originalMaxFE = Problem.maxFE;
            originalFE = Problem.FE;
            
            if segIdx == 1
                % 第一段：只求解一次
                try
                    presetPathStart = Problem.presetPath(1, :);
                catch
                    presetPathStart = fullWaypoints(1, :);
                end
                
                % 每段都使用完整的函数评估预算（不在段间平分）
                segmentMaxFE = originalMaxFE;
                SubProblem = UAVPathPlanningSegment(Problem, startIdx, endIdx, fullWaypoints, presetPathStart, segmentMaxFE);
                SubProblem.FE = 0;
                
                MOCPSOAlg = MOCPSO_Ek();
                MOCPSOAlg.lambda = lambda;
                MOCPSOAlg.c_guide = c_guide;
                MOCPSOAlg.useDynamicGrouping = useDynamicGrouping;
                MOCPSOAlg.useDynamicMutation = useDynamicMutation;
                previousProblem = PROBLEM.Current();
                
                try
                    MOCPSOAlg.Solve(SubProblem);
                    if ~isempty(MOCPSOAlg.result)
                        SubPopulation = MOCPSOAlg.result{end, 2};
                    else
                        SubPopulation = [];
                    end
                catch ME
                    warning('段 %d 求解失败: %s', segIdx, ME.message);
                    SubPopulation = [];
                end
                
                PROBLEM.Current(Problem);
                Problem.FE = originalFE + SubProblem.FE;
                
                % 第一段：直接转换为完整路径
                if ~isempty(SubPopulation)
                    fprintf('段 %d 获得 %d 个解\n', segIdx, length(SubPopulation));
                    
                    numSubSolutions = length(SubPopulation);
                    AllSolutions = cell(numSubSolutions, 1);
                    segmentSizeInSubProblem = segmentSize - 1;
                    
                    for i = 1:numSubSolutions
                        segmentWaypointsDec = SubPopulation(i).decs;
                        segmentWaypoints = reshape(segmentWaypointsDec, 3, segmentSizeInSubProblem)';
                        
                        currentFullWaypoints = fullWaypoints;
                        currentFullWaypoints(startIdx, :) = presetPathStart;
                        if segmentSizeInSubProblem > 0
                            currentFullWaypoints(startIdx+1:endIdx, :) = segmentWaypoints;
                        end
                        
                        AllSolutions{i} = currentFullWaypoints;
                    end
                    
                    fprintf('段 %d 求解完成，生成 %d 条路径\n', segIdx, length(AllSolutions));
                else
                    warning('段 %d 没有找到解', segIdx);
                    AllSolutions = [];
                end
                
            else
                % 后续段：为每条前段路径创建独立子问题
                if isempty(AllSolutions)
                    warning('段 %d: 前一段没有解，无法继续', segIdx);
                    break;
                end
                
                numPrevSolutions = length(AllSolutions);
                fprintf('为前一段的 %d 条路径分别求解当前段...\n', numPrevSolutions);
                
                % 每段都使用完整的函数评估预算（不在段间/路径间平分）
                segmentMaxFEPerPath = originalMaxFE;
                % 注意：此设置会导致总FE可能显著超过Problem.maxFE（按真实累计统计）
                
                CombinedSolutions = [];  % 存储所有组合后的路径
                totalSubFE = 0;
                
                for prevIdx = 1:numPrevSolutions
                    prevFullWaypoints = AllSolutions{prevIdx};
                    
                    % 提取前一段的终点作为当前段的起点
                    fixedStartPoint = prevFullWaypoints(startIdx-1, :);
                    
                    fprintf('  为第 %d/%d 条前段路径求解（起点: [%.2f, %.2f, %.2f]）...\n', ...
                        prevIdx, numPrevSolutions, fixedStartPoint(1), fixedStartPoint(2), fixedStartPoint(3));
                    
                    % 创建子问题，固定起点为前一段的终点
                    SubProblem = UAVPathPlanningSegment(Problem, startIdx, endIdx, prevFullWaypoints, fixedStartPoint, segmentMaxFEPerPath);
                    SubProblem.FE = 0;
                    
                    MOCPSOAlg = MOCPSO_Ek();
                    MOCPSOAlg.lambda = lambda;
                    MOCPSOAlg.c_guide = c_guide;
                    MOCPSOAlg.useDynamicGrouping = useDynamicGrouping;
                    MOCPSOAlg.useDynamicMutation = useDynamicMutation;
                    previousProblem = PROBLEM.Current();
                    
                    try
                        MOCPSOAlg.Solve(SubProblem);
                        if ~isempty(MOCPSOAlg.result)
                            SubPopulation = MOCPSOAlg.result{end, 2};
                        else
                            SubPopulation = [];
                        end
                    catch ME
                        warning('段 %d, 前段路径 %d 求解失败: %s', segIdx, prevIdx, ME.message);
                        SubPopulation = [];
                    end
                    
                    PROBLEM.Current(Problem);
                    totalSubFE = totalSubFE + SubProblem.FE;
                    
                    % 拼接路径
                    if ~isempty(SubPopulation)
                        numSubSolutions = length(SubPopulation);
                        fprintf('    获得 %d 个解，拼接路径...\n', numSubSolutions);
                        
                        segmentSizeInSubProblem = segmentSize - 1;
                        
                        for j = 1:numSubSolutions
                            segmentWaypointsDec = SubPopulation(j).decs;
                            segmentWaypoints = reshape(segmentWaypointsDec, 3, segmentSizeInSubProblem)';
                            
                            % 拼接：复制前段路径，更新当前段
                            newFullWaypoints = prevFullWaypoints;
                            newFullWaypoints(startIdx, :) = fixedStartPoint;  % 起点为前段终点
                            
                            if segmentSizeInSubProblem > 0
                                newFullWaypoints(startIdx+1:endIdx, :) = segmentWaypoints;
                            end
                            
                            if isempty(CombinedSolutions)
                                CombinedSolutions = {newFullWaypoints};
                            else
                                CombinedSolutions{end+1} = newFullWaypoints;
                            end
                        end
                    else
                        fprintf('    前段路径 %d 没有找到当前段的解\n', prevIdx);
                    end
                end
                
                Problem.FE = originalFE + totalSubFE;
                
                % 筛选可行解
                if ~isempty(CombinedSolutions)
                    fprintf('段 %d 组合生成 %d 条路径，筛选可行解...\n', segIdx, length(CombinedSolutions));
                    AllSolutions = DCMOCPSO.extractFeasibleSolutions(CombinedSolutions, Problem);
                    fprintf('段 %d 求解完成，当前可行解集合包含 %d 条路径\n', segIdx, length(AllSolutions));
                else
                    warning('段 %d 没有生成任何路径', segIdx);
                    AllSolutions = [];
                end
            end
        end
        
        %% 创建最终解集种群
        if isempty(AllSolutions)
            warning('没有找到任何解');
            FinalPopulation = [];
        else
            fprintf('\n最终解集包含 %d 个解\n', length(AllSolutions));
            
            numFinalSolutions = length(AllSolutions);
            FinalPopulationArray = [];
            
            PROBLEM.Current(Problem);
            
            for i = 1:numFinalSolutions
                currentFullWaypoints = AllSolutions{i};
                
                if size(currentFullWaypoints, 2) ~= 3
                    error('fullWaypoints维度错误：应该是 numWaypoints x 3');
                end
                
                finalDec = reshape(currentFullWaypoints', 1, []);
                sol = SOLUTION(finalDec);
                
                if isempty(FinalPopulationArray)
                    FinalPopulationArray = sol;
                else
                    FinalPopulationArray = [FinalPopulationArray, sol];
                end
            end
            
            FinalPopulation = FinalPopulationArray;
        end
        
        % 保存最终结果
        try
            Algorithm.NotTerminated(FinalPopulation);
        catch ME
            if ~strcmp(ME.identifier, 'PlatEMO:Termination')
                rethrow(ME);
            end
        end
        
        fprintf('\n========== DCMOCPSO 求解完成 ==========\n');
        fprintf('最终路径: %d个航点\n', numWaypoints);
        
        if ~isempty(FinalPopulation)
            numSolutions = length(FinalPopulation);
            fprintf('最终解集包含 %d 个解\n', numSolutions);
            
            CV = sum(max(0, FinalPopulation.cons), 2);
            numFeasible = sum(CV == 0);
            numInfeasible = sum(CV > 0);
            fprintf('可行解: %d, 不可行解: %d\n', numFeasible, numInfeasible);
            
            allObjs = FinalPopulation.objs;
            fprintf('目标值范围:\n');
            fprintf('  目标1: [%.4f, %.4f]\n', min(allObjs(:,1)), max(allObjs(:,1)));
            fprintf('  目标2: [%.4f, %.4f]\n', min(allObjs(:,2)), max(allObjs(:,2)));
        else
            fprintf('未找到任何解\n');
        end
    end
end

methods(Static)
    function FeasibleSolutions = extractFeasibleSolutions(CombinedSolutions, Problem)
        % 从组合解中筛选所有可行解
        if isempty(CombinedSolutions)
            FeasibleSolutions = [];
            return;
        end
        
        numSolutions = length(CombinedSolutions);
        PROBLEM.Current(Problem);
        
        % 转换为SOLUTION对象
        SolutionArray = [];
        for i = 1:numSolutions
            currentWaypoints = CombinedSolutions{i};
            dec = reshape(currentWaypoints', 1, []);
            sol = SOLUTION(dec);
            
            if isempty(SolutionArray)
                SolutionArray = sol;
            else
                SolutionArray = [SolutionArray, sol];
            end
        end
        
        % 筛选所有可行解
        CV = sum(max(0, SolutionArray.cons), 2);
        feasibleIndices = find(CV == 0);
        
        if ~isempty(feasibleIndices)
            % 保留所有可行解
            FeasibleSolutions = cell(length(feasibleIndices), 1);
            for i = 1:length(feasibleIndices)
                idx = feasibleIndices(i);
                FeasibleSolutions{i} = CombinedSolutions{idx};
            end
            fprintf('从 %d 个组合解中筛选出 %d 个可行解\n', numSolutions, length(feasibleIndices));
        else
            % 如果没有可行解，保留约束违反度最小的前N个解
            [~, sortedIdx] = sort(CV);
            numKeep = min(50, numSolutions);
            FeasibleSolutions = cell(numKeep, 1);
            for i = 1:numKeep
                idx = sortedIdx(i);
                FeasibleSolutions{i} = CombinedSolutions{idx};
            end
            fprintf('从 %d 个组合解中没有可行解，保留约束违反度最小的 %d 个解\n', numSolutions, numKeep);
        end
    end
    
    function segmentRanges = calculateSegmentRanges(numWaypoints, numSegments, segmentOverlap)
        % 计算每段的航点范围
        segmentRanges = zeros(numSegments, 2);
        
        if numSegments == 1
            segmentRanges(1, 1) = 1;
            segmentRanges(1, 2) = numWaypoints;
            return;
        end
        
        baseSegmentSize = floor(numWaypoints / numSegments) + 1;
        remainder = mod(numWaypoints, numSegments);
        newWaypointsPerSegment = baseSegmentSize * ones(numSegments, 1);
        newWaypointsPerSegment(1:remainder) = newWaypointsPerSegment(1:remainder) + 1;
        
        currentIdx = 1;
        for i = 1:numSegments
            segmentRanges(i, 1) = currentIdx;
            endIdx = currentIdx + newWaypointsPerSegment(i) - 1;
            
            if i == numSegments
                segmentRanges(i, 2) = numWaypoints;
            else
                segmentRanges(i, 2) = min(endIdx, numWaypoints);
            end
            
            if i < numSegments
                currentIdx = segmentRanges(i, 2) - segmentOverlap + 1;
                if currentIdx > segmentRanges(i, 2)
                    currentIdx = segmentRanges(i, 2) + 1;
                end
                if currentIdx > numWaypoints
                    segmentRanges = segmentRanges(1:i, :);
                    break;
                end
            end
        end
        
        if segmentRanges(end, 2) ~= numWaypoints
            segmentRanges(end, 2) = numWaypoints;
        end
    end
end

end