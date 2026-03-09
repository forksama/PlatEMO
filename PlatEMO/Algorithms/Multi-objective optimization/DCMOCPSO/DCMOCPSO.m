classdef DCMOCPSO < ALGORITHM
% <multi> <real> <constrained/none>
% Divide-and-Conquer MOCPSO: 将大问题拆分成多个小问题，使用MOCPSO分别求解
% 
% 算法描述：
% 将UAVPathPlanning问题按照航点序列拆分成多个子问题，每个子问题包含
% 较少的航点。顺序求解每个子问题，保留并组合Pareto前沿。
% 
% 参数说明：
% numSegments --- 5 --- 将问题分成多少段（子问题数量）
% segmentOverlap --- 1 --- 相邻段之间的重叠航点数（用于平滑连接）
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
    function main(Algorithm, Problem)
        %% 参数设置
        [numSegments, segmentOverlap] = Algorithm.ParameterSet(5, 1);
        
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
        
        %% 顺序求解每个子问题，保留Pareto前沿
        ParetoFrontSolutions = [];
        
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
            
            try
                presetPathStart = Problem.presetPath(1, :);
            catch
                presetPathStart = fullWaypoints(1, :);
            end
            
            originalMaxFE = Problem.maxFE;
            originalFE = Problem.FE;
            segmentMaxFE = floor(originalMaxFE / numSegments);
            
            SubProblem = UAVPathPlanningSegment(Problem, startIdx, endIdx, fullWaypoints, presetPathStart, segmentMaxFE);
            SubProblem.FE = 0;
            
            MOCPSOAlg = MOCPSO();
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
            
            % 处理子问题的Pareto解
            if ~isempty(SubPopulation)
                fprintf('段 %d 获得 %d 个Pareto解\n', segIdx, length(SubPopulation));
                
                segmentSizeInSubProblem = segmentSize - 1;
                
                if segIdx == 1
                    % 第一段：直接转换为完整路径
                    numSubSolutions = length(SubPopulation);
                    ParetoFrontSolutions = cell(numSubSolutions, 1);
                    
                    for i = 1:numSubSolutions
                        segmentWaypointsDec = SubPopulation(i).decs;
                        segmentWaypoints = reshape(segmentWaypointsDec, 3, segmentSizeInSubProblem)';
                        
                        currentFullWaypoints = fullWaypoints;
                        currentFullWaypoints(startIdx, :) = presetPathStart;
                        if segmentSizeInSubProblem > 0
                            currentFullWaypoints(startIdx+1:endIdx, :) = segmentWaypoints;
                        end
                        
                        ParetoFrontSolutions{i} = currentFullWaypoints;
                    end
                else
                    % 后续段：组合前一段的所有解与当前段的所有解
                    numPrevSolutions = length(ParetoFrontSolutions);
                    numSubSolutions = length(SubPopulation);
                    
                    fprintf('组合前一段的 %d 个解与当前段的 %d 个解...\n', numPrevSolutions, numSubSolutions);
                    
                    CombinedSolutions = cell(numPrevSolutions * numSubSolutions, 1);
                    combIdx = 0;
                    
                    for i = 1:numPrevSolutions
                        prevFullWaypoints = ParetoFrontSolutions{i};
                        
                        for j = 1:numSubSolutions
                            combIdx = combIdx + 1;
                            
                            segmentWaypointsDec = SubPopulation(j).decs;
                            segmentWaypoints = reshape(segmentWaypointsDec, 3, segmentSizeInSubProblem)';
                            
                            newFullWaypoints = prevFullWaypoints;
                            newFullWaypoints(startIdx, :) = prevFullWaypoints(startIdx-1, :);
                            
                            if segmentSizeInSubProblem > 0
                                newFullWaypoints(startIdx+1:endIdx, :) = segmentWaypoints;
                            end
                            
                            CombinedSolutions{combIdx} = newFullWaypoints;
                        end
                    end
                    
                    fprintf('评估 %d 个组合解...\n', length(CombinedSolutions));
                    ParetoFrontSolutions = DCMOCPSO.extractParetoFront(CombinedSolutions, Problem);
                    fprintf('提取后的Pareto前沿包含 %d 个解\n', length(ParetoFrontSolutions));
                end
                
                fprintf('段 %d 求解完成，当前Pareto前沿包含 %d 个解\n', segIdx, length(ParetoFrontSolutions));
            else
                warning('段 %d 没有找到解', segIdx);
            end
            
            Problem.FE = originalFE + SubProblem.FE;
        end
        
        %% 创建最终Pareto前沿种群
        if isempty(ParetoFrontSolutions)
            warning('没有找到任何解');
            FinalPopulation = [];
        else
            fprintf('\n最终Pareto前沿包含 %d 个解\n', length(ParetoFrontSolutions));
            
            numFinalSolutions = length(ParetoFrontSolutions);
            FinalPopulationArray = [];
            
            PROBLEM.Current(Problem);
            
            for i = 1:numFinalSolutions
                currentFullWaypoints = ParetoFrontSolutions{i};
                
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
            fprintf('Pareto前沿包含 %d 个解\n', numSolutions);
            
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
    function ParetoFrontSolutions = extractParetoFront(CombinedSolutions, Problem)
        % 从组合解中提取Pareto前沿
        if isempty(CombinedSolutions)
            ParetoFrontSolutions = [];
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
        
        % 非支配排序
        [FrontNo, ~] = NDSort(SolutionArray.objs, SolutionArray.cons, numSolutions);
        
        % 提取Pareto前沿
        paretoIndices = find(FrontNo == 1);
        ParetoFrontSolutions = cell(length(paretoIndices), 1);
        for i = 1:length(paretoIndices)
            idx = paretoIndices(i);
            ParetoFrontSolutions{i} = CombinedSolutions{idx};
        end
        
        fprintf('从 %d 个组合解中提取出 %d 个Pareto前沿解\n', numSolutions, length(paretoIndices));
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