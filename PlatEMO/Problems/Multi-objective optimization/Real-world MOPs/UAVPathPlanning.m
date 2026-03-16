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
% 3. 最大化路径覆盖率（转换为最小化负的覆盖率）
%
% 参数说明：
% bsPerKm2 --- 100 --- 每平方公里基站数量
% velocity --- 10 --- 无人机最大速度（m/s）
% TTT --- 1 --- 时间间隔（s）
% switchThreshold --- -80 --- 切换阈值（dBm）
% obstacleMethod --- 0 --- 障碍物与预设路径生成方法（固定为0，基于αβγ的方法）
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
        obstacles;       % 障碍物信息（二维数组：gridX x gridY x 5，obstacles(x, y, :) = [x_min, y_min, x_max, y_max, height]）
        obstacleGridSize; % 障碍物网格大小 [gridX, gridY]
        velocity;        % 无人机最大速度（m/s）
        TTT;             % 时间间隔（s）
        numBS;           % 基站数量
        switchThreshold; % 切换阈值（dBm）
        obstacleMethod;  % 障碍物与预设路径生成方法（固定为0，基于αβγ的方法）
        alpha;           % 城市密度比（建筑总面积与土地总面积的比值，0.1~0.5）
        beta;            % 建筑密度（单位土地面积内的建筑物数量，300~750 栋/km²）
        gamma;           % 建筑高度的瑞利分布参数（8~50m）
        pathLength;      % 预设路径总长度
        numWaypoints;    % 航点数量（自动计算）
        presetWaypoints; % 预设航点位置（在预设路径上均匀分布，numWaypoints x 3）
        waypointSegmentMapping; % 航点到路径段的映射（numWaypoints x 1），每个值表示对应的路径段索引（1到numPresetPoints-1）
        xyBound; % XY平面边界约束（numPresetPoints-1 x 4），每行包含[kLower, cLower, kUpper, cUpper]，对应一个路径段
        % coverageRadius不再使用固定值：覆盖半径取每个航点当前高度z（r = waypoint(3)）
        % coverageRadius; 
    end
    
    methods
        %% 获取切换阈值（公共方法）
        function threshold = getSwitchThreshold(obj)
            threshold = obj.switchThreshold;
            
        end
        
        %% 获取航点到路径段的映射（公共方法）
        function segmentMapping = getWaypointSegmentMapping(obj)
            %getWaypointSegmentMapping - 获取每个航点对应的路径段索引
            %
            %   输出：
            %       segmentMapping - numWaypoints x 1向量，每个值表示对应的路径段索引
            %                       路径段索引范围：1 到 numPresetPoints-1
            %                       段i表示从presetPath(i)到presetPath(i+1)的路径段
            
            % 确保映射关系已经初始化
            if isempty(obj.waypointSegmentMapping)
                obj.generateUniformWaypoints();
            end
            
            segmentMapping = obj.waypointSegmentMapping;
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
            % 参数格式：{bsPerKm2, velocity, TTT, switchThreshold, obstacleMethod}
            %   bsPerKm2: 每平方公里的基站数量
            %   velocity: 无人机最大速度（m/s）
            %   TTT: 时间间隔（s）
            %   switchThreshold: 切换阈值（dBm）
            %   obstacleMethod: 障碍物生成方法（固定为0，基于αβγ的方法，固定α=0.3, β=500, γ=40）
            % 注意：不再需要numWaypoints参数，航点数量将自动计算
            if isempty(obj.parameter)
                bsPerKm2 = 10;  % 默认每平方公里10个基站
                velocity = 10;
                TTT = 1;
                switchThreshold = -80;
                obstacleMethod = 0;  % 0 = 基于αβγ的新方法
            else
                params = obj.parameter;
                if iscell(params) && length(params) >= 4
                    bsPerKm2 = params{1};  % 每平方公里基站数量
                    velocity = params{2};
                    TTT = params{3};
                    switchThreshold = params{4};
                    if length(params) >= 5
                        obstacleMethod = params{5};
                        % 只支持method=0，其他值将被忽略并使用默认值0
                        if obstacleMethod ~= 0
                            warning('UAVPathPlanning:只支持obstacleMethod=0，已自动设置为0');
                            obstacleMethod = 0;
                        end
                    else
                        obstacleMethod = 0;
                    end
                else
                    bsPerKm2 = 10;  % 默认每平方公里10个基站
                    velocity = 10;
                    TTT = 1;
                    switchThreshold = -80;
                    obstacleMethod = 0;
                end
            end
            
            % 固定使用α=0.3, β=500, γ=40
            alpha = 0.3265;  % 城市密度比
            beta = 204.08;   % 建筑密度（栋/km²）
            gamma = 40;   % 瑞利分布参数（m）
            
            obj.velocity = velocity;
            obj.TTT = TTT;
            obj.switchThreshold = switchThreshold;
            obj.obstacleMethod = obstacleMethod;
            
            % 覆盖半径不再使用固定值：覆盖半径取每个航点当前高度z（r = waypoint(3)）
            % 因此这里不再设置obj.coverageRadius
            
            % 保存建筑物建模参数（用于生成和加载）
            obj.alpha = alpha;
            obj.beta = beta;
            obj.gamma = gamma;
            
            % 生成或加载预设路径、基站位置和障碍物
            % 文件名使用obstacleMethod和bsPerKm2标识，以便不同参数配置使用不同文件
            file = sprintf('UAVPathPlanning-%d-%d.mat', obstacleMethod, bsPerKm2);
            file = fullfile(fileparts(mfilename('fullpath')), file);
            
            if exist(file, 'file') == 2
                % 加载数据文件（尝试加载obstacleGridSize和xyBound，如果不存在也不会报错）
                try
                    load(file, 'presetPath', 'baseStations', 'obstacles', 'obstacleGridSize', 'xyBound');
                    if exist('obstacleGridSize', 'var') && ~isempty(obstacleGridSize)
                        obj.obstacleGridSize = obstacleGridSize;
                    end
                    if exist('xyBound', 'var') && ~isempty(xyBound)
                        obj.xyBound = xyBound;
                    end
                catch
                    % 如果某些变量不存在，尝试加载基本变量
                    try
                        load(file, 'presetPath', 'baseStations', 'obstacles', 'obstacleGridSize');
                        if exist('obstacleGridSize', 'var') && ~isempty(obstacleGridSize)
                            obj.obstacleGridSize = obstacleGridSize;
                        end
                    catch
                        load(file, 'presetPath', 'baseStations', 'obstacles');
                    end
                end
                
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
                    baseStations = obj.generateBaseStationsUniform(bsPerKm2, obstacles);
                    obstacleGridSize = obj.obstacleGridSize;
                    save(file, 'presetPath', 'baseStations', 'obstacles', 'obstacleGridSize', '-append');
                else
                    % 新格式：如果obstacleGridSize未加载，从obstacles维度推断
                    if isempty(obj.obstacleGridSize)
                        obj.obstacleGridSize = [size(obstacles, 1), size(obstacles, 2)];
                    end
                end
                
                % 如果xyBound未加载，根据当前的presetPath生成xyBound
                % 注意：这里不调用generatePresetPath，因为它会重新生成presetPath
                % 如果xyBound未定义，会在后续根据presetPath生成
                if isempty(obj.xyBound)
                    % 根据当前的presetPath生成xyBound（调用generatePresetPath但只使用xyBound部分）
                    % 先保存当前的presetPath
                    savedPresetPath = obj.presetPath;
                    % 调用generatePresetPath生成xyBound
                    obj.generatePresetPath(obstacleMethod);
                    % 恢复presetPath（因为generatePresetPath会重新生成它）
                    obj.presetPath = savedPresetPath;
                end
            else
                % 生成预设路径和障碍物（根据obstacleMethod）
                [presetPath, obstacles] = obj.generatePresetPathAndObstacles(obstacleMethod);
                
                % 在建筑物顶端生成基站位置（基于每平方公里基站数量）
                baseStations = obj.generateBaseStationsUniform(bsPerKm2, obstacles);
                
                % 保存数据（包括网格大小和xyBound）
                obstacleGridSize = obj.obstacleGridSize;
                xyBound = obj.xyBound;
                save(file, 'presetPath', 'baseStations', 'obstacles', 'obstacleGridSize', 'xyBound');
            end
            
            obj.obstacles = obstacles;
            
            obj.presetPath = presetPath;
            obj.baseStations = baseStations;
            
            % 如果xyBound未设置（从文件加载时可能不存在），根据当前的presetPath生成
            if isempty(obj.xyBound)
                % 先保存当前的presetPath
                savedPresetPath = obj.presetPath;
                % 调用generatePresetPath生成xyBound
                obj.generatePresetPath(obstacleMethod);
                % 恢复presetPath（因为generatePresetPath会重新生成它）
                obj.presetPath = savedPresetPath;
            end
            
            % 更新基站数量为实际生成的基站数量（等于建筑物数量）
            obj.numBS = size(baseStations, 1);
            
            % 计算预设路径总长度（3D距离）
            obj.pathLength = 0;
            for i = 1:size(obj.presetPath, 1)-1
                obj.pathLength = obj.pathLength + norm(obj.presetPath(i+1,:) - obj.presetPath(i,:));
            end
            
            % 根据预设路径总长度和无人机速度自动计算航点数量
            % 假设无人机以最大速度的0.8倍运动
            actualVelocity = obj.velocity * 0.5;
            distancePerWaypoint = actualVelocity * obj.TTT;  % 每个航点之间的距离
            obj.numWaypoints = max(2, ceil(obj.pathLength / distancePerWaypoint));  % 至少2个航点
            
            % 设置决策变量维度（N个航点，每个3维坐标：x, y, z）
            % 注意：D维度由航点数量自动计算，忽略用户传递的D参数
            obj.D = obj.numWaypoints * 3;
            
            % 在预设路径上按距离均匀分布生成预设航点
            % 同时生成waypointSegmentMapping（航点到路径段的映射）
            obj.presetWaypoints = obj.generateUniformWaypoints();
            
            % 注意：waypointSegmentMapping会在generateUniformWaypoints中自动生成
            % 即使从文件加载，也会根据presetPath重新生成，确保一致性
            
            % 设置决策变量的上下界
            % 如果用户传递了lower/upper且维度匹配，则使用用户的值；否则使用默认值
            if ~isempty(userLower) && isequal(size(userLower), [1, obj.D])
                obj.lower = userLower;
            else
                % 默认下界：x, y在0-300（根据预设路径范围），z在30-70米（高度范围，预设路径在40米左右）
                obj.lower = zeros(1, obj.D);
                % z坐标的下界设为30米（允许一定的高度变化范围）
                for i = 3:3:obj.D
                    obj.lower(i) = 30;
                end
            end
            
            if ~isempty(userUpper) && isequal(size(userUpper), [1, obj.D])
                obj.upper = userUpper;
            else
                % 默认上界：x, y在0-300（根据预设路径范围），z在30-70米（高度范围，预设路径在40米左右）
                obj.upper = 500 * ones(1, obj.D);
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
            
            % 计算扰动范围（初始种群使用更小的扰动，确保满足约束）
            % 扰动范围设为决策空间范围的1%，即约1米（比原来的5%小很多）
            perturbationRange = (obj.upper(1) - obj.lower(1)) * 0;
            
            % 计算最大允许距离（用于确保相邻航点距离约束）
            maxDistance = obj.velocity * obj.TTT;
            
            for i = 1:N
                % 以presetWaypoints为基础，添加小的随机扰动
                waypoints = obj.presetWaypoints + randn(size(obj.presetWaypoints)) * perturbationRange;
                
                % 限制在边界内（3D坐标：x, y, z）
                waypoints = max(waypoints, repmat(obj.lower(1:3), size(waypoints, 1), 1));
                waypoints = min(waypoints, repmat(obj.upper(1:3), size(waypoints, 1), 1));
                
                % 固定第一个和最后一个航点为预设路径的起点和终点
                waypoints(1, :) = obj.presetPath(1, :);  % 第一个航点 = 预设路径起点
                % waypoints(end, :) = obj.presetPath(end, :);  % 最后一个航点 = 预设路径终点（暂时注释）
                
                % 修复航点位置：将航点移出建筑物（中间航点，不包括首尾）
                for j = 2:size(waypoints, 1)-1
                    waypoints(j, :) = obj.repairWaypointOutsideObstacle(waypoints(j, :));
                end
                
                % 确保相邻航点距离不超过最大允许距离
                % 如果距离超过限制，将下一个航点调整到可到达的位置
                for j = 1:size(waypoints, 1)-1
                    currentWP = waypoints(j, :);
                    nextWP = waypoints(j+1, :);
                    distance = norm(nextWP - currentWP);
                    
                    if distance > maxDistance
                        % 将下一个航点调整到可到达的位置
                        direction = (nextWP - currentWP) / distance;
                        waypoints(j+1, :) = currentWP + direction * maxDistance;
                        
                        % 确保修复后的航点在边界内
                        waypoints(j+1, :) = max(waypoints(j+1, :), obj.lower(1:3));
                        waypoints(j+1, :) = min(waypoints(j+1, :), obj.upper(1:3));
                    end
                end
                
                % 再次确保首尾航点固定（可能在修复过程中被改变）
                waypoints(1, :) = obj.presetPath(1, :);
                % waypoints(end, :) = obj.presetPath(end, :);  % 暂时注释
                
                % 转换为决策变量格式（D = numWaypoints × 3）
                % 将 numWaypoints × 3 的矩阵转换为 1 × D 的向量
                PopDec(i,:) = reshape(waypoints', 1, []);
            end
            
            % 使用CalDec进一步修复，确保所有约束都满足
            PopDec = obj.CalDec(PopDec);
            
            % 创建SOLUTION对象
            Population = SOLUTION(PopDec);
        end
        
        %% 修复无效解（确保首尾航点固定，并将航点移出建筑物）
        function PopDec = CalDec(obj, PopDec)
            %CalDec - 修复无效解，确保首尾航点固定，并将航点移出建筑物
            %
            %   修复策略：
            %   1. 调用父类的CalDec方法，确保决策变量在边界内
            %   2. 固定第一个和最后一个航点为预设路径的起点和终点
            %   3. 将航点移出建筑物（如果航点在建筑物内）
            %
            %   输入：
            %       PopDec - 决策变量矩阵（N x D）
            %   输出：
            %       PopDec - 修复后的决策变量矩阵
            
            % 先调用父类的CalDec方法，确保决策变量在边界内
            PopDec = CalDec@PROBLEM(obj, PopDec);
            
            [N, D] = size(PopDec);
            numWaypoints = D / 3;
            
            % 固定第一个和最后一个航点为预设路径的起点和终点，并修复航点位置
            for i = 1:N
                % 提取航点坐标（3D：x, y, z）
                waypoints = reshape(PopDec(i,:), 3, numWaypoints)';  % numWaypoints x 3
                
                % 固定第一个和最后一个航点为预设路径的起点和终点
                waypoints(1, :) = obj.presetPath(1, :);  % 第一个航点 = 预设路径起点
                % waypoints(end, :) = obj.presetPath(end, :);  % 最后一个航点 = 预设路径终点（暂时注释）
                
                % 修复航点位置：将航点移出建筑物（中间航点，不包括首尾）
                for j = 2:numWaypoints-1
                    waypoints(j, :) = obj.repairWaypointOutsideObstacle(waypoints(j, :));
                end
                
                % 确保修复后的航点在边界内
                waypoints = max(waypoints, repmat(obj.lower(1:3), size(waypoints, 1), 1));
                waypoints = min(waypoints, repmat(obj.upper(1:3), size(waypoints, 1), 1));
                
                % 再次固定首尾航点（可能在边界检查后被改变）
                waypoints(1, :) = obj.presetPath(1, :);
                % waypoints(end, :) = obj.presetPath(end, :);  % 暂时注释
                
                % 将修复后的航点转换回决策变量格式
                PopDec(i,:) = reshape(waypoints', 1, []);
            end
        end
        
        %% 计算约束违反度
        function PopCon = CalCon(obj, PopDec)
            %CalCon - 计算约束违反度
            %
            %   约束0：每个航点指向下一个航点的向量x与起点到终点的向量a的点积不能为负数
            %          （即向量x与向量a所成的角度不大于90度）
            %   约束1：连续三个航点a, b, c之间的夹角约束
            %          （向量ab与向量bc之间的夹角不大于90度）
            %   约束2：航点不可在建筑物中
            %   约束3：两个航点间的连线不可穿过建筑物
            %   约束4：XY平面边界约束（xyBound）
            %         对每个路径段下的所有航点(x, y, z)，满足：
            %         - y > kLower*x + cLower 且 y < kUpper*x + cUpper
            %         - 特殊情况：若kLower或kUpper为realmax，则：
            %           * 当kLower为realmax时，满足x > cLower
            %           * 当kUpper为realmax时，满足x < cUpper
            %
            %   约束违反度 = max(0, violation)
            %   如果 violation <= 0，约束违反度为0（满足约束）
            %   如果 violation > 0，约束违反度 > 0（违反约束）
            %
            %   输入：
            %       PopDec - 决策变量矩阵（N x D）
            %   输出：
            %       PopCon - 约束违反度矩阵（N x numConstraints）
            %               每行是一个解的约束违反度，每列是一个约束
            
            [N, D] = size(PopDec);
            numWaypoints = D / 3;

            % 计算起点到终点的向量a（3D向量）
            startPoint = obj.presetPath(1, :);  % 起点
            endPoint = obj.presetPath(end, :);  % 终点
            vector_a = endPoint - startPoint;  % 起点到终点的向量
            
            % 计算最大允许距离（无人机最大速度 * TTT）
            maxDistance = obj.velocity * obj.TTT;
            
            % 约束数量：
            %   0. 航点方向约束（与起点到终点向量的角度约束）：numWaypoints - 1
            %   1. 连续三个航点之间的夹角约束：numWaypoints - 2（需要至少3个航点）
            %   2. 航点不在建筑物中：numWaypoints
            %   3. 连线不穿过建筑物：numWaypoints - 1
            %   4. XY平面边界约束（xyBound）：numWaypoints
            numConstraints = (numWaypoints - 1) + max(0, numWaypoints - 2) + numWaypoints + (numWaypoints - 1) + numWaypoints;
            PopCon = zeros(N, numConstraints);
            
            % 获取航点到路径段的映射（用于xyBound约束）
            segmentMapping = obj.getWaypointSegmentMapping();
            
            for i = 1:N
                % 提取航点坐标（3D：x, y, z）
                waypoints = reshape(PopDec(i,:), 3, numWaypoints)';  % numWaypoints x 3
                
                % 固定第一个和最后一个航点为预设路径的起点和终点
                waypoints(1, :) = obj.presetPath(1, :);  % 第一个航点 = 预设路径起点
                % waypoints(end, :) = obj.presetPath(end, :);  % 最后一个航点 = 预设路径终点（暂时注释）
                
                constraintIdx = 1;

                                
                % 约束0：检查每个航点指向下一个航点的向量x与向量a的点积
                % 要求：x · a >= 0（角度不大于90度）
                for j = 1:numWaypoints-1
                    currentWP = waypoints(j, :);
                    nextWP = waypoints(j+1, :);
                    
                    % 计算当前航点指向下一个航点的向量x（3D向量）
                    vector_x = nextWP - currentWP;
                    
                    % 计算点积：x · a
                    dot_product = dot(vector_x, vector_a);
                    
                    % 约束违反度 = max(0, -dot_product)
                    % 如果dot_product < 0（角度大于90度），则违反约束
                    PopCon(i, constraintIdx) = max(0, -dot_product);
                    constraintIdx = constraintIdx + 1;
                end
                
                % 约束1：检查连续三个航点a, b, c之间的夹角约束
                % 要求：向量ab与向量bc之间的夹角不大于90度
                % 即：ab · bc >= 0（点积非负表示夹角不大于90度）
                for j = 1:numWaypoints-2
                    a = waypoints(j, :);      % 航点a
                    b = waypoints(j+1, :);    % 航点b（a的下一个）
                    c = waypoints(j+2, :);    % 航点c（b的下一个）
                    
                    % 计算向量ab和bc
                    vector_ab = b - a;
                    vector_bc = c - b;
                    
                    % 计算点积：ab · bc
                    dot_product_ab_bc = dot(vector_ab, vector_bc);
                    
                    % 约束违反度 = max(0, -dot_product_ab_bc)
                    % 如果dot_product_ab_bc < 0（夹角大于90度），则违反约束
                    PopCon(i, constraintIdx) = max(0, -dot_product_ab_bc);
                    constraintIdx = constraintIdx + 1;
                end
                
                % 约束2：检查航点是否在建筑物中
                for j = 1:numWaypoints
                    waypoint = waypoints(j, :);
                    violation = obj.checkWaypointInObstacle(waypoint);
                    % 确保违反度非负（虽然checkWaypointInObstacle应该返回非负值，但为了保险起见）
                    PopCon(i, constraintIdx) = max(0, violation);
                    constraintIdx = constraintIdx + 1;
                end
                
                % 约束3：检查连线是否穿过建筑物
                for j = 1:numWaypoints-1
                    currentWP = waypoints(j, :);
                    nextWP = waypoints(j+1, :);
                    
                    violation = obj.checkSegmentIntersectsObstacle(currentWP, nextWP);
                    % 确保违反度非负（虽然checkSegmentIntersectsObstacle应该返回非负值，但为了保险起见）
                    PopCon(i, constraintIdx) = max(0, violation);
                    constraintIdx = constraintIdx + 1;
                end
                
                % 约束4：检查XY平面边界约束（xyBound）
                % 对每个航点，根据其所属的路径段，检查是否满足xyBound约束
                for j = 1:numWaypoints
                    waypoint = waypoints(j, :);
                    x = waypoint(1);
                    y = waypoint(2);
                    
                    % 获取航点对应的路径段索引
                    segmentIdx = segmentMapping(j);
                    
                    % 获取该路径段的xyBound约束
                    if ~isempty(obj.xyBound) && segmentIdx >= 1 && segmentIdx <= size(obj.xyBound, 1)
                        kLower = obj.xyBound(segmentIdx, 1);
                        cLower = obj.xyBound(segmentIdx, 2);
                        kUpper = obj.xyBound(segmentIdx, 3);
                        cUpper = obj.xyBound(segmentIdx, 4);
                        
                        violation = 0;
                        
                        % 检查下界约束：y > kLower*x + cLower
                        if kLower == realmax
                            % 特殊情况：kLower为realmax，检查x > cLower
                            if x <= cLower
                                violation = violation + (cLower - x);
                            end
                        else
                            % 一般情况：y > kLower*x + cLower
                            lowerBound = kLower * x + cLower;
                            if y <= lowerBound
                                violation = violation + (lowerBound - y);
                            end
                        end
                        
                        % 检查上界约束：y < kUpper*x + cUpper
                        if kUpper == realmax
                            % 特殊情况：kUpper为realmax，检查x < cUpper
                            if x >= cUpper
                                violation = violation + (x - cUpper);
                            end
                        else
                            % 一般情况：y < kUpper*x + cUpper
                            upperBound = kUpper * x + cUpper;
                            if y >= upperBound
                                violation = violation + (y - upperBound);
                            end
                        end
                        
                        PopCon(i, constraintIdx) = max(0, violation);
                    else
                        % 如果没有定义xyBound或索引超出范围，约束违反度为0
                        PopCon(i, constraintIdx) = 0;
                    end
                    constraintIdx = constraintIdx + 1;
                end
                
                % 验证：确保constraintIdx - 1 == numConstraints（调试用，可以注释掉）
                % if constraintIdx - 1 ~= numConstraints
                %     warning('UAVPathPlanning:CalCon', '约束数量不匹配！期望 %d，实际 %d', numConstraints, constraintIdx - 1);
                % end
            end
        end
        
        %% 计算目标函数值
        function PopObj = CalObj(obj, PopDec)
            [N, D] = size(PopDec);
            numWaypoints = D / 3;
            PopObj = zeros(N, obj.M);
            
            for i = 1:N
                % 提取航点坐标（3D：x, y, z）
                waypoints = reshape(PopDec(i,:), 3, numWaypoints)';  % numWaypoints x 3
                
                % 固定第一个和最后一个航点为预设路径的起点和终点
                waypoints(1, :) = obj.presetPath(1, :);  % 第一个航点 = 预设路径起点
                % waypoints(end, :) = obj.presetPath(end, :);  % 最后一个航点 = 预设路径终点（暂时注释）
                
                % 目标1：最大化平均信号强度（转换为最小化负的平均信号强度）
                avgSignal = obj.calculateAverageSignal(waypoints);
                PopObj(i, 1) = -avgSignal;  % 取负值，因为要最小化
                
                % 目标2：最小化切换次数
                switchCount = obj.calculateSwitchCount(waypoints);
                PopObj(i, 2) = switchCount;
                
                % 目标3：最大化路径覆盖率（转换为最小化负的覆盖率）
                coverageRatio = obj.calculatePathCoverageRatio(waypoints);
                PopObj(i, 3) = -coverageRatio;  % 取负值，因为要最小化
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
                    else
                        % 信号强度 >= 阈值，继续连接之前的基站
                        % 注意：如果信号强度足够，无人机应该继续连接之前的基站
                        % 但为了保持逻辑一致性，我们仍然更新previousBS为currentBS
                        % 因为如果信号强度足够，currentBS应该等于previousBS（信号最强的基站）
                        % 如果currentBS != previousBS，说明信号强度虽然>=阈值，但最强的基站已经改变
                        % 这种情况下，我们更新previousBS但不计数切换（因为信号强度足够，不需要切换）
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
        
        %% 计算圆柱体与预设路径段的相交长度
        function intersectionLength = calculateCylinderSegmentIntersection(obj, waypointXY, waypointRadius, segmentStartXY, segmentEndXY)
            %calculateCylinderSegmentIntersection - 计算圆柱体与路径段的相交长度
            %
            %   计算以航点为圆心（XY平面投影）的圆柱体与预设路径段（XY平面投影）的相交长度
            %   圆柱体垂直于地面，半径取该航点当前高度z（r = waypoint(3)）
            %
            %   输入：
            %       waypointXY - 航点的XY坐标（1 x 2）
            %       waypointRadius - 航点对应的覆盖半径（标量，单位：米），通常等于航点高度z
            %       segmentStartXY - 路径段起点的XY坐标（1 x 2）
            %       segmentEndXY - 路径段终点的XY坐标（1 x 2）
            %
            %   输出：
            %       intersectionLength - 相交部分的长度
            
            % 航点位置
            cx = waypointXY(1);
            cy = waypointXY(2);
            
            % 路径段端点
            x1 = segmentStartXY(1);
            y1 = segmentStartXY(2);
            x2 = segmentEndXY(1);
            y2 = segmentEndXY(2);
            
            % 圆半径（由航点高度决定）
            r = waypointRadius;
            
            % 线段向量
            dx = x2 - x1;
            dy = y2 - y1;
            segmentLength = sqrt(dx^2 + dy^2);
            
            % 如果线段长度为0，返回0
            if segmentLength < 1e-10
                intersectionLength = 0;
                return;
            end
            
            % 归一化方向向量
            ux = dx / segmentLength;
            uy = dy / segmentLength;
            
            % 从线段起点到圆心的向量
            fx = cx - x1;
            fy = cy - y1;
            
            % 计算圆心到线段的距离（投影）
            % t是圆心在线段方向上的投影参数（t=0在起点，t=segmentLength在终点）
            t = fx * ux + fy * uy;
            
            % 限制t在[0, segmentLength]范围内，找到线段上最接近圆心的点
            t = max(0, min(segmentLength, t));
            
            % 最接近点的坐标
            closestX = x1 + t * ux;
            closestY = y1 + t * uy;
            
            % 圆心到最接近点的距离
            distToSegment = sqrt((cx - closestX)^2 + (cy - closestY)^2);
            
            % 如果圆心到线段的距离大于半径，没有相交
            if distToSegment > r
                intersectionLength = 0;
                return;
            end
            
            % 使用圆与直线相交的数学公式
            % 将线段参数化为：P(s) = P1 + s*(P2-P1)，s∈[0,1]
            % 圆心到直线的距离：d = distToSegment
            % 相交弦长：2 * sqrt(r^2 - d^2)
            
            % 计算圆心到无限直线的距离
            % 使用点到直线的距离公式
            if abs(dx) < 1e-10 && abs(dy) < 1e-10
                % 线段退化为点
                intersectionLength = 0;
                return;
            end
            
            % 点到直线距离：|ax0 + by0 + c| / sqrt(a^2 + b^2)
            % 直线方程：dy*x - dx*y + (dx*y1 - dy*x1) = 0
            a = dy;
            b = -dx;
            c = dx*y1 - dy*x1;
            distToLine = abs(a*cx + b*cy + c) / sqrt(a^2 + b^2);
            
            % 如果圆心到直线的距离大于半径，没有相交
            if distToLine > r
                intersectionLength = 0;
                return;
            end
            
            % 计算相交弦的半长
            halfChordLength = sqrt(r^2 - distToLine^2);
            
            % 圆心在直线上的投影点参数（s∈[0,1]表示在线段上）
            % t是从起点沿线段方向的距离，转换为参数s
            s_center = t / segmentLength;
            
            % 相交区间的两个端点参数（在线段方向上）
            % 从圆心投影点向两侧延伸halfChordLength
            t1 = t - halfChordLength;
            t2 = t + halfChordLength;
            
            % 限制在线段范围内[0, segmentLength]
            t1 = max(0, t1);
            t2 = min(segmentLength, t2);
            
            % 计算相交长度
            intersectionLength = max(0, t2 - t1);
        end
        
        %% 计算路径覆盖率
        function coverageRatio = calculatePathCoverageRatio(obj, waypoints)
            %calculatePathCoverageRatio - 计算路径覆盖率
            %
            %   对每个航点，只计算在当前"所属"的预设路径段内的覆盖路径长度。
            %   不同航点若覆盖路径有重叠，不重复计算重叠的部分。
            %   路径覆盖率为总覆盖长度/路径总长度。
            %
            %   输入：
            %       waypoints - 航点坐标（numWaypoints x 3）
            %
            %   输出：
            %       coverageRatio - 路径覆盖率（0到1之间）
            
            numWaypoints = size(waypoints, 1);
            numPresetPoints = size(obj.presetPath, 1);
            numSegments = numPresetPoints - 1;
            
            % 获取航点到路径段的映射
            segmentMapping = obj.getWaypointSegmentMapping();
            
            % 对每个路径段，存储被覆盖的区间
            % segmentCoverage{i} 是一个 N x 2 的矩阵，每行是一个覆盖区间 [start, end]
            % start和end是从路径段起点开始的距离（0到segmentLength）
            segmentCoverage = cell(numSegments, 1);
            for i = 1:numSegments
                segmentCoverage{i} = [];
            end
            
            % 对每个航点，计算其在所属路径段内的覆盖区间
            for j = 1:numWaypoints
                waypoint = waypoints(j, :);
                waypointXY = waypoint(1:2);  % XY坐标
                
                % 获取航点对应的路径段索引
                segmentIdx = segmentMapping(j);
                
                % 获取路径段的起点和终点（XY坐标）
                segmentStartXY = obj.presetPath(segmentIdx, 1:2);
                segmentEndXY = obj.presetPath(segmentIdx+1, 1:2);
                
                % 计算路径段长度
                segmentLength = norm(segmentEndXY - segmentStartXY);
                
                if segmentLength < 1e-10
                    % 路径段长度为0，跳过
                    continue;
                end
                
                % 覆盖半径取航点当前高度z
                waypointRadius = waypoint(3) * sqrt(3) / 3;
                
                % 计算圆柱体与路径段的相交长度
                intersectionLength = obj.calculateCylinderSegmentIntersection(waypointXY, waypointRadius, segmentStartXY, segmentEndXY);
                
                if intersectionLength > 1e-10
                    % 计算相交区间在路径段上的位置
                    % 需要找到相交区间的起点和终点在路径段上的参数（0到segmentLength）
                    
                    % 圆心位置
                    cx = waypointXY(1);
                    cy = waypointXY(2);
                    
                    % 路径段起点和方向
                    x1 = segmentStartXY(1);
                    y1 = segmentStartXY(2);
                    dx = segmentEndXY(1) - x1;
                    dy = segmentEndXY(2) - y1;
                    
                    % 归一化方向向量
                    ux = dx / segmentLength;
                    uy = dy / segmentLength;
                    
                    % 从线段起点到圆心的向量
                    fx = cx - x1;
                    fy = cy - y1;
                    
                    % 圆心在线段上的投影参数
                    t_center = fx * ux + fy * uy;
                    
                    % 圆半径（由航点高度决定）
                    r = waypointRadius;
                    
                    % 圆心到直线的距离
                    a = dy;
                    b = -dx;
                    c = dx*y1 - dy*x1;
                    distToLine = abs(a*cx + b*cy + c) / sqrt(a^2 + b^2);
                    
                    if distToLine <= r
                        % 计算相交弦的半长
                        halfChordLength = sqrt(r^2 - distToLine^2);
                        
                        % 相交区间
                        t1 = max(0, t_center - halfChordLength);
                        t2 = min(segmentLength, t_center + halfChordLength);
                        
                        % 添加到该路径段的覆盖区间列表
                        if t2 > t1
                            segmentCoverage{segmentIdx} = [segmentCoverage{segmentIdx}; t1, t2];
                        end
                    end
                end
            end
            
            % 对每个路径段，合并重叠的覆盖区间，计算总覆盖长度
            totalCoveredLength = 0;
            
            for i = 1:numSegments
                intervals = segmentCoverage{i};
                
                if isempty(intervals)
                    continue;
                end
                
                % 合并重叠区间
                % 1. 按起点排序
                intervals = sortrows(intervals, 1);
                
                % 2. 合并重叠区间
                mergedIntervals = [];
                currentStart = intervals(1, 1);
                currentEnd = intervals(1, 2);
                
                for k = 2:size(intervals, 1)
                    if intervals(k, 1) <= currentEnd
                        % 重叠，扩展当前区间
                        currentEnd = max(currentEnd, intervals(k, 2));
                    else
                        % 不重叠，保存当前区间，开始新区间
                        mergedIntervals = [mergedIntervals; currentStart, currentEnd];
                        currentStart = intervals(k, 1);
                        currentEnd = intervals(k, 2);
                    end
                end
                % 保存最后一个区间
                mergedIntervals = [mergedIntervals; currentStart, currentEnd];
                
                % 计算该路径段的总覆盖长度
                segmentCoveredLength = sum(mergedIntervals(:, 2) - mergedIntervals(:, 1));
                totalCoveredLength = totalCoveredLength + segmentCoveredLength;
            end
            
            % 计算覆盖率
            if obj.pathLength > 0
                coverageRatio = totalCoveredLength / obj.pathLength;
            else
                coverageRatio = 0;
            end
            
            % 确保覆盖率在[0, 1]范围内
            coverageRatio = max(0, min(1, coverageRatio));
        end
        
        %% 在预设路径上按距离均匀分布生成航点
        function presetWaypoints = generateUniformWaypoints(obj)
            % 在预设路径上按距离均匀分布生成航点
            % 航点数量由 pathLength / (velocity * 0.8 * TTT) 决定
            % 同时保存每个航点对应的路径段索引到obj.waypointSegmentMapping
            
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
            % 初始化航点到路径段的映射（numWaypoints x 1）
            obj.waypointSegmentMapping = zeros(numWaypoints, 1);
            
            for j = 1:numWaypoints
                targetDist = targetDistances(j);
                
                % 找到目标距离所在的段
                segmentIdx = find(cumulativeLengths <= targetDist, 1, 'last');
                
                if segmentIdx >= numPresetPoints
                    % 如果超出范围，使用最后一个点
                    presetWaypoints(j,:) = obj.presetPath(end,:);
                    % 映射到最后一个段（numPresetPoints-1）
                    obj.waypointSegmentMapping(j) = numPresetPoints - 1;
                elseif segmentIdx == 0
                    % 如果小于0，使用第一个点
                    presetWaypoints(j,:) = obj.presetPath(1,:);
                    % 映射到第一个段（1）
                    obj.waypointSegmentMapping(j) = 1;
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
                    % 保存对应的路径段索引（segmentIdx对应段segmentIdx到segmentIdx+1）
                    obj.waypointSegmentMapping(j) = segmentIdx;
                end
            end
        end
        
        %% 生成用于超体积计算的参考点
        function R = GetOptimum(obj, N)
            % 返回参考点（用于超体积计算）
            % 
            % HV计算逻辑（在Metrics/HV.m中）：
            % 1. fmin = min(min(PopObj,[],1), zeros(1,M))  % 取实际最小值和0的较小者
            % 2. fmax = max(optimum,[],1)                   % 从optimum取最大值作为上界
            % 3. 归一化：(PopObj - fmin) / ((fmax - fmin) * 1.1)
            % 4. 删除任何归一化后>1的点：PopObj(any(PopObj>1,2),:) = []
            %
            % 关键问题：如果参考点设置得太小，归一化后所有点都可能>1，导致全部被删除，HV=0
            %
            % 参考点设置原则：
            % - 必须比所有可能的解都"差"（所有目标值都更大）
            % - 对于最小化问题，参考点应该是所有目标的上界
            % - 需要足够大，确保归一化后所有解都<=1
            %
            % 目标值范围估计：
            % - 目标1（-avgSignal）：信号强度通常在-100到-50 dBm，所以-avgSignal在50到100
            % - 目标2（switchCount）：切换次数在0到numWaypoints之间
            % - 目标3（-coverageRatio）：覆盖率在0到1之间，所以-coverageRatio在-1到0之间
            %
            % 使用保守的上界，确保覆盖所有可能的解
            
            numWaypoints = obj.numWaypoints;
            
            % 设置足够大的参考点（比所有可能的解都差）
            % 注意：参考点必须比所有实际解都差，否则归一化后解会被删除，导致HV=0
            %
            % 目标值范围估计（保守估计）：
            % - 目标1（-avgSignal）：最差情况信号强度可能到-120 dBm，所以-avgSignal可能到120
            %   设置参考点为200，确保覆盖所有情况
            % - 目标2（switchCount）：最坏情况每个航点都切换，最多numWaypoints次
            %   设置参考点为numWaypoints*1.5，足够大
            % - 目标3（-coverageRatio）：最差情况覆盖率为0，所以-coverageRatio为0
            %   设置参考点为0.1（比0稍大一点），确保覆盖所有情况
            
            R = [105, 8, 0.1];
            
            % 注意：如果HV仍然为0，可能是以下原因：
            % 1. 参考点仍然太小，实际解比参考点还差
            % 2. 目标值的实际范围超出了预期
            % 建议：在算法运行后检查实际目标值范围，然后调整参考点
        end
        
        %% 生成预设路径和障碍物
        function [presetPath, obstacles] = generatePresetPathAndObstacles(obj, method)
            % 生成预设路径和障碍物
            % method: 固定为0（基于αβγ的方法）
            
            % 生成障碍物
            obstacles = obj.generateObstacles(method);
            
            % 生成预设路径
            presetPath = obj.generatePresetPath(method);
        end
        
        %% 生成预设路径
        function presetPath = generatePresetPath(obj, method)
            % 生成预设路径（固定路径）
            
            if method == 0  % 0 = 固定预设路径
                % 固定的预设路径点（按顺序）
                presetPath = [
                    280,  280,  40;   % 起点
                    140,  280,  40;
                    140,  100,  40
                ];
                
                % XY平面边界约束（xyBound）
                % 每行对应一个路径段，格式：[kLower, cLower, kUpper, cUpper]
                % 对路径段下的所有航点(x, y, z)，满足：
                %   - y > kLower*x + cLower 且 y < kUpper*x + cUpper
                %   - 特殊情况：若kLower或kUpper为realmax，则：
                %     * 当kLower为realmax时，满足x > cLower
                %     * 当kUpper为realmax时，满足x < cUpper
                % 示例：对于路径段[40,40,40]到[80,40,40]，约束y>33且y<50
                obj.xyBound = [
                    0, 265, 0, 295;  % 路径段1：[40,40,40]到[80,40,40]
                    realmax, 125, realmax, 155   % 路径段2：[123,40,40]到[123,150,40]
                ];
                
                % presetPath = [
                %     40,   40,  40;   % 起点
                %     168,  40,  40;   % 转折点1
                %     168,  125, 40;   % 转折点2
                %     83,   125, 40;   % 转折点3
                %     83,   208, 40;   % 转折点4
                %     250,  208, 40    % 终点
                % ];
                % 对应的xyBound示例：
                % obj.xyBound = [
                %     0, 33, 0, 50;              % 路径段1：[40,40,40]到[168,40,40]
                %     realmax, 74, realmax, 91   % 路径段2：[168,40,40]到[168,125,40]
                % ];
            else
                error('未知的预设路径生成方法: %d', method);
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
            % 生成障碍物（基于αβγ的方法）
            % obstacles: gridX x gridY x 5 三维数组
            % obstacles(x, y, :) = [x_min, y_min, x_max, y_max, height]
            % x相同的建筑物在同一行，y相同的建筑物在同一列
            
            if method == 0
                % 新方法：基于城市密度比α、建筑密度β和瑞利分布参数γ
                % 使用obj.alpha, obj.beta, obj.gamma参数
                
                % 获取地图边界（默认0-1000米）
                map_x_min = 0;
                map_x_max = 500;
                map_y_min = 0;
                map_y_max = 500;
                
                % 计算地图面积（平方公里）
                map_width = map_x_max - map_x_min;   % 米
                map_height = map_y_max - map_y_min;   % 米
                map_area_m2 = map_width * map_height;  % 平方米
                map_area_km2 = map_area_m2 / 1e6;     % 平方公里
                
                % 计算建筑物几何特征
                % 建筑物宽度：W = 1000 * (α / β)^0.5
                W = 1000 * sqrt(obj.alpha / obj.beta);  % 米
                
                % 街道间距：S = 1000 / β^0.5 - W
                S = 1000 / sqrt(obj.beta) - W;  % 米
                
                % 总建筑数量：N = β * Area
                N = round(obj.beta * map_area_km2);  % 栋
                
                % 计算网格大小（建筑物间距 = W + S）
                buildingSpacing = W + S;  % 米
                
                % 计算网格尺寸（确保覆盖整个地图）
                gridX = ceil(map_width / buildingSpacing);
                gridY = ceil(map_height / buildingSpacing);
                
                % 初始化障碍物数组
                obstacles = zeros(gridX, gridY, 5);
                
                % 生成建筑物
                buildingCount = 0;
                for x = 1:gridX
                    for y = 1:gridY
                        % 计算建筑物中心位置
                        center_x = map_x_min + (x - 0.5) * buildingSpacing;
                        center_y = map_y_min + (y - 0.5) * buildingSpacing;
                        
                        % 检查是否在地图范围内
                        if center_x >= map_x_min && center_x <= map_x_max && ...
                           center_y >= map_y_min && center_y <= map_y_max
                            
                            % 计算建筑物边界（正方形，边长为W）
                            x_min = center_x - W / 2;
                            y_min = center_y - W / 2;
                            x_max = center_x + W / 2;
                            y_max = center_y + W / 2;
                            
                            % 确保建筑物在地图范围内
                            x_min = max(x_min, map_x_min);
                            y_min = max(y_min, map_y_min);
                            x_max = min(x_max, map_x_max);
                            y_max = min(y_max, map_y_max);
                            
                            % 建筑高度：h ~ Rayleigh(γ)
                            % 瑞利分布：h = gamma * sqrt(-2 * log(1 - U))，其中U是[0,1)的均匀随机数
                            U = rand();
                            height = obj.gamma * sqrt(-2 * log(1 - U));
                            
                            % 确保高度为正且合理（至少1米，最多200米）
                            height = max(1, min(200, height));
                            
                            obstacles(x, y, :) = [x_min, y_min, x_max, y_max, height];
                            buildingCount = buildingCount + 1;
                            
                            % 如果已达到目标建筑数量，停止生成
                            if buildingCount >= N
                                break;
                            end
                        end
                    end
                    if buildingCount >= N
                        break;
                    end
                end
                
                % 如果生成的建筑物数量少于N，调整网格大小
                % NOTE(临时)：按需求暂不启用“buildingCount < N 时提高网格密度并重生成建筑物”的逻辑。
                % 这会导致最终实际生成的建筑数量可能小于 N（即实际建筑密度略低于 beta）。
                %
                % if buildingCount < N
                %     % 增加网格密度
                %     gridX = ceil(sqrt(N * map_width / map_height));
                %     gridY = ceil(sqrt(N * map_height / map_width));
                %     obstacles = zeros(gridX, gridY, 5);
                %     
                %     buildingCount = 0;
                %     for x = 1:gridX
                %         for y = 1:gridY
                %             center_x = map_x_min + (x - 0.5) * (map_width / gridX);
                %             center_y = map_y_min + (y - 0.5) * (map_height / gridY);
                %             
                %             if center_x >= map_x_min && center_x <= map_x_max && ...
                %                center_y >= map_y_min && center_y <= map_y_max
                %                 
                %                 x_min = center_x - W / 2;
                %                 y_min = center_y - W / 2;
                %                 x_max = center_x + W / 2;
                %                 y_max = center_y + W / 2;
                %                 
                %                 x_min = max(x_min, map_x_min);
                %                 y_min = max(y_min, map_y_min);
                %                 x_max = min(x_max, map_x_max);
                %                 y_max = min(y_max, map_y_max);
                %                 
                %                 U = rand();
                %                 height = obj.gamma * sqrt(-2 * log(1 - U));
                %                 height = max(1, min(200, height));
                %                 
                %                 obstacles(x, y, :) = [x_min, y_min, x_max, y_max, height];
                %                 buildingCount = buildingCount + 1;
                %                 
                %                 if buildingCount >= N
                %                     break;
                %                 end
                %             end
                %         end
                %         if buildingCount >= N
                %             break;
                %         end
                %     end
                % end
                
                % 保存网格大小
                obj.obstacleGridSize = [gridX, gridY];
                
                fprintf('建筑物生成完成：\n');
                fprintf('  参数：α=%.2f, β=%.0f 栋/km², γ=%.0f m\n', obj.alpha, obj.beta, obj.gamma);
                fprintf('  建筑物宽度 W=%.2f m，街道间距 S=%.2f m\n', W, S);
                fprintf('  地图面积=%.4f km²，目标建筑数量=%d 栋，实际生成=%d 栋\n', ...
                    map_area_km2, N, buildingCount);
                fprintf('  网格大小：%d x %d\n', gridX, gridY);
            else
                error('未知的障碍物生成方法: %d（只支持method=0）', method);
            end
        end
        
        %% 基于每平方公里基站数量的均匀部署算法
        function baseStations = generateBaseStationsUniform(obj, bsPerKm2, obstacles)
            %generateBaseStationsUniform - 基于每平方公里基站数量均匀部署基站
            %
            %   算法策略：
            %   1. 计算地图总面积（根据障碍物边界或默认边界）
            %   2. 根据每平方公里基站数量计算需要的建筑物数量（注意：每个建筑物部署2个基站）
            %   3. 使用K-means聚类确定基站的目标位置（确保均匀分布）
            %   4. 在每个目标位置附近选择最高的建筑物
            %   5. 在选中的建筑物顶部部署基站：每个建筑物部署2个基站
            %      - 基站1：建筑物左下角（x_min, y_min）
            %      - 基站2：建筑物右上角（x_max, y_max）
            %
            %   输入：
            %       bsPerKm2 - 每平方公里的基站数量
            %       obstacles - 障碍物信息（gridX x gridY x 5 三维数组）
            %
            %   输出：
            %       baseStations - 基站位置矩阵（numBS x 3，每行是[x, y, z]）
            
            [gridX, gridY, ~] = size(obstacles);
            
            % 步骤1：计算地图总面积
            % 从障碍物中获取地图边界
            x_min_map = inf;
            x_max_map = -inf;
            y_min_map = inf;
            y_max_map = -inf;
            
            for x = 1:gridX
                for y = 1:gridY
                    obs = obstacles(x, y, :);
                    obs = obs(:)';
                    if obs(5) > 0  % 只考虑有高度的建筑物
                        x_min_map = min(x_min_map, obs(1));
                        x_max_map = max(x_max_map, obs(3));
                        y_min_map = min(y_min_map, obs(2));
                        y_max_map = max(y_max_map, obs(4));
                    end
                end
            end
            
            % 如果无法从障碍物获取边界，使用默认边界（0-1000米）
            if isinf(x_min_map)
                x_min_map = 0;
                x_max_map = 1000;
                y_min_map = 0;
                y_max_map = 1000;
            end
            
            % 计算地图面积（平方米）
            map_width = x_max_map - x_min_map;   % 米
            map_height = y_max_map - y_min_map;   % 米
            map_area_m2 = map_width * map_height;  % 平方米
            map_area_km2 = map_area_m2 / 1e6;     % 平方公里
            
            % 步骤2：计算需要的建筑物数量
            % 注意：每个建筑物部署2个基站（对角位置），所以需要的建筑物数量 = 基站总数 / 2
            totalBS = max(1, round(bsPerKm2 * map_area_km2));
            numBS = max(1, ceil(totalBS / 2));  % 需要的建筑物数量（向上取整）
            
            % 步骤3：收集所有建筑物的信息（位置和高度）
            buildingList = [];
            for x = 1:gridX
                for y = 1:gridY
                    obs = obstacles(x, y, :);
                    obs = obs(:)';
                    if obs(5) > 0  % 只考虑有高度的建筑物
                        x_center = (obs(1) + obs(3)) / 2;
                        y_center = (obs(2) + obs(4)) / 2;
                        height = obs(5);
                        buildingList = [buildingList; x_center, y_center, height, x, y];
                    end
                end
            end
            
            if isempty(buildingList)
                % 如果没有建筑物，返回空矩阵
                baseStations = zeros(0, 3);
                obj.numBS = 0;
                return;
            end
            
            % 如果需要的基站数量大于等于建筑物数量，使用所有建筑物
            if numBS >= size(buildingList, 1)
                numBS = size(buildingList, 1);
                selectedBuildings = buildingList;
            else
                % 步骤4：使用K-means聚类确定基站的目标位置（确保均匀分布）
                % 在2D平面上进行K-means聚类（只使用x, y坐标）
                buildingPositions = buildingList(:, 1:2);
                
                % 尝试使用K-means聚类，如果失败则使用网格方法
                try
                    [~, clusterCenters] = kmeans(buildingPositions, numBS, 'Replicates', 10, 'MaxIter', 100);
                    useKMeans = true;
                catch
                    % 如果K-means不可用，使用网格方法作为备选
                    % 将地图划分为numBS个网格，在每个网格中选择最高的建筑物
                    gridSize = ceil(sqrt(numBS));
                    x_step = map_width / gridSize;
                    y_step = map_height / gridSize;
                    clusterCenters = zeros(numBS, 2);
                    idx = 1;
                    for gx = 1:gridSize
                        for gy = 1:gridSize
                            if idx <= numBS
                                clusterCenters(idx, :) = [x_min_map + (gx-0.5)*x_step, y_min_map + (gy-0.5)*y_step];
                                idx = idx + 1;
                            end
                        end
                    end
                    useKMeans = false;
                end
                
                % 步骤5：为每个聚类中心选择最近的最高建筑物
                selectedBuildings = zeros(numBS, 5);
                usedBuildings = false(size(buildingList, 1), 1);
                
                for i = 1:numBS
                    center = clusterCenters(i, :);
                    
                    % 计算所有未使用建筑物到聚类中心的距离
                    distances = inf(size(buildingList, 1), 1);
                    for j = 1:size(buildingList, 1)
                        if ~usedBuildings(j)
                            distances(j) = norm(buildingList(j, 1:2) - center);
                        end
                    end
                    
                    % 在距离聚类中心一定范围内的建筑物中，选择最高的
                    % 搜索半径设为平均建筑物间距的1.5倍
                    avgDistance = sqrt(map_area_m2 / size(buildingList, 1));
                    searchRadius = avgDistance * 1.5;
                    
                    candidates = find(distances <= searchRadius & ~usedBuildings);
                    
                    if isempty(candidates)
                        % 如果没有候选建筑物，选择最近的
                        [~, bestIdx] = min(distances);
                        candidates = bestIdx;
                    end
                    
                    % 在候选建筑物中选择最高的
                    [~, maxHeightIdx] = max(buildingList(candidates, 3));
                    bestIdx = candidates(maxHeightIdx);
                    
                    selectedBuildings(i, :) = buildingList(bestIdx, :);
                    usedBuildings(bestIdx) = true;
                end
            end
            
            % 步骤6：在选中的建筑物顶部部署基站
            % 每个建筑物部署2个基站：一个在(x_min, y_min)，另一个在(x_max, y_max)
            numSelectedBuildings = size(selectedBuildings, 1);
            baseStations = zeros(numSelectedBuildings * 2, 3);
            
            bsIdx = 1;
            for i = 1:numSelectedBuildings
                gridX_idx = selectedBuildings(i, 4);
                gridY_idx = selectedBuildings(i, 5);
                
                % 获取建筑物的详细信息
                obs = obstacles(gridX_idx, gridY_idx, :);
                obs = obs(:)';
                
                x_min = obs(1);
                y_min = obs(2);
                x_max = obs(3);
                y_max = obs(4);
                height = obs(5);
                
                % 基站1：建筑物左下角（x_min, y_min），高度为建筑物高度+5米
                baseStations(bsIdx, :) = [x_min, y_min, height + 5];
                bsIdx = bsIdx + 1;
                
                % 基站2：建筑物右上角（x_max, y_max），高度为建筑物高度+5米
                baseStations(bsIdx, :) = [x_max, y_max, height + 5];
                bsIdx = bsIdx + 1;
            end
            
            % 更新基站数量（每个建筑物2个基站）
            obj.numBS = size(baseStations, 1);
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
            
            % 使用二维数组结构进行快速查询
            gridX = obj.obstacleGridSize(1);
            gridY = obj.obstacleGridSize(2);
            
            % 根据线段bounding box确定需要检查的网格范围
            % 对于默认方法：x坐标范围是20*(x-0.5)到20*x
            % 计算哪些网格单元可能与线段相交
            x_start = max(1, floor((seg_x_min - 10) / 20) + 1);
            x_end = min(gridX, ceil(seg_x_max / 20));
            y_start = max(1, floor((seg_y_min - 10) / 20) + 1);
            y_end = min(gridY, ceil(seg_y_max / 20));
            
            % 只遍历可能相交的网格单元
            for x = x_start:x_end
                for y = y_start:y_end
                    obs = obj.obstacles(x, y, :);
                    obs = obs(:)';  % 转换为行向量
                    
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
        end
        
        %% 检查航点是否在建筑物中
        function violation = checkWaypointInObstacle(obj, waypoint)
            %checkWaypointInObstacle - 检查航点是否在建筑物中
            %
            %   输入：
            %       waypoint - 1x3向量 [x, y, z]
            %   输出：
            %       violation - 约束违反度
            %                  如果航点在建筑物外，violation = 0（满足约束）
            %                  如果航点在建筑物内，violation > 0（违反约束，值为到建筑物表面的最小距离）
            
            violation = 0;
            
            % 使用二维数组结构进行快速查询
            gridX = obj.obstacleGridSize(1);
            gridY = obj.obstacleGridSize(2);
            
            % 根据航点坐标确定需要检查的网格范围
            wp_x = waypoint(1);
            wp_y = waypoint(2);
            wp_z = waypoint(3);
            
            % 计算航点所在的网格单元
            x_idx = max(1, min(gridX, floor((wp_x - 10) / 20) + 1));
            y_idx = max(1, min(gridY, floor((wp_y - 10) / 20) + 1));
            
            % 检查航点所在的网格单元及其相邻单元（以防航点在边界附近）
            x_range = max(1, x_idx-1):min(gridX, x_idx+1);
            y_range = max(1, y_idx-1):min(gridY, y_idx+1);
            
            for x = x_range
                for y = y_range
                    obs = obj.obstacles(x, y, :);
                    obs = obs(:)';  % 转换为行向量
                    
                    x_min = obs(1);
                    y_min = obs(2);
                    x_max = obs(3);
                    y_max = obs(4);
                    height = obs(5);
                    
                    % 检查航点是否在建筑物的水平投影内
                    if wp_x >= x_min && wp_x <= x_max && ...
                       wp_y >= y_min && wp_y <= y_max
                        % 检查航点的高度是否在建筑物高度范围内
                        if wp_z >= 0 && wp_z <= height
                            % 航点在建筑物内，计算到建筑物表面的最小距离
                            % 到各个面的距离
                            dist_to_xmin = wp_x - x_min;
                            dist_to_xmax = x_max - wp_x;
                            dist_to_ymin = wp_y - y_min;
                            dist_to_ymax = y_max - wp_y;
                            dist_to_bottom = wp_z;
                            dist_to_top = height - wp_z;
                            
                            % 最小距离（到最近表面的距离）
                            minDistToSurface = min([dist_to_xmin, dist_to_xmax, ...
                                                   dist_to_ymin, dist_to_ymax, ...
                                                   dist_to_bottom, dist_to_top]);
                            
                            % 约束违反度 = 到表面的距离（越小表示越深入建筑物）
                            % 使用一个小的惩罚值，确保违反度 > 0
                            violation = max(violation, 1.0 - minDistToSurface);
                        end
                    end
                end
            end
        end
        
        %% 修复航点位置，将其移出建筑物
        function repairedWaypoint = repairWaypointOutsideObstacle(obj, waypoint)
            %repairWaypointOutsideObstacle - 修复航点位置，将其移出建筑物
            %
            %   修复策略：
            %   1. 检查航点是否在建筑物内
            %   2. 如果在建筑物内，计算到各个面的距离
            %   3. 选择距离最近的表面，将航点移动到该表面外（加上小的偏移量）
            %   4. 优先向上移动（因为无人机通常在空中飞行）
            %
            %   输入：
            %       waypoint - 1x3向量 [x, y, z]
            %   输出：
            %       repairedWaypoint - 修复后的航点坐标（1x3向量）
            
            repairedWaypoint = waypoint;
            
            % 使用二维数组结构进行快速查询
            gridX = obj.obstacleGridSize(1);
            gridY = obj.obstacleGridSize(2);
            
            % 根据航点坐标确定需要检查的网格范围
            wp_x = waypoint(1);
            wp_y = waypoint(2);
            wp_z = waypoint(3);
            
            % 计算航点所在的网格单元
            x_idx = max(1, min(gridX, floor((wp_x - 10) / 20) + 1));
            y_idx = max(1, min(gridY, floor((wp_y - 10) / 20) + 1));
            
            % 检查航点所在的网格单元及其相邻单元（以防航点在边界附近）
            x_range = max(1, x_idx-1):min(gridX, x_idx+1);
            y_range = max(1, y_idx-1):min(gridY, y_idx+1);
            
            % 找到包含航点的建筑物
            containingObstacle = [];
            for x = x_range
                for y = y_range
                    obs = obj.obstacles(x, y, :);
                    obs = obs(:)';  % 转换为行向量
                    
                    x_min = obs(1);
                    y_min = obs(2);
                    x_max = obs(3);
                    y_max = obs(4);
                    height = obs(5);
                    
                    % 检查航点是否在建筑物的水平投影内
                    if wp_x >= x_min && wp_x <= x_max && ...
                       wp_y >= y_min && wp_y <= y_max
                        % 检查航点的高度是否在建筑物高度范围内
                        if wp_z >= 0 && wp_z <= height
                            % 航点在建筑物内，记录这个建筑物
                            containingObstacle = obs;
                            break;
                        end
                    end
                end
                if ~isempty(containingObstacle)
                    break;
                end
            end
            
            % 如果航点在建筑物内，需要修复
            if ~isempty(containingObstacle)
                x_min = containingObstacle(1);
                y_min = containingObstacle(2);
                x_max = containingObstacle(3);
                y_max = containingObstacle(4);
                height = containingObstacle(5);
                
                % 计算到各个面的距离
                dist_to_xmin = wp_x - x_min;
                dist_to_xmax = x_max - wp_x;
                dist_to_ymin = wp_y - y_min;
                dist_to_ymax = y_max - wp_y;
                dist_to_bottom = wp_z;
                dist_to_top = height - wp_z;
                
                % 找到最近的表面（优先考虑向上移动）
                distances = [dist_to_xmin, dist_to_xmax, dist_to_ymin, dist_to_ymax, dist_to_bottom, dist_to_top];
                
                % 优先向上移动（索引6对应top）
                % 策略：优先向上移动，因为无人机通常在空中飞行
                if dist_to_top == min(distances) || dist_to_top <= min([dist_to_xmin, dist_to_xmax, dist_to_ymin, dist_to_ymax, dist_to_bottom])
                    % 向上移动到建筑物顶部上方（加上1米安全距离）
                    repairedWaypoint(3) = height + 1;
                elseif dist_to_xmin == min(distances)
                    % 向左移动（加上1米安全距离）
                    repairedWaypoint(1) = x_min - 1;
                elseif dist_to_xmax == min(distances)
                    % 向右移动（加上1米安全距离）
                    repairedWaypoint(1) = x_max + 1;
                elseif dist_to_ymin == min(distances)
                    % 向前移动（加上1米安全距离）
                    repairedWaypoint(2) = y_min - 1;
                elseif dist_to_ymax == min(distances)
                    % 向后移动（加上1米安全距离）
                    repairedWaypoint(2) = y_max + 1;
                else
                    % 默认向上移动
                    repairedWaypoint(3) = height + 5;
                end
            end
        end
        
        %% 检查连线是否穿过建筑物
        function violation = checkSegmentIntersectsObstacle(obj, point1, point2)
            %checkSegmentIntersectsObstacle - 检查连线是否穿过建筑物
            %
            %   输入：
            %       point1, point2 - 1x3向量 [x, y, z]
            %   输出：
            %       violation - 约束违反度
            %                  如果连线不穿过建筑物，violation = 0（满足约束）
            %                  如果连线穿过建筑物，violation > 0（违反约束）
            
            violation = 0;
            
            % 先筛选出与线段相交的障碍物
            relevantObstacles = obj.getObstaclesBetweenPoints(point1, point2);
            
            % 如果没有相关障碍物，直接返回0（满足约束）
            if isempty(relevantObstacles)
                return;
            end
            
            % 检查线段是否与任何障碍物相交
            for i = 1:size(relevantObstacles, 1)
                obs = relevantObstacles(i, :);
                x_min = obs(1);
                y_min = obs(2);
                x_max = obs(3);
                y_max = obs(4);
                height = obs(5);
                
                % 检查线段是否与障碍物的水平投影相交
                if obj.segmentIntersectsRectangleFast(point1(1:2), point2(1:2), ...
                                                      [x_min, y_min], [x_max, y_max])
                    % 如果水平投影相交，检查高度是否被阻挡
                    % 使用与checkLineOfSight相同的逻辑
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
                        t_min = max(0, min(t_in_rect));
                        t_max = min(1, max(t_in_rect));
                        
                        z_at_tmin = point1(3) + t_min * (point2(3) - point1(3));
                        z_at_tmax = point1(3) + t_max * (point2(3) - point1(3));
                        min_z_in_obstacle = min(z_at_tmin, z_at_tmax);
                        
                        % 如果最低高度低于障碍物高度，则穿过建筑物
                        if min_z_in_obstacle < height
                            % 计算违反度：线段在建筑物内的最大深度
                            penetration_depth = height - min_z_in_obstacle;
                            violation = max(violation, penetration_depth);
                        end
                    end
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

