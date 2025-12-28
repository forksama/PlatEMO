classdef UAVPathPlanning < PROBLEM
% <multi> <real> <constrained/none>
% 无人机路径规划多目标优化问题
% 
% 问题描述：
% 给定一个折线的预设路径，根据无人机预设的飞行速度，在实际航行路线上
% 每间隔TTT时间打一个航点。无人机的实际路径是N个航点相连的折线。
% 在区域内随机分布着一些地面基站，在每个航点都可以求得无人机当前连接的
% 基站的信号强度；无人机在每个航点，会根据信号强度进行是否切换的判断。
%
% 三个优化目标：
% 1. 最大化全程的平均信号强度（转换为最小化负的平均信号强度）
% 2. 最小化切换次数
% 3. 最小化偏离预设路径的距离
%
% 参数说明：
% numBS --- 10 --- 基站数量（已废弃，基站数量现在等于建筑物数量，每个建筑物顶部都有一个基站）
% velocity --- 10 --- 无人机最大速度（m/s）
% TTT --- 1 --- 时间间隔（s）
% switchThreshold --- -80 --- 切换阈值（dBm）
% obstacleMethod --- 'default' --- 障碍物与预设路径生成方法（字符串）
% 
% 注意：航点数量不再由用户指定，而是根据预设路径总长度和
%       无人机速度自动计算：numWaypoints = pathLength / (velocity * 0.8 * TTT)
%       航点在预设路径上按距离均匀分布
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
        presetPath;      % 预设路径（N_preset x 3，包含x, y, z坐标）
        baseStations;    % 基站位置（numBS x 3，包含x, y, z坐标）
        obstacles;       % 障碍物信息（N_obstacle x 5，每行：[x_min, y_min, x_max, y_max, height]）
        velocity;        % 无人机最大速度（m/s）
        TTT;             % 时间间隔（s）
        numBS;           % 基站数量
        switchThreshold; % 切换阈值（dBm）
        obstacleMethod;  % 障碍物与预设路径生成方法（字符串）
        pathLength;      % 预设路径总长度
        numWaypoints;    % 航点数量（自动计算）
        presetWaypoints; % 预设航点位置（在预设路径上均匀分布，numWaypoints x 3）
    end
    
    methods
        %% 获取切换阈值（公共方法）
        function threshold = getSwitchThreshold(obj)
            threshold = obj.switchThreshold;
        end
        
        %% 默认设置
        function Setting(obj)
            % 参数设置
            if isempty(obj.M); obj.M = 3; end  % 三个目标
            
            % 注意：D维度会自动计算，忽略用户传递的D参数
            % 保存用户可能传递的lower和upper（如果有），但会在计算D后重新设置
            userLower = obj.lower;
            userUpper = obj.upper;
            
            % 获取参数（使用ParameterSet获取，如果obj.parameter被指定则使用，否则使用默认值）
            % 参数格式：{numBS, velocity, TTT, switchThreshold, obstacleMethod}
            % 注意：不再需要numWaypoints参数，航点数量将自动计算
            if isempty(obj.parameter)
                numBS = 10;
                velocity = 10;
                TTT = 1;
                switchThreshold = -80;
                obstacleMethod = 'default';
            else
                params = obj.parameter;
                if iscell(params) && length(params) >= 4
                    numBS = params{1};
                    velocity = params{2};
                    TTT = params{3};
                    switchThreshold = params{4};
                    if length(params) >= 5
                        obstacleMethod = params{5};
                    else
                        obstacleMethod = 'default';
                    end
                else
                    numBS = 10;
                    velocity = 10;
                    TTT = 1;
                    switchThreshold = -80;
                    obstacleMethod = 'default';
                end
            end
            
            obj.numBS = numBS;
            obj.velocity = velocity;
            obj.TTT = TTT;
            obj.switchThreshold = switchThreshold;
            obj.obstacleMethod = obstacleMethod;
            
            % 生成或加载预设路径、基站位置和障碍物
            % 注意：基站数量等于建筑物数量，文件名使用obstacleMethod标识
            file = sprintf('UAVPathPlanning-%s.mat', obstacleMethod);
            file = fullfile(fileparts(mfilename('fullpath')), file);
            
            if exist(file, 'file') == 2
                load(file, 'presetPath', 'baseStations', 'obstacles');
                % 检查数据维度，如果是2D则转换为3D
                if size(presetPath, 2) == 2
                    presetPath = [presetPath, 50*ones(size(presetPath, 1), 1)];  % 添加z坐标，默认50米
                end
                if size(baseStations, 2) == 2
                    baseStations = [baseStations, zeros(size(baseStations, 1), 1)];  % 添加z坐标，默认0
                end
                % 如果没有障碍物数据，生成默认障碍物
                if ~exist('obstacles', 'var') || isempty(obstacles)
                    obstacles = obj.generateObstacles(obstacleMethod);
                    baseStations = obj.generateBaseStationsOnObstacles(numBS, obstacles);
                    save(file, 'presetPath', 'baseStations', 'obstacles', '-append');
                end
            else
                % 生成预设路径和障碍物（根据obstacleMethod）
                [presetPath, obstacles] = obj.generatePresetPathAndObstacles(obstacleMethod);
                
                % 在建筑物顶端生成基站位置
                baseStations = obj.generateBaseStationsOnObstacles(numBS, obstacles);
                
                % 保存数据
                save(file, 'presetPath', 'baseStations', 'obstacles');
            end
            
            obj.obstacles = obstacles;
            
            obj.presetPath = presetPath;
            obj.baseStations = baseStations;
            
            % 更新基站数量为实际生成的基站数量（等于建筑物数量）
            obj.numBS = size(baseStations, 1);
            
            % 计算预设路径总长度（3D距离）
            obj.pathLength = 0;
            for i = 1:size(obj.presetPath, 1)-1
                obj.pathLength = obj.pathLength + norm(obj.presetPath(i+1,:) - obj.presetPath(i,:));
            end
            
            % 根据预设路径总长度和无人机速度自动计算航点数量
            % 假设无人机以最大速度的0.8倍运动
            actualVelocity = obj.velocity * 0.8;
            distancePerWaypoint = actualVelocity * obj.TTT;  % 每个航点之间的距离
            obj.numWaypoints = max(2, ceil(obj.pathLength / distancePerWaypoint));  % 至少2个航点
            
            % 设置决策变量维度（N个航点，每个3维坐标：x, y, z）
            % 注意：D维度由航点数量自动计算，忽略用户传递的D参数
            obj.D = obj.numWaypoints * 3;
            
            % 在预设路径上按距离均匀分布生成预设航点
            obj.presetWaypoints = obj.generateUniformWaypoints();
            
            % 设置决策变量的上下界
            % 如果用户传递了lower/upper且维度匹配，则使用用户的值；否则使用默认值
            if ~isempty(userLower) && isequal(size(userLower), [1, obj.D])
                obj.lower = userLower;
            else
                % 默认下界：x, y在0-100，z在30-70米（高度范围，预设路径在50米左右）
                obj.lower = zeros(1, obj.D);
                % z坐标的下界设为30米（允许一定的高度变化范围）
                for i = 3:3:obj.D
                    obj.lower(i) = 30;
                end
            end
            
            if ~isempty(userUpper) && isequal(size(userUpper), [1, obj.D])
                obj.upper = userUpper;
            else
                % 默认上界：x, y在0-100，z在30-70米（高度范围，预设路径在50米左右）
                obj.upper = 100 * ones(1, obj.D);
                % z坐标的上界设为70米（允许一定的高度变化范围）
                for i = 3:3:obj.D
                    obj.upper(i) = 70;
                end
            end
            
            obj.encoding = 'real';
        end
        
        %% 生成初始种群
        function Population = Initialization(obj, N)
            %Initialization - 生成初始种群
            %
            %   基于预设路径上的航点生成初始种群，添加随机扰动
            %
            %   输入：
            %       N - 种群大小（可选，默认使用obj.N）
            %
            %   输出：
            %       Population - SOLUTION对象数组
            
            if nargin < 2
                N = obj.N;
            end
            
            % 确保presetWaypoints已经生成
            if isempty(obj.presetWaypoints)
                obj.presetWaypoints = obj.generateUniformWaypoints();
            end
            
            % 基于预设航点生成初始种群
            PopDec = zeros(N, obj.D);
            
            % 计算扰动范围（可以根据问题规模调整）
            % 扰动范围设为决策空间范围的5%，即约5米
            perturbationRange = (obj.upper(1) - obj.lower(1)) * 0.05;
            
            for i = 1:N
                % 以presetWaypoints为基础，添加随机扰动
                waypoints = obj.presetWaypoints + randn(size(obj.presetWaypoints)) * perturbationRange;
                
                % 限制在边界内（3D坐标：x, y, z）
                waypoints = max(waypoints, repmat(obj.lower(1:3), size(waypoints, 1), 1));
                waypoints = min(waypoints, repmat(obj.upper(1:3), size(waypoints, 1), 1));
                
                % 转换为决策变量格式（D = numWaypoints × 3）
                % 将 numWaypoints × 3 的矩阵转换为 1 × D 的向量
                PopDec(i,:) = reshape(waypoints', 1, []);
            end
            
            % 创建SOLUTION对象
            Population = SOLUTION(PopDec);
        end
        
        %% 计算目标函数值
        function PopObj = CalObj(obj, PopDec)
            [N, D] = size(PopDec);
            numWaypoints = D / 3;
            PopObj = zeros(N, obj.M);
            
            for i = 1:N
                % 提取航点坐标（3D：x, y, z）
                waypoints = reshape(PopDec(i,:), 3, numWaypoints)';  % numWaypoints x 3
                
                % 目标1：最大化平均信号强度（转换为最小化负的平均信号强度）
                avgSignal = obj.calculateAverageSignal(waypoints);
                PopObj(i, 1) = -avgSignal;  % 取负值，因为要最小化
                
                % 目标2：最小化切换次数
                switchCount = obj.calculateSwitchCount(waypoints);
                PopObj(i, 2) = switchCount;
                
                % 目标3：最小化偏离预设路径的距离
                deviation = obj.calculatePathDeviation(waypoints);
                PopObj(i, 3) = deviation;
            end
        end
        
        %% 计算平均信号强度
        function avgSignal = calculateAverageSignal(obj, waypoints)
            % waypoints: numWaypoints x 3 (x, y, z)
            numWaypoints = size(waypoints, 1);
            totalSignal = 0;
            
            for j = 1:numWaypoints
                % 计算当前航点到所有基站的距离（3D距离）
                distances = sqrt(sum((obj.baseStations - repmat(waypoints(j,:), obj.numBS, 1)).^2, 2));
                
                % 计算信号强度（考虑视距/非视距）
                signalStrengths = zeros(obj.numBS, 1);
                for k = 1:obj.numBS
                    % 检查是否有视距（LOS）
                    hasLOS = obj.checkLineOfSight(waypoints(j,:), obj.baseStations(k,:));
                    
                    distances(k) = max(distances(k), 0.1);
                    if hasLOS
                        % 视距（LOS）路径损耗模型
                        signalStrengths(k) = -20*log10(distances(k)) - 61.4;  % dBm
                    else
                        % 非视距（NLOS）路径损耗模型（更大的衰减）
                        signalStrengths(k) = -40*log10(distances(k)) - 72;  % dBm
                    end
                end
                
                % 选择信号最强的基站
                [maxSignal, ~] = max(signalStrengths);
                totalSignal = totalSignal + maxSignal;
            end
            
            avgSignal = totalSignal / numWaypoints;
        end
        
        %% 计算切换次数
        function switchCount = calculateSwitchCount(obj, waypoints)
            % waypoints: numWaypoints x 3 (x, y, z)
            numWaypoints = size(waypoints, 1);
            switchCount = 0;
            previousBS = 0;  % 上一个航点连接的基站索引
            
            for j = 1:numWaypoints
                % 计算当前航点到所有基站的距离（3D距离）
                distances = sqrt(sum((obj.baseStations - repmat(waypoints(j,:), obj.numBS, 1)).^2, 2));
                
                % 计算信号强度（考虑视距/非视距）
                signalStrengths = zeros(obj.numBS, 1);
                for k = 1:obj.numBS
                    % 检查是否有视距（LOS）
                    hasLOS = obj.checkLineOfSight(waypoints(j,:), obj.baseStations(k,:));
                    
                    distances(k) = max(distances(k), 0.1);
                    if hasLOS
                        % 视距（LOS）路径损耗模型
                        signalStrengths(k) = -20*log10(distances(k)) - 61.4;  % dBm
                    else
                        % 非视距（NLOS）路径损耗模型（更大的衰减）
                        signalStrengths(k) = -40*log10(distances(k)) - 72;  % dBm
                    end
                end
                
                % 选择信号最强的基站
                [maxSignal, currentBS] = max(signalStrengths);
                
                % 判断是否需要切换
                % 切换的定义：
                % 1. 信号强度低于阈值时才改变基站为信号最强的基站
                % 2. 一改变基站就算切换
                % 即：信号强度 < 阈值 → 改变到信号最强的基站，且一旦改变就算切换
                if j > 1
                    % 检查信号强度是否低于阈值
                    if maxSignal < obj.switchThreshold
                        % 信号强度低于阈值，改变基站为信号最强的基站
                        if currentBS ~= previousBS
                            % 基站改变 → 切换
                            switchCount = switchCount + 1;
                        end
                        % 更新连接的基站（改变到信号最强的基站）
                        previousBS = currentBS;
                    end
                else
                    % 第一个航点，初始化基站连接，不计为切换
                    previousBS = currentBS;
                end
            end
        end
        
        %% 计算偏离预设路径的距离
        function deviation = calculatePathDeviation(obj, waypoints)
            % waypoints: numWaypoints x 3 (x, y, z)
            numWaypoints = size(waypoints, 1);
            totalDeviation = 0;
            
            % 使用预设航点（在预设路径上均匀分布）
            presetWaypoints = obj.presetWaypoints;
            
            % 确保航点数量匹配
            if size(waypoints, 1) ~= size(presetWaypoints, 1)
                error('航点数量不匹配：实际路径 %d 个航点，预设路径 %d 个航点', ...
                      size(waypoints, 1), size(presetWaypoints, 1));
            end
            
            % 计算每个实际航点到对应预设航点的距离（3D距离）
            for j = 1:numWaypoints
                dist = norm(waypoints(j,:) - presetWaypoints(j,:));
                totalDeviation = totalDeviation + dist;
            end
            
            deviation = totalDeviation / numWaypoints;  % 平均偏离距离
        end
        
        %% 在预设路径上按距离均匀分布生成航点
        function presetWaypoints = generateUniformWaypoints(obj)
            % 在预设路径上按距离均匀分布生成航点
            % 航点数量由 pathLength / (velocity * 0.8 * TTT) 决定
            
            numPresetPoints = size(obj.presetPath, 1);
            numWaypoints = obj.numWaypoints;
            
            % 计算预设路径上每个段的长度和累积长度
            segmentLengths = zeros(numPresetPoints-1, 1);
            for i = 1:numPresetPoints-1
                segmentLengths(i) = norm(obj.presetPath(i+1,:) - obj.presetPath(i,:));
            end
            cumulativeLengths = [0; cumsum(segmentLengths)];
            
            % 计算每个航点在预设路径上的目标距离（均匀分布）
            targetDistances = linspace(0, obj.pathLength, numWaypoints)';
            
            % 在预设路径上插值生成航点（3D坐标）
            presetWaypoints = zeros(numWaypoints, 3);
            for j = 1:numWaypoints
                targetDist = targetDistances(j);
                
                % 找到目标距离所在的段
                segmentIdx = find(cumulativeLengths <= targetDist, 1, 'last');
                
                if segmentIdx >= numPresetPoints
                    % 如果超出范围，使用最后一个点
                    presetWaypoints(j,:) = obj.presetPath(end,:);
                elseif segmentIdx == 0
                    % 如果小于0，使用第一个点
                    presetWaypoints(j,:) = obj.presetPath(1,:);
                else
                    % 在当前段内线性插值（3D插值）
                    dist1 = cumulativeLengths(segmentIdx);
                    dist2 = cumulativeLengths(segmentIdx+1);
                    
                    if dist2 > dist1
                        alpha = (targetDist - dist1) / (dist2 - dist1);
                        presetWaypoints(j,:) = (1-alpha)*obj.presetPath(segmentIdx,:) + ...
                                              alpha*obj.presetPath(segmentIdx+1,:);
                    else
                        presetWaypoints(j,:) = obj.presetPath(segmentIdx,:);
                    end
                end
            end
        end
        
        %% 生成用于超体积计算的参考点
        function R = GetOptimum(obj, N)
            % 返回参考点（用于超体积计算）
            % HV计算逻辑：
            % - fmin = min(min(PopObj,[],1), zeros(1,M))  % 取实际最小值和0的较小者
            % - fmax = max(optimum,[],1)                   % 从optimum取最大值作为上界
            % - 归一化：(PopObj - fmin) / ((fmax - fmin) * 1.1)
            % - 删除任何维度>1的点（归一化后）
            %
            % 关键：参考点必须比所有实际解都"差"（所有目标值都更大）
            % 对于最小化问题，参考点应该是所有目标的上界
            
            numWaypoints = obj.numWaypoints;
            
            % 设置足够大的参考点，确保覆盖所有可能的解
            % 使用非常保守的上界，避免归一化后解被删除
            % 目标1（负信号强度，越小越好）：设为50（比任何可能的负值都大）
            % 目标2（切换次数，越小越好）：设为航点数*3（足够大）
            % 目标3（偏离距离，越小越好）：设为1000（足够大）
            
            R = [50, numWaypoints * 3, 1000];
        end
        
        %% 生成预设路径和障碍物
        function [presetPath, obstacles] = generatePresetPathAndObstacles(obj, method)
            % 根据方法名称生成预设路径和障碍物
            
            if strcmpi(method, 'default')
                % 生成障碍物
                obstacles = obj.generateObstacles(method);
                
                % 生成预设路径
                presetPath = obj.generatePresetPath(method);
            else
                % 其他方法可以在这里扩展
                error('未知的障碍物与预设路径生成方法: %s', method);
            end
        end
        
        %% 生成预设路径
        function presetPath = generatePresetPath(obj, method)
            % 生成预设路径
            % 起点：(5, 5, 50)
            % 终点：(85, 85, 50)
            % 中间转折点：随机生成(20(m+0.5)-5, 20(n+0.5)-5, 50)，0<=m,n<=4
            % 要求：路径不交叉，没有重复点
            % 转折点数量由算法自动确定（包含所有可能的中间点）
            
            if strcmpi(method, 'default')
                % 计算可能的中间点坐标
                % 20(m+0.5)-5 = 20m + 10 - 5 = 20m + 5
                % 当m=0: 5, m=1: 25, m=2: 45, m=3: 65, m=4: 85
                % 当m=5: 105（超出范围），所以m,n的范围应该是0<=m,n<=4
                
                possible_x = 20 * (0:4) + 5;  % [5, 25, 45, 65, 85]
                possible_y = 20 * (0:4) + 5;  % [5, 25, 45, 65, 85]
                
                % 起点和终点
                start_point = [5, 5, 50];
                end_point = [85, 85, 50];
                
                % 生成所有可能的中间点（排除起点和终点）
                [X, Y] = meshgrid(possible_x, possible_y);
                all_points = [X(:), Y(:), 50*ones(length(X(:)), 1)];
                
                % 排除起点和终点
                valid_points = [];
                for i = 1:size(all_points, 1)
                    pt = all_points(i, :);
                    % 排除起点
                    if abs(pt(1) - start_point(1)) < 0.1 && abs(pt(2) - start_point(2)) < 0.1
                        continue;
                    end
                    % 排除终点
                    if abs(pt(1) - end_point(1)) < 0.1 && abs(pt(2) - end_point(2)) < 0.1
                        continue;
                    end
                    valid_points = [valid_points; pt];
                end
                
                % 使用最近邻算法对所有中间点进行排序，确保路径不交叉且无重复
                % 包含所有可能的中间点（不再限制数量）
                num_intermediate = size(valid_points, 1);
                selected_points = zeros(num_intermediate, 3);
                used_indices = false(size(valid_points, 1), 1);
                
                % 从起点开始
                current_point = start_point;
                
                for i = 1:num_intermediate
                    % 找到未使用且距离当前点最近的点
                    distances = inf(size(valid_points, 1), 1);
                    for j = 1:size(valid_points, 1)
                        if ~used_indices(j)
                            distances(j) = norm(valid_points(j, 1:2) - current_point(1:2));
                        end
                    end
                    
                    [~, nearest_idx] = min(distances);
                    selected_points(i, :) = valid_points(nearest_idx, :);
                    used_indices(nearest_idx) = true;
                    current_point = selected_points(i, :);
                end
                
                % 检查并确保路径不交叉
                path_points = [start_point; selected_points; end_point];
                path_points = obj.ensureNoCrossing(path_points);
                
                presetPath = path_points;
            else
                error('未知的预设路径生成方法: %s', method);
            end
        end
        
        %% 确保路径不交叉
        function path_points = ensureNoCrossing(obj, path_points)
            % 确保路径不交叉（使用最近邻排序）
            
            num_points = size(path_points, 1);
            if num_points <= 3
                return;  % 少于3个点不会交叉
            end
            
            % 使用最近邻算法重新排序（除了起点和终点）
            if num_points > 3
                start_point = path_points(1, :);
                end_point = path_points(end, :);
                intermediate_points = path_points(2:end-1, :);
                
                % 使用最近邻排序
                sorted_intermediate = zeros(size(intermediate_points));
                used = false(size(intermediate_points, 1), 1);
                current = start_point;
                
                for i = 1:size(intermediate_points, 1)
                    distances = inf(size(intermediate_points, 1), 1);
                    for j = 1:size(intermediate_points, 1)
                        if ~used(j)
                            distances(j) = norm(intermediate_points(j, 1:2) - current(1:2));
                        end
                    end
                    [~, nearest_idx] = min(distances);
                    sorted_intermediate(i, :) = intermediate_points(nearest_idx, :);
                    used(nearest_idx) = true;
                    current = sorted_intermediate(i, :);
                end
                
                path_points = [start_point; sorted_intermediate; end_point];
            end
        end
        
        %% 生成障碍物
        function obstacles = generateObstacles(obj, method)
            % 根据方法名称生成障碍物
            % obstacles: N_obstacle x 5，每行：[x_min, y_min, x_max, y_max, height]
            
            if strcmpi(method, 'default')
                % 默认方法：网格布局
                % 1<=x<=5，1<=y<=5
                % 在横坐标20(x-0.5)~20x，纵坐标20(y-0.5)~20y处
                % 都有地面为正方形的高度在30~60间随机变化的长方体建筑物障碍物
                % 
                % 例如：
                % x=1: 横坐标 20(1-0.5)~20*1 = 10~20
                % x=2: 横坐标 20(2-0.5)~20*2 = 30~40
                % x=3: 横坐标 20(3-0.5)~20*3 = 50~60
                % x=4: 横坐标 20(4-0.5)~20*4 = 70~80
                % x=5: 横坐标 20(5-0.5)~20*5 = 90~100
                % 
                % 这意味着20~30, 40~50, 60~70, 80~90之间没有建筑物
                obstacles = [];
                for x = 1:5
                    for y = 1:5
                        x_min = 20 * (x - 0.5);
                        y_min = 20 * (y - 0.5);
                        x_max = 20 * x;
                        y_max = 20 * y;
                        height = 30 + (60 - 30) * rand();  % 高度在30~60米之间随机
                        obstacles = [obstacles; x_min, y_min, x_max, y_max, height];
                    end
                end
            else
                % 其他方法可以在这里扩展
                error('未知的障碍物生成方法: %s', method);
            end
        end
        
        %% 在建筑物顶端生成基站
        function baseStations = generateBaseStationsOnObstacles(obj, numBS, obstacles)
            % 在每个建筑物顶端生成基站
            % 每个基站位于一个建筑物的中心位置，高度为建筑物高度+5米
            % 注意：基站数量等于建筑物数量，numBS参数将被忽略
            
            numObstacles = size(obstacles, 1);
            baseStations = zeros(numObstacles, 3);
            
            for i = 1:numObstacles
                obs = obstacles(i, :);
                
                % 计算建筑物中心位置
                x_center = (obs(1) + obs(3)) / 2;
                y_center = (obs(2) + obs(4)) / 2;
                z_height = obs(5) + 5;  % 建筑物高度 + 5米
                
                % 在建筑物顶端添加小随机偏移（模拟基站安装位置）
                x_offset = (obs(3) - obs(1)) * 0.2 * (rand() - 0.5);  % ±20%的偏移
                y_offset = (obs(4) - obs(2)) * 0.2 * (rand() - 0.5);
                
                baseStations(i, :) = [x_center + x_offset, y_center + y_offset, z_height];
            end
        end
        
        %% 获取两点之间的障碍物
        function relevantObstacles = getObstaclesBetweenPoints(obj, point1, point2)
            % 筛选出与线段（point1到point2）相交的障碍物
            % 只返回UAV与基站之间的建筑物，而非所有建筑物
            % point1, point2: 1x3向量 [x, y, z]
            % relevantObstacles: N_relevant x 5，只包含与线段相交的障碍物
            
            % 计算线段的bounding box（用于快速排除）
            seg_x_min = min(point1(1), point2(1));
            seg_x_max = max(point1(1), point2(1));
            seg_y_min = min(point1(2), point2(2));
            seg_y_max = max(point1(2), point2(2));
            
            relevantObstacles = [];
            
            % 遍历所有障碍物，筛选出与线段相交的
            for i = 1:size(obj.obstacles, 1)
                obs = obj.obstacles(i, :);
                x_min = obs(1);
                y_min = obs(2);
                x_max = obs(3);
                y_max = obs(4);
                
                % 快速排除：如果线段的bounding box与障碍物的bounding box不相交，跳过
                if seg_x_max < x_min || seg_x_min > x_max || ...
                   seg_y_max < y_min || seg_y_min > y_max
                    continue;
                end
                
                % 检查线段是否与障碍物的水平投影相交
                if obj.segmentIntersectsRectangleFast(point1(1:2), point2(1:2), ...
                                                      [x_min, y_min], [x_max, y_max])
                    % 如果相交，添加到相关障碍物列表
                    relevantObstacles = [relevantObstacles; obs];
                end
            end
        end
        
        %% 检查视距（Line of Sight）- 优化版本
        function hasLOS = checkLineOfSight(obj, point1, point2)
            % 检查两点之间是否有视距（是否被障碍物阻挡）
            % point1, point2: 1x3向量 [x, y, z]
            % hasLOS: true表示有视距，false表示被障碍物阻挡
            % 
            % 优化策略：
            % 1. 只检查UAV与基站之间的建筑物（与线段相交的障碍物）
            % 2. 简化计算：只检查线段在障碍物区域内的最低高度
            
            hasLOS = true;
            
            % 先筛选出与线段相交的障碍物（只检查UAV与基站之间的建筑物）
            relevantObstacles = obj.getObstaclesBetweenPoints(point1, point2);
            
            % 如果没有相关障碍物，直接返回true
            if isempty(relevantObstacles)
                return;
            end
            
            % 只遍历与线段相交的障碍物
            for i = 1:size(relevantObstacles, 1)
                obs = relevantObstacles(i, :);
                x_min = obs(1);
                y_min = obs(2);
                x_max = obs(3);
                y_max = obs(4);
                height = obs(5);
                
                % 如果水平投影相交，检查高度是否被阻挡
                % 简化：计算线段在障碍物矩形内的最低高度
                % 使用参数方程：P(t) = point1 + t*(point2 - point1), t in [0,1]
                
                % 找到线段在矩形内的t值范围
                t_in_rect = [];
                
                % 检查起点和终点是否在矩形内
                if point1(1) >= x_min && point1(1) <= x_max && ...
                   point1(2) >= y_min && point1(2) <= y_max
                    t_in_rect = [t_in_rect, 0];
                end
                if point2(1) >= x_min && point2(1) <= x_max && ...
                   point2(2) >= y_min && point2(2) <= y_max
                    t_in_rect = [t_in_rect, 1];
                end
                
                % 检查与四条边的交点
                if abs(point2(1) - point1(1)) > 1e-10
                    % 左边界
                    t = (x_min - point1(1)) / (point2(1) - point1(1));
                    if t > 0 && t < 1
                        y_at_t = point1(2) + t * (point2(2) - point1(2));
                        if y_at_t >= y_min && y_at_t <= y_max
                            t_in_rect = [t_in_rect, t];
                        end
                    end
                    % 右边界
                    t = (x_max - point1(1)) / (point2(1) - point1(1));
                    if t > 0 && t < 1
                        y_at_t = point1(2) + t * (point2(2) - point1(2));
                        if y_at_t >= y_min && y_at_t <= y_max
                            t_in_rect = [t_in_rect, t];
                        end
                    end
                end
                
                if abs(point2(2) - point1(2)) > 1e-10
                    % 下边界
                    t = (y_min - point1(2)) / (point2(2) - point1(2));
                    if t > 0 && t < 1
                        x_at_t = point1(1) + t * (point2(1) - point1(1));
                        if x_at_t >= x_min && x_at_t <= x_max
                            t_in_rect = [t_in_rect, t];
                        end
                    end
                    % 上边界
                    t = (y_max - point1(2)) / (point2(2) - point1(2));
                    if t > 0 && t < 1
                        x_at_t = point1(1) + t * (point2(1) - point1(1));
                        if x_at_t >= x_min && x_at_t <= x_max
                            t_in_rect = [t_in_rect, t];
                        end
                    end
                end
                
                % 计算线段在障碍物区域内的最低高度
                if ~isempty(t_in_rect)
                    % 找到t值范围
                    t_min = max(0, min(t_in_rect));
                    t_max = min(1, max(t_in_rect));
                    
                    % 计算该范围内的最低z坐标（线性插值，最低点在端点）
                    z_at_tmin = point1(3) + t_min * (point2(3) - point1(3));
                    z_at_tmax = point1(3) + t_max * (point2(3) - point1(3));
                    min_z_in_obstacle = min(z_at_tmin, z_at_tmax);
                    
                    % 如果最低高度低于障碍物高度，则被阻挡
                    if min_z_in_obstacle < height
                        hasLOS = false;
                        return;
                    end
                end
            end
        end
        
        %% 检查线段是否与矩形相交（快速版本）
        function intersects = segmentIntersectsRectangleFast(obj, p1, p2, rect_min, rect_max)
            % 检查线段是否与矩形相交（2D）- 快速版本
            % p1, p2: 1x2向量，线段端点
            % rect_min, rect_max: 1x2向量，矩形左下角和右上角
            
            % 如果线段端点有一个在矩形内，则相交
            if (p1(1) >= rect_min(1) && p1(1) <= rect_max(1) && ...
                p1(2) >= rect_min(2) && p1(2) <= rect_max(2)) || ...
               (p2(1) >= rect_min(1) && p2(1) <= rect_max(1) && ...
                p2(2) >= rect_min(2) && p2(2) <= rect_max(2))
                intersects = true;
                return;
            end
            
            % 使用分离轴定理（SAT）的简化版本
            % 检查线段是否与矩形的任意边相交
            % 左边界：x = rect_min(1)
            if obj.segmentIntersectsVerticalLine(p1, p2, rect_min(1), rect_min(2), rect_max(2))
                intersects = true;
                return;
            end
            % 右边界：x = rect_max(1)
            if obj.segmentIntersectsVerticalLine(p1, p2, rect_max(1), rect_min(2), rect_max(2))
                intersects = true;
                return;
            end
            % 下边界：y = rect_min(2)
            if obj.segmentIntersectsHorizontalLine(p1, p2, rect_min(2), rect_min(1), rect_max(1))
                intersects = true;
                return;
            end
            % 上边界：y = rect_max(2)
            if obj.segmentIntersectsHorizontalLine(p1, p2, rect_max(2), rect_min(1), rect_max(1))
                intersects = true;
                return;
            end
            
            intersects = false;
        end
        
        %% 检查线段是否与垂直线段相交
        function intersects = segmentIntersectsVerticalLine(obj, p1, p2, x, y_min, y_max)
            % 检查线段p1-p2是否与垂直线段(x, y_min)到(x, y_max)相交
            if abs(p2(1) - p1(1)) < 1e-10
                % 线段是垂直的
                if abs(p1(1) - x) < 1e-10
                    % 线段在垂直线上
                    seg_y_min = min(p1(2), p2(2));
                    seg_y_max = max(p1(2), p2(2));
                    intersects = ~(seg_y_max < y_min || seg_y_min > y_max);
                else
                    intersects = false;
                end
            else
                % 计算交点
                t = (x - p1(1)) / (p2(1) - p1(1));
                if t >= 0 && t <= 1
                    y_intersect = p1(2) + t * (p2(2) - p1(2));
                    intersects = (y_intersect >= y_min && y_intersect <= y_max);
                else
                    intersects = false;
                end
            end
        end
        
        %% 检查线段是否与水平线段相交
        function intersects = segmentIntersectsHorizontalLine(obj, p1, p2, y, x_min, x_max)
            % 检查线段p1-p2是否与水平线段(x_min, y)到(x_max, y)相交
            if abs(p2(2) - p1(2)) < 1e-10
                % 线段是水平的
                if abs(p1(2) - y) < 1e-10
                    % 线段在水平线上
                    seg_x_min = min(p1(1), p2(1));
                    seg_x_max = max(p1(1), p2(1));
                    intersects = ~(seg_x_max < x_min || seg_x_min > x_max);
                else
                    intersects = false;
                end
            else
                % 计算交点
                t = (y - p1(2)) / (p2(2) - p1(2));
                if t >= 0 && t <= 1
                    x_intersect = p1(1) + t * (p2(1) - p1(1));
                    intersects = (x_intersect >= x_min && x_intersect <= x_max);
                else
                    intersects = false;
                end
            end
        end
        
        %% 检查两条线段是否相交
        function intersects = segmentIntersectsLine(obj, p1, p2, q1, q2)
            % 检查线段p1-p2是否与线段q1-q2相交
            % 使用叉积方法
            
            % 计算方向向量
            d1 = p2 - p1;
            d2 = q2 - q1;
            
            % 计算叉积
            cross1 = (q1(1) - p1(1)) * d1(2) - (q1(2) - p1(2)) * d1(1);
            cross2 = (q2(1) - p1(1)) * d1(2) - (q2(2) - p1(2)) * d1(1);
            
            % 如果两个叉积符号相同，则不相交
            if cross1 * cross2 > 0
                intersects = false;
                return;
            end
            
            % 检查另一条线段
            cross3 = (p1(1) - q1(1)) * d2(2) - (p1(2) - q1(2)) * d2(1);
            cross4 = (p2(1) - q1(1)) * d2(2) - (p2(2) - q1(2)) * d2(1);
            
            if cross3 * cross4 > 0
                intersects = false;
                return;
            end
            
            intersects = true;
        end
    end
end

