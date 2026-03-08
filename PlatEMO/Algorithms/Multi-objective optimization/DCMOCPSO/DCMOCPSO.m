classdef DCMOCPSO < ALGORITHM
% <multi> <real> <constrained/none>
% Divide-and-Conquer MOCPSO: 将大问题拆分成多个小问题，使用MOCPSO分别求解
% 
% 算法描述：
% 将UAVPathPlanning问题按照航点序列拆分成多个子问题，每个子问题包含
% 较少的航点。顺序求解每个子问题，确保相邻子问题的首尾航点连接。
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
        
        % 确保段数合理：每段至少需要2个航点（1个固定+1个优化）
        % 如果段数太多，自动调整
        maxSegments = floor(numWaypoints / 2);  % 每段至少2个航点
        if numSegments > maxSegments
            warning('段数(%d)过多，每段至少需要2个航点。自动调整为%d段', numSegments, maxSegments);
            numSegments = max(1, maxSegments);  % 至少1段
        end
        
        if numSegments < 1
            numSegments = 1;
        end
        
        fprintf('DCMOCPSO: 将%d个航点分成%d段，每段重叠%d个航点\n', ...
            numWaypoints, numSegments, segmentOverlap);
        
        %% 计算每段的航点范围
        segmentRanges = DCMOCPSO.calculateSegmentRanges(numWaypoints, numSegments, segmentOverlap);
        
        %% 初始化完整路径（使用预设航点）
        % 确保presetWaypoints已生成
        % 注意：presetWaypoints是私有属性，需要通过Setting方法初始化
        % 如果为空，说明Setting方法还未调用或presetWaypoints未生成
        try
            fullWaypoints = Problem.presetWaypoints;  % numWaypoints x 3
            if isempty(fullWaypoints)
                % 如果为空，重新生成
                fullWaypoints = Problem.generateUniformWaypoints();
            end
        catch
            % 如果无法访问，重新生成
            fullWaypoints = Problem.generateUniformWaypoints();
        end
        
        %% 顺序求解每个子问题
        for segIdx = 1:numSegments
            fprintf('\n========== 求解第 %d/%d 段 ==========\n', segIdx, numSegments);
            
            % 获取当前段的航点范围
            startIdx = segmentRanges(segIdx, 1);
            endIdx = segmentRanges(segIdx, 2);
            segmentSize = endIdx - startIdx + 1;
            
            fprintf('段 %d: 航点索引 %d-%d (共%d个航点)\n', segIdx, startIdx, endIdx, segmentSize);
            
            % 检查段大小：如果段只有1个航点，跳过优化（没有可优化的变量）
            if segmentSize <= 1
                warning('段 %d 只有%d个航点，跳过优化（没有可优化的变量）', segIdx, segmentSize);
                continue;  % 跳过这个段
            end
            
            % 获取预设路径起点（用于第一段）
            % 注意：presetPath是私有属性，需要通过其他方式获取
            try
                presetPathStart = Problem.presetPath(1, :);
            catch
                % 如果无法访问，使用预设航点的第一个点
                presetPathStart = fullWaypoints(1, :);
            end
            
            % 使用MOCPSO求解子问题
            % 注意：需要分配部分函数评估次数给每个子问题
            originalMaxFE = Problem.maxFE;
            originalFE = Problem.FE;  % 保存当前的FE
            segmentMaxFE = floor(originalMaxFE / numSegments);
            
            % 创建子问题（传入maxFE参数）
            SubProblem = UAVPathPlanningSegment(Problem, startIdx, endIdx, fullWaypoints, presetPathStart, segmentMaxFE);
            
            SubProblem.FE = 0;  % 子问题的FE从0开始
            
            % 创建MOCPSO算法实例
            MOCPSOAlg = MOCPSO();
            
            % 保存当前问题对象（如果有）
            previousProblem = PROBLEM.Current();
            
            % 求解子问题
            try
                MOCPSOAlg.Solve(SubProblem);
                
                % 获取最优解（从MOCPSO的结果中）
                if ~isempty(MOCPSOAlg.result)
                    SubPopulation = MOCPSOAlg.result{end, 2};
                else
                    SubPopulation = [];
                end
            catch ME
                warning('段 %d 求解失败: %s', segIdx, ME.message);
                SubPopulation = [];
            end
            
            % 恢复当前问题对象为原始的Problem
            PROBLEM.Current(Problem);
            
            % 选择最优解（选择第一个可行解，或第一个解）
            if ~isempty(SubPopulation)
                CV = sum(max(0, SubPopulation.cons), 2);
                feasibleIdx = find(CV == 0);
                if ~isempty(feasibleIdx)
                    bestSolution = SubPopulation(feasibleIdx(1));
                else
                    bestSolution = SubPopulation(1);
                end
                
                % 提取子问题的航点解
                % 注意：子问题的决策变量不包括固定的第一个航点
                segmentSizeInSubProblem = segmentSize - 1;  % 不包括固定的第一个航点
                segmentWaypointsDec = bestSolution.decs;  % 1 x (segmentSizeInSubProblem * 3)
                segmentWaypoints = reshape(segmentWaypointsDec, 3, segmentSizeInSubProblem)';  % segmentSizeInSubProblem x 3
                
                % 更新完整路径中对应段的航点
                % 注意：第一个航点固定（与前一段的最后一个航点相同）
                if segIdx > 1
                    % 第一个航点固定为前一段的最后一个航点
                    fullWaypoints(startIdx, :) = fullWaypoints(startIdx-1, :);
                    % 更新其他航点（从子问题的解中提取）
                    if segmentSizeInSubProblem > 0
                        fullWaypoints(startIdx+1:endIdx, :) = segmentWaypoints;
                    end
                else
                    % 第一段：第一个航点固定为预设路径起点
                    try
                        fullWaypoints(startIdx, :) = Problem.presetPath(1, :);
                    catch
                        % 如果无法访问，使用传入的presetPathStart
                        fullWaypoints(startIdx, :) = presetPathStart;
                    end
                    % 更新其他航点（从子问题的解中提取）
                    if segmentSizeInSubProblem > 0
                        fullWaypoints(startIdx+1:endIdx, :) = segmentWaypoints;
                    end
                end
                
                fprintf('段 %d 求解完成，更新了航点 %d-%d\n', segIdx, startIdx, endIdx);
            else
                warning('段 %d 没有找到解', segIdx);
            end
            
            % 累加函数评估次数
            Problem.FE = originalFE + SubProblem.FE;
        end
        
        %% 合并所有段的解，创建最终种群
        % 将完整路径转换为决策变量格式
        % 确保fullWaypoints的维度正确：numWaypoints x 3
        if size(fullWaypoints, 2) ~= 3
            error('fullWaypoints维度错误：应该是 numWaypoints x 3，实际是 %d x %d', ...
                  size(fullWaypoints, 1), size(fullWaypoints, 2));
        end
        
        % 验证维度匹配
        expectedD = size(fullWaypoints, 1) * 3;
        if Problem.D ~= expectedD
            error('维度不匹配：Problem.D = %d，但fullWaypoints对应的维度 = %d', ...
                  Problem.D, expectedD);
        end
        
        finalDec = reshape(fullWaypoints', 1, []);  % 1 x D
        
        % 确保当前问题对象是原始的Problem（而不是子问题）
        % SOLUTION构造函数会使用PROBLEM.Current()来获取当前问题
        PROBLEM.Current(Problem);
        
        % 创建最终解
        % 注意：SOLUTION构造函数会自动计算目标值和约束值
        % 由于属性是只读的，我们无法手动设置，所以让构造函数正常计算
        FinalPopulation = SOLUTION(finalDec);
        
        % 更新函数评估次数（累加所有子问题的评估次数）
        % 注意：每个子问题的FE已经累加到Problem.FE中
        
        % 保存最终结果
        % 使用NotTerminated方法保存结果（这是标准做法）
        % 注意：NotTerminated可能会抛出终止异常，但Solve方法会捕获它
        try
            Algorithm.NotTerminated(FinalPopulation);
        catch ME
            % 如果抛出终止异常，这是正常的（因为FE可能已经达到maxFE）
            % 但结果已经保存了
            if ~strcmp(ME.identifier, 'PlatEMO:Termination')
                rethrow(ME);
            end
        end
        
        fprintf('\n========== DCMOCPSO 求解完成 ==========\n');
        fprintf('最终路径: %d个航点\n', numWaypoints);
        
        % 显示最终解的目标值
        if ~isempty(FinalPopulation)
            % FinalPopulation是单个SOLUTION对象，直接访问obj和con属性
            % objs是方法，返回矩阵；obj是属性，返回行向量
            fprintf('目标值: [%.4f, %.4f]\n', FinalPopulation.obj(1), FinalPopulation.obj(2));
            CV = sum(max(0, FinalPopulation.con), 2);
            if CV == 0
                fprintf('约束状态: 可行解\n');
            else
                fprintf('约束状态: 不可行解 (违反度=%.4f)\n', CV);
            end
        end
    end
end

methods(Static)
    function segmentRanges = calculateSegmentRanges(numWaypoints, numSegments, segmentOverlap)
        % 计算每段的航点范围（平均分配）
        % 输入：
        %   numWaypoints - 总航点数
        %   numSegments - 段数
        %   segmentOverlap - 相邻段之间的重叠航点数
        % 输出：
        %   segmentRanges - numSegments x 2 矩阵，每行是[startIdx, endIdx]
        %
        % 分配策略：
        % 1. 每段基本大小 = floor(numWaypoints / numSegments)
        % 2. 余数 = mod(numWaypoints, numSegments)
        % 3. 将余数均匀分配到前几段（每段+1）
        % 4. 每段包含上一段的结束点（重叠），所以每段实际包含的航点数 = 基本大小 + 1（重叠点）
        %
        % 示例：40个航点，5段，重叠1
        % - 基本大小 = 8，余数 = 0
        % - 每段大小 = [8, 8, 8, 8, 8]
        % - 第一段：1-8（8个航点）
        % - 第二段：8-16（9个航点，包含重叠点8）
        % - 第三段：16-24（9个航点，包含重叠点16）
        % - 第四段：24-32（9个航点，包含重叠点24）
        % - 第五段：32-40（9个航点，包含重叠点32）
        
        segmentRanges = zeros(numSegments, 2);
        
        % 如果只有1段，直接返回全部航点
        if numSegments == 1
            segmentRanges(1, 1) = 1;
            segmentRanges(1, 2) = numWaypoints;
            return;
        end
        
        % 计算每段的基本大小（包括重叠点）
        baseSegmentSize = floor(numWaypoints / numSegments) + 1;
        
        % 计算余数（需要额外分配的航点数）
        remainder = mod(numWaypoints, numSegments);
        
        % 计算每段需要覆盖的新航点数（不包括重叠点）
        % 前remainder段额外多覆盖1个新航点
        newWaypointsPerSegment = baseSegmentSize * ones(numSegments, 1);
        newWaypointsPerSegment(1:remainder) = newWaypointsPerSegment(1:remainder) + 1;
        
        % 分配每段的航点范围
        currentIdx = 1;
        for i = 1:numSegments
            % 当前段的起始索引
            segmentRanges(i, 1) = currentIdx;
            
            % 当前段的结束索引
            % 结束索引 = 起始索引 + 本段需要覆盖的新航点数 - 1
            endIdx = currentIdx + newWaypointsPerSegment(i) - 1;
            
            % 确保不超过总航点数
            if i == numSegments
                % 最后一段必须包含所有剩余航点
                segmentRanges(i, 2) = numWaypoints;
            else
                segmentRanges(i, 2) = min(endIdx, numWaypoints);
            end
            
            % 计算下一段的起始索引
            % 下一段从当前段结束位置 - 重叠数 + 1 开始
            % 这样确保相邻段之间有segmentOverlap个重叠航点
            if i < numSegments
                currentIdx = segmentRanges(i, 2) - segmentOverlap + 1;
                
                % 确保下一段起始位置合理（不能超过当前段结束位置）
                if currentIdx > segmentRanges(i, 2)
                    currentIdx = segmentRanges(i, 2) + 1;
                end
                
                % 如果下一段起始位置已经超过总航点数，提前结束
                if currentIdx > numWaypoints
                    % 调整段数，只保留已分配的段
                    segmentRanges = segmentRanges(1:i, :);
                    break;
                end
            end
        end
        
        % 验证：确保所有航点都被覆盖
        if segmentRanges(end, 2) ~= numWaypoints
            % 如果最后一段没有覆盖所有航点，调整最后一段
            segmentRanges(end, 2) = numWaypoints;
        end
    end
end

end
