classdef UAVPathPlanningSegment < PROBLEM
%UAVPathPlanningSegment - UAVPathPlanning问题的子问题包装类
%
% 这个类将UAVPathPlanning问题的一个航点段包装成独立的子问题。
% 用于分治算法中，将大问题拆分成多个小问题分别求解。
%
% 属性：
%   originalProblem - 原始的UAVPathPlanning问题对象
%   startIdx - 当前段在完整路径中的起始航点索引（从1开始）
%   endIdx - 当前段在完整路径中的结束航点索引（从1开始）
%   fullWaypoints - 完整路径的所有航点（numWaypoints x 3）
%   fixedStartWaypoint - 固定的起始航点（前一段的最后一个航点，或预设路径起点）
%   fixedEndWaypoint - 固定的结束航点（可选，用于最后一段）
%
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    properties(Access = private)
        originalProblem;      % 原始的UAVPathPlanning问题对象
        startIdx;            % 当前段在完整路径中的起始航点索引
        endIdx;              % 当前段在完整路径中的结束航点索引
        fullWaypoints;       % 完整路径的所有航点（numWaypoints x 3）
        fixedStartWaypoint;  % 固定的起始航点（1 x 3）
        fixedEndWaypoint;    % 固定的结束航点（1 x 3，可选）
        useFixedEnd;         % 是否使用固定的结束航点
        presetPathStart;     % 预设路径起点（1 x 3），用于第一段
    end
    
    methods
        function obj = UAVPathPlanningSegment(originalProblem, startIdx, endIdx, fullWaypoints, presetPathStart, maxFE)
            %UAVPathPlanningSegment - 构造函数
            %
            %   输入：
            %       originalProblem - 原始的UAVPathPlanning问题对象
            %       startIdx - 当前段在完整路径中的起始航点索引（从1开始）
            %       endIdx - 当前段在完整路径中的结束航点索引（从1开始）
            %       fullWaypoints - 完整路径的所有航点（numWaypoints x 3）
            %       presetPathStart - 预设路径起点（1 x 3），用于第一段
            %       maxFE - （可选）最大函数评估次数，如果不提供则使用原始问题的maxFE
            %
            %   注意：
            %      - 第一个航点（startIdx）固定为前一段的最后一个航点（或预设路径起点）
            %      - 最后一个航点（endIdx）通常不固定，除非是最后一段
            
            obj.originalProblem = originalProblem;
            obj.startIdx = startIdx;
            obj.endIdx = endIdx;
            obj.fullWaypoints = fullWaypoints;
            obj.presetPathStart = presetPathStart;
            
            % 设置固定的起始航点
            if startIdx == 1
                % 第一段：固定为预设路径起点
                obj.fixedStartWaypoint = presetPathStart;
            else
                % 其他段：固定为前一段的最后一个航点
                obj.fixedStartWaypoint = fullWaypoints(startIdx - 1, :);
            end
            
            % 设置固定的结束航点（可选，通常不使用）
            obj.useFixedEnd = false;
            if endIdx == size(fullWaypoints, 1)
                % 最后一段：可以选择固定为预设路径终点
                % 但根据UAVPathPlanning的代码，最后一个航点通常不固定
                % obj.fixedEndWaypoint = originalProblem.presetPath(end, :);
                % obj.useFixedEnd = true;
            end
            
            % 调用父类构造函数，设置问题参数
            % 子问题的决策变量维度：段内航点数 * 3（不包括固定的第一个航点）
            segmentSize = endIdx - startIdx + 1;
            
            % 检查段大小：至少需要2个航点（1个固定+1个优化）
            if segmentSize < 2
                error('UAVPathPlanningSegment: 段大小至少需要2个航点（当前：%d个）', segmentSize);
            end
            
            obj.D = (segmentSize - 1) * 3;  % 减去固定的第一个航点
            
            % 目标数量与原始问题相同
            obj.M = originalProblem.M;
            
            % 决策变量上下界（与原始问题相同）
            % 确保是行向量，且维度匹配
            % 原始问题的边界是长度为 originalProblem.D 的行向量
            % 子问题的边界应该是长度为 obj.D 的行向量
            % 每个航点的 x, y, z 使用相同的边界值（从原始问题中提取前3个元素）
            originalLower = originalProblem.lower(:)';  % 转换为行向量
            originalUpper = originalProblem.upper(:)';  % 转换为行向量
            
            % 提取 x, y, z 的边界值（原始问题的前3个元素）
            % 如果原始问题的边界长度小于3，使用默认值
            if length(originalLower) >= 3
                xyzLower = originalLower(1:3);  % 1 x 3
                xyzUpper = originalUpper(1:3);  % 1 x 3
            else
                % 使用默认边界值
                xyzLower = [0, 0, 30];  % x, y, z 的下界
                xyzUpper = [500, 500, 70];  % x, y, z 的上界
            end
            
            % 为子问题的每个航点（不包括固定的第一个航点）设置边界
            % obj.D = (segmentSize - 1) * 3，所以需要 (segmentSize - 1) 个航点的边界
            numWaypointsInSegment = segmentSize - 1;  % 不包括固定的第一个航点
            obj.lower = repmat(xyzLower, 1, numWaypointsInSegment);  % 1 x obj.D
            obj.upper = repmat(xyzUpper, 1, numWaypointsInSegment);  % 1 x obj.D
            
            % 确保是行向量
            obj.lower = obj.lower(:)';
            obj.upper = obj.upper(:)';
            
            % 验证维度
            if length(obj.lower) ~= obj.D || length(obj.upper) ~= obj.D
                error('UAVPathPlanningSegment: 边界维度不匹配。obj.D = %d, lower长度 = %d, upper长度 = %d', ...
                    obj.D, length(obj.lower), length(obj.upper));
            end
            
            % 编码方式
            obj.encoding = originalProblem.encoding;
            
            % 最大函数评估次数（如果提供了maxFE参数则使用它，否则使用原始问题的maxFE）
            if nargin >= 6 && ~isempty(maxFE)
                obj.maxFE = maxFE;
            else
                obj.maxFE = originalProblem.maxFE;
            end
            
            % 种群大小
            obj.N = originalProblem.N;
        end
        
        function Setting(obj)
            %Setting - 子问题设置（继承父类，无需额外设置）
            % 所有设置已在构造函数中完成
        end
        
        function Population = Initialization(obj, N)
            %Initialization - 生成初始种群
            %
            %   基于预设航点生成初始种群，添加随机扰动
            
            if nargin < 2
                N = obj.N;
            end
            
            % 获取段内的预设航点（不包括固定的第一个航点）
            segmentSize = obj.endIdx - obj.startIdx + 1;
            if obj.startIdx < obj.endIdx
                presetSegmentWaypoints = obj.fullWaypoints(obj.startIdx+1:obj.endIdx, :);  % (segmentSize-1) x 3
            else
                % 如果段只有一个航点（不应该发生，但为了安全）
                presetSegmentWaypoints = [];
            end
            
            % 生成初始种群
            PopDec = zeros(N, obj.D);
            
            % 计算扰动范围
            perturbationRange = (obj.upper(1) - obj.lower(1)) * 0.01;  % 1%的扰动
            
            for i = 1:N
                % 基于预设航点添加随机扰动
                waypoints = presetSegmentWaypoints + randn(size(presetSegmentWaypoints)) * perturbationRange;
                
                % 限制在边界内
                waypoints = max(waypoints, repmat(obj.lower(1:3), size(waypoints, 1), 1));
                waypoints = min(waypoints, repmat(obj.upper(1:3), size(waypoints, 1), 1));
                
                % 转换为决策变量格式
                PopDec(i, :) = reshape(waypoints', 1, []);
            end
            
            % 使用CalDec进一步修复
            PopDec = obj.CalDec(PopDec);
            
            % 创建SOLUTION对象
            Population = SOLUTION(PopDec);
        end
        
        function PopDec = CalDec(obj, PopDec)
            %CalDec - 修复无效解
            %
            %   确保决策变量在边界内，并修复航点位置
            
            % 验证维度匹配
            [N, D] = size(PopDec);
            if D ~= obj.D
                error('UAVPathPlanningSegment/CalDec: PopDec的列数(%d)与obj.D(%d)不匹配', D, obj.D);
            end
            if length(obj.lower) ~= obj.D || length(obj.upper) ~= obj.D
                error('UAVPathPlanningSegment/CalDec: 边界维度不匹配。obj.D = %d, lower长度 = %d, upper长度 = %d', ...
                    obj.D, length(obj.lower), length(obj.upper));
            end
            
            % 确保边界是行向量
            if size(obj.lower, 1) > 1
                obj.lower = obj.lower(:)';
            end
            if size(obj.upper, 1) > 1
                obj.upper = obj.upper(:)';
            end
            
            % 调用父类的CalDec方法
            PopDec = CalDec@PROBLEM(obj, PopDec);
            
            [N, D] = size(PopDec);
            segmentSize = obj.endIdx - obj.startIdx + 1;
            numWaypointsInSegment = segmentSize - 1;  % 不包括固定的第一个航点
            
            % 修复航点位置
            for i = 1:N
                % 提取航点坐标
                waypoints = reshape(PopDec(i, :), 3, numWaypointsInSegment)';  % numWaypointsInSegment x 3
                
                % 修复航点位置：将航点移出建筑物
                for j = 1:numWaypointsInSegment
                    waypoints(j, :) = obj.originalProblem.repairWaypointOutsideObstacle(waypoints(j, :));
                end
                
                % 确保在边界内
                % 使用原始问题的边界（每个航点的x, y, z使用相同的边界值）
                lowerBound = obj.originalProblem.lower(1:3);  % 1 x 3
                upperBound = obj.originalProblem.upper(1:3);  % 1 x 3
                waypoints = max(waypoints, repmat(lowerBound(:)', size(waypoints, 1), 1));
                waypoints = min(waypoints, repmat(upperBound(:)', size(waypoints, 1), 1));
                
                % 转换回决策变量格式
                PopDec(i, :) = reshape(waypoints', 1, []);
            end
        end
        
        function PopObj = CalObj(obj, PopDec)
            %CalObj - 计算目标函数值
            %
            %   将子问题的解嵌入完整路径，然后计算完整路径的目标值
            
            [N, D] = size(PopDec);
            segmentSize = obj.endIdx - obj.startIdx + 1;
            numWaypointsInSegment = segmentSize - 1;  % 不包括固定的第一个航点
            
            PopObj = zeros(N, obj.M);
            
            for i = 1:N
                % 提取子问题的航点
                segmentWaypoints = reshape(PopDec(i, :), 3, numWaypointsInSegment)';  % numWaypointsInSegment x 3
                
                % 构建完整路径（包括固定航点）
                fullPath = obj.fullWaypoints;  % 复制完整路径
                
                % 更新当前段的航点
                % 第一个航点固定
                fullPath(obj.startIdx, :) = obj.fixedStartWaypoint;
                % 其他航点使用子问题的解
                fullPath(obj.startIdx+1:obj.endIdx, :) = segmentWaypoints;
                
                % 如果使用固定的结束航点
                if obj.useFixedEnd
                    fullPath(obj.endIdx, :) = obj.fixedEndWaypoint;
                end
                
                % 将完整路径转换为决策变量格式
                fullDec = reshape(fullPath', 1, []);  % 1 x (numWaypoints * 3)
                
                % 计算完整路径的目标值
                fullObj = obj.originalProblem.CalObj(fullDec);
                PopObj(i, :) = fullObj;
            end
        end
        
        function PopCon = CalCon(obj, PopDec)
            %CalCon - 计算约束违反度
            %
            %   将子问题的解嵌入完整路径，然后计算完整路径的约束违反度
            
            [N, D] = size(PopDec);
            segmentSize = obj.endIdx - obj.startIdx + 1;
            numWaypointsInSegment = segmentSize - 1;  % 不包括固定的第一个航点
            numWaypoints = size(obj.fullWaypoints, 1);
            
            % 计算约束数量（与原始问题相同）
            % 约束0：航点方向约束（与起点到终点向量的角度约束）：numWaypoints - 1
            % 约束1：连续三个航点之间的夹角约束：numWaypoints - 2
            % 约束2：航点不在建筑物中：numWaypoints
            % 约束3：连线不穿过建筑物：numWaypoints - 1
            % 约束4：XY平面边界约束（xyBound）：numWaypoints
            numConstraints = (numWaypoints - 1) + max(0, numWaypoints - 2) + numWaypoints + (numWaypoints - 1) + numWaypoints;
            PopCon = zeros(N, numConstraints);
            
            for i = 1:N
                % 提取子问题的航点
                segmentWaypoints = reshape(PopDec(i, :), 3, numWaypointsInSegment)';  % numWaypointsInSegment x 3
                
                % 构建完整路径（包括固定航点）
                fullPath = obj.fullWaypoints;  % 复制完整路径
                
                % 更新当前段的航点
                % 第一个航点固定
                fullPath(obj.startIdx, :) = obj.fixedStartWaypoint;
                % 其他航点使用子问题的解
                fullPath(obj.startIdx+1:obj.endIdx, :) = segmentWaypoints;
                
                % 如果使用固定的结束航点
                if obj.useFixedEnd
                    fullPath(obj.endIdx, :) = obj.fixedEndWaypoint;
                end
                
                % 将完整路径转换为决策变量格式
                fullDec = reshape(fullPath', 1, []);  % 1 x (numWaypoints * 3)
                
                % 计算完整路径的约束违反度
                fullCon = obj.originalProblem.CalCon(fullDec);
                PopCon(i, :) = fullCon;
            end
            
            % 注意：这里返回完整路径的约束，因为约束可能涉及相邻航点
        end
        
        function R = GetOptimum(obj, N)
            %GetOptimum - 获取参考点（用于超体积计算）
            %   使用原始问题的参考点
            
            % 检查originalProblem是否已设置（可能在构造函数调用时还未设置）
            % 使用try-catch来处理可能的访问错误
            try
                % 检查属性是否存在且不为空
                if ~isprop(obj, 'originalProblem') || isempty(obj.originalProblem)
                    % 如果originalProblem未设置，返回默认参考点
                    % 默认参考点：目标1=105, 目标2=3, 目标3=0.1（3目标）
                    R = [105, 3, 0.1];
                else
                    % 尝试使用原始问题的参考点
                    R = obj.originalProblem.GetOptimum(N);
                end
            catch ME
                % 如果访问失败（例如originalProblem还未初始化），返回默认参考点
                % 这通常发生在PROBLEM构造函数调用GetOptimum时
                R = [105, 3, 0.1];
            end
        end
        
        function R = GetPF(obj)
            %GetPF - 获取Pareto前沿（子问题没有独立的PF）
            %   返回空数组，因为子问题不是独立的问题
            R = [];
        end
    end
end
