% example_DCMOCPSO.m
% 示例：使用DCMOCPSO算法求解UAVPathPlanning问题并可视化结果
%
% 这个示例展示如何：
% 1. 使用DCMOCPSO算法运行优化（分治策略）
% 2. 从结果中提取实际路径（航点坐标）
% 3. 对比不同目标的最优解
% 4. 可视化路径、基站和障碍物

clear; clc; close all;

%% 运行DCMOCPSO优化算法
fprintf('=== 运行DCMOCPSO优化算法 ===\n');

% 创建DCMOCPSO算法实例
% 参数格式：{numSegments, segmentOverlap, lambda, c_guide, useDynamicGrouping, useDynamicMutation}
%   numSegments: 将问题分成多少段（子问题数量），默认5
%   segmentOverlap: 相邻段之间的重叠航点数，默认1
%   lambda: E_k影响权重（MOCPSO_Ek参数，0~1），默认0.5
%   c_guide: 引导粒子权重（MOCPSO_Ek参数），默认0.3
%   useDynamicGrouping: 是否使用动态分组比例（MOCPSO_Ek参数），默认false
%     - false: 使用原始1:1:1均匀分组 + swapWL竞争
%     - true:  使用动态分组比例:
%              0-25%迭代:  2:1:1 (强化多样性)
%              25-75%迭代: 1:1:1 (均衡)
%              75-100%迭代: 1:1:2 (强化收敛)
%   useDynamicMutation: 是否使用动态变异率（MOCPSO_Ek参数），默认false
%     - false: 使用固定变异率 1/D
%     - true:  使用动态变异率:
%              0-20%迭代:   2.0x (强化探索)
%              20-40%迭代:  1.5x
%              40-60%迭代:  1.0x (标准)
%              60-80%迭代:  0.75x
%              80-100%迭代: 0.5x (强化收敛)
Algorithm = DCMOCPSO('parameter', {2, 1, 0.5, 0.3, true, true});

% 创建UAVPathPlanning问题
% 参数格式：{bsPerKm2, velocity, TTT, switchThreshold, obstacleMethod}
%   bsPerKm2: 每平方公里的基站数量
%   velocity: 无人机最大速度（m/s）
%   TTT: 时间间隔（s）
%   switchThreshold: 切换阈值（dBm）
%   obstacleMethod: 障碍物生成方法（0=default）
Problem = UAVPathPlanning('N', 50, 'maxFE', 3000, 'parameter', {96, 10, 4, -85, 0});

fprintf('问题设置：\n');
fprintf('  航点数量: %d\n', Problem.D / 3);
fprintf('  种群大小: %d\n', Problem.N);
fprintf('  最大函数评估次数: %d\n', Problem.maxFE);
fprintf('\n');

% 运行优化
Algorithm.Solve(Problem);

% 打印算法参数（从Algorithm对象中读取）
fprintf('算法参数：\n');
fprintf('  分治参数: %d段，每段重叠%d个航点\n', Algorithm.numSegments, Algorithm.segmentOverlap);
fprintf('  MOCPSO_Ek参数: lambda=%.2f, c_guide=%.2f\n', Algorithm.lambda, Algorithm.c_guide);
if Algorithm.useDynamicGrouping
    fprintf('  动态分组: 已启用 (0-25%%:2:1:1, 25-75%%:1:1:1, 75-100%%:1:1:2)\n');
else
    fprintf('  动态分组: 未启用 (使用原始1:1:1均匀分组)\n');
end
if Algorithm.useDynamicMutation
    fprintf('  动态变异率: 已启用 (0-20%%:2x, 20-40%%:1.5x, 40-60%%:1x, 60-80%%:0.75x, 80-100%%:0.5x)\n');
else
    fprintf('  动态变异率: 未启用 (使用固定变异率1/D)\n');
end
fprintf('\n');

% 获取最终种群
if ~isempty(Algorithm.result)
    finalPopulation = Algorithm.result{end, 2};
    fprintf('最终种群大小: %d\n', length(finalPopulation));
else
    error('算法未返回结果');
end
fprintf('\n');

%% 提取最优解并可视化
fprintf('\n=== 提取最优解并可视化 ===\n');

if length(finalPopulation) >= 1
    % 提取所有解的目标值
    PopObj = finalPopulation.objs;  % N×M矩阵，每行是一个解的目标值
    % 目标1：负平均信号强度（越小越好，即平均信号强度越大越好）
    % 目标2：切换次数（越小越好）
    % 目标3：负覆盖率（越小越好，即覆盖率越大越好）
    
    numObjectives = size(PopObj, 2);
    fprintf('目标数量: %d\n', numObjectives);
    
    % 找到每个目标的最优解
    [~, idx_obj1] = min(PopObj(:,1));  % 目标1最优
    [~, idx_obj2] = min(PopObj(:,2));  % 目标2最优
    
    if numObjectives >= 3
        [~, idx_obj3] = min(PopObj(:,3));  % 目标3最优（覆盖率最大）
    end
    
    fprintf('目标1最优解索引: %d (负平均信号强度=%.4f)\n', idx_obj1, PopObj(idx_obj1,1));
    fprintf('目标2最优解索引: %d (切换次数=%.4f)\n', idx_obj2, PopObj(idx_obj2,2));
    if numObjectives >= 3
        fprintf('目标3最优解索引: %d (负覆盖率=%.4f, 覆盖率=%.2f%%)\n', idx_obj3, PopObj(idx_obj3,3), -PopObj(idx_obj3,3)*100);
    end
    
    % 如果只有一个解，使用同一个解
    if length(finalPopulation) == 1
        idx_obj2 = idx_obj1;
        if numObjectives >= 3
            idx_obj3 = idx_obj1;
        end
        fprintf('注意：只有一个解，所有目标使用同一个解\n');
    end
    
    % 提取各目标最优解的路径（3D坐标：x, y, z）
    actualPath_obj1 = reshape(finalPopulation(idx_obj1).decs, 3, [])';
    actualPath_obj2 = reshape(finalPopulation(idx_obj2).decs, 3, [])';
    if numObjectives >= 3
        actualPath_obj3 = reshape(finalPopulation(idx_obj3).decs, 3, [])';
    end
    
    % 创建对比图（3D）
    if numObjectives >= 3
        figName = 'DCMOCPSO: 三个目标最优解的路径对比';
    else
        figName = 'DCMOCPSO: 两个目标最优解的路径对比';  % M<3兼容
    end
    figure('Name', figName, 'Position', [100, 100, 1400, 900]);
    
    % 加载预设路径、基站和障碍物
    % 文件名格式：UAVPathPlanning-%d-%d.mat（包含障碍物方法和每平方公里基站数量）
    obstacleMethod = 0;  % 与Problem创建时使用的障碍物方法一致
    bsPerKm2 = 96;    % 与Problem创建时使用的每平方公里基站数量一致
    file = sprintf('UAVPathPlanning-%d-%d.mat', obstacleMethod, bsPerKm2);
    file = fullfile(fileparts(which('UAVPathPlanning')), file);
    
    if exist(file, 'file') == 2
        % 加载数据文件（包括obstacleGridSize）
        try
            load(file, 'presetPath', 'baseStations', 'obstacles', 'obstacleGridSize');
        catch
            load(file, 'presetPath', 'baseStations', 'obstacles');
            obstacleGridSize = [];
        end
        fprintf('成功加载数据文件：%s\n', file);
        if exist('obstacles', 'var') && ~isempty(obstacles)
            % 检查障碍物格式：应该是三维数组 gridX x gridY x 5
            if ndims(obstacles) == 3
                [gridX, gridY, ~] = size(obstacles);
                if isempty(obstacleGridSize)
                    obstacleGridSize = [gridX, gridY];
                end
                numObstacles = gridX * gridY;
                fprintf('障碍物网格大小：%d x %d，障碍物数量：%d\n', gridX, gridY, numObstacles);
            else
                error('障碍物格式错误：应该是三维数组 gridX x gridY x 5');
            end
        else
            fprintf('警告：文件中没有障碍物数据\n');
            obstacles = [];
            obstacleGridSize = [];
        end
    else
        error('找不到数据文件：%s', file);
    end
    
    % 检查数据维度，如果是2D则转换为3D
    % 预设路径的z坐标设为40米（与预设路径高度一致）
    if size(presetPath, 2) == 2
        presetPath = [presetPath, 40*ones(size(presetPath, 1), 1)];
    end
    % 基站的z坐标应该已经在建筑物顶端（如果是从新格式加载）
    if size(baseStations, 2) == 2
        % 旧格式：基站在地面，z坐标设为0
        baseStations = [baseStations, zeros(size(baseStations, 1), 1)];
        warning('基站位置来自旧格式文件，可能不准确（应该在建筑物顶端）');
    end
    
    % 开始绘图
    hold on;
    
    % 绘制障碍物（建筑物）- 先绘制建筑物，这样其他元素会显示在上面
    obstacleDrawn = false;
    maxBuildingHeight = 0;  % 记录最高建筑物高度
    if exist('obstacles', 'var') && ~isempty(obstacles) && ndims(obstacles) == 3
        [gridX, gridY, ~] = size(obstacles);
        numObstacles = gridX * gridY;
        fprintf('开始绘制 %d 个建筑物障碍物（网格：%d x %d）...\n', numObstacles, gridX, gridY);
        obsCount = 0;
        for x = 1:gridX
            for y = 1:gridY
                obs = obstacles(x, y, :);
                obs = obs(:)';  % 转换为行向量
                x_min = obs(1);
                y_min = obs(2);
                x_max = obs(3);
                y_max = obs(4);
                height = obs(5);
                
                % 记录最高建筑物高度
                if height > maxBuildingHeight
                    maxBuildingHeight = height;
                end
                
                obsCount = obsCount + 1;
                % 调试信息：打印前几个建筑物的位置
                if obsCount <= 5
                    fprintf('  建筑物 (%d,%d): x=[%.1f, %.1f], y=[%.1f, %.1f], 高度=%.1f米\n', ...
                           x, y, x_min, x_max, y_min, y_max, height);
                end
            
            % 使用patch绘制3D长方体
            % 定义长方体的8个顶点
            vertices = [
                x_min, y_min, 0;      % 1: 左下前
                x_max, y_min, 0;      % 2: 右下前
                x_max, y_max, 0;      % 3: 右后下
                x_min, y_max, 0;      % 4: 左后下
                x_min, y_min, height; % 5: 左上前
                x_max, y_min, height; % 6: 右上前
                x_max, y_max, height; % 7: 右后上
                x_min, y_max, height  % 8: 左后上
            ];
            
            % 定义6个面的顶点索引（每个面4个顶点）
            faces = [
                1, 2, 3, 4;  % 底面
                5, 6, 7, 8;  % 顶面
                1, 2, 6, 5;  % 前面
                3, 4, 8, 7;  % 后面
                1, 4, 8, 5;  % 左面
                2, 3, 7, 6   % 右面
            ];
            
                % 绘制长方体（使用patch）
                if obsCount == 1
                    % 第一个建筑物添加到图例
                    patch('Faces', faces, 'Vertices', vertices, ...
                         'FaceColor', [0.7, 0.7, 0.7], 'FaceAlpha', 0.3, ...
                         'EdgeColor', 'k', 'LineWidth', 1, ...
                         'DisplayName', '建筑物障碍物');
                    obstacleDrawn = true;
                else
                    % 其他建筑物不添加到图例
                    patch('Faces', faces, 'Vertices', vertices, ...
                         'FaceColor', [0.7, 0.7, 0.7], 'FaceAlpha', 0.3, ...
                         'EdgeColor', 'k', 'LineWidth', 1, ...
                         'HandleVisibility', 'off');
                end
            end
        end
        fprintf('建筑物绘制完成，最高建筑物高度：%.1f米\n', maxBuildingHeight);
    end
    
    % 如果没有障碍物数据，添加提示
    if ~obstacleDrawn
        fprintf('警告：未找到障碍物数据，建筑物障碍物未显示\n');
    end
    
    % 绘制预设路径（3D）
    plot3(presetPath(:,1), presetPath(:,2), presetPath(:,3), 'b-o', ...
         'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b', ...
         'DisplayName', '预设路径');
    
    % 绘制基站（3D）- 现在基站应该在建筑物顶端
    % 打印基站位置信息（用于调试）
    fprintf('基站位置信息：\n');
    for bs_idx = 1:min(size(baseStations, 1), 5)  % 只打印前5个
        fprintf('  基站 %d: (%.2f, %.2f, %.2f)\n', bs_idx, ...
                baseStations(bs_idx, 1), baseStations(bs_idx, 2), baseStations(bs_idx, 3));
    end
    if size(baseStations, 1) > 5
        fprintf('  ... (共%d个基站)\n', size(baseStations, 1));
    end
    
    scatter3(baseStations(:,1), baseStations(:,2), baseStations(:,3), 200, 'r', '^', ...
            'filled', 'LineWidth', 2, 'DisplayName', '基站（建筑物顶端）');
    
    % 重新计算切换次数（以及覆盖率）以确保一致性
    fprintf('重新计算最优解的切换次数（以及覆盖率）...\n');
    switchCount_obj1 = Problem.calculateSwitchCount(actualPath_obj1);
    switchCount_obj2 = Problem.calculateSwitchCount(actualPath_obj2);
    if numObjectives >= 3
        switchCount_obj3 = Problem.calculateSwitchCount(actualPath_obj3);
    end
    
    fprintf('  目标1最优：切换次数=%.1f (原值=%.1f)\n', switchCount_obj1, PopObj(idx_obj1,2));
    fprintf('  目标2最优：切换次数=%.1f (原值=%.1f)\n', switchCount_obj2, PopObj(idx_obj2,2));
    if numObjectives >= 3
        coverageRatio_obj1 = Problem.calculatePathCoverageRatio(actualPath_obj1);
        coverageRatio_obj2 = Problem.calculatePathCoverageRatio(actualPath_obj2);
        coverageRatio_obj3 = Problem.calculatePathCoverageRatio(actualPath_obj3);
        fprintf('  目标3最优：切换次数=%.1f (原值=%.1f), 覆盖率=%.2f%% (原值=%.2f%%)\n', ...
            switchCount_obj3, PopObj(idx_obj3,2), coverageRatio_obj3*100, -PopObj(idx_obj3,3)*100);
    end
    
    % 绘制各目标的最优解（3D）
    % 目标1最优：信号强度最大（绿色）
    if numObjectives >= 3
        plot3(actualPath_obj1(:,1), actualPath_obj1(:,2), actualPath_obj1(:,3), 'g-s', ...
             'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', 'g', ...
             'DisplayName', sprintf('目标1最优（信号强度最大）\n负信号强度=%.2f, 切换次数=%.1f, 覆盖率=%.1f%%', ...
                                    PopObj(idx_obj1,1), switchCount_obj1, coverageRatio_obj1*100));
    else
        plot3(actualPath_obj1(:,1), actualPath_obj1(:,2), actualPath_obj1(:,3), 'g-s', ...
             'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', 'g', ...
             'DisplayName', sprintf('目标1最优（信号强度最大）\n负信号强度=%.2f, 切换次数=%.1f', ...
                                    PopObj(idx_obj1,1), switchCount_obj1));
    end
    
    % 目标2最优：切换次数最小（品红色）
    if numObjectives >= 3
        plot3(actualPath_obj2(:,1), actualPath_obj2(:,2), actualPath_obj2(:,3), 'm-d', ...
             'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', 'm', ...
             'DisplayName', sprintf('目标2最优（切换次数最小）\n负信号强度=%.2f, 切换次数=%.1f, 覆盖率=%.1f%%', ...
                                    PopObj(idx_obj2,1), switchCount_obj2, coverageRatio_obj2*100));
    else
        plot3(actualPath_obj2(:,1), actualPath_obj2(:,2), actualPath_obj2(:,3), 'm-d', ...
             'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', 'm', ...
             'DisplayName', sprintf('目标2最优（切换次数最小）\n负信号强度=%.2f, 切换次数=%.1f', ...
                                    PopObj(idx_obj2,1), switchCount_obj2));
    end

    % 目标3最优：覆盖率最大（青色）
    if numObjectives >= 3
        plot3(actualPath_obj3(:,1), actualPath_obj3(:,2), actualPath_obj3(:,3), 'c-p', ...
             'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', 'c', ...
             'DisplayName', sprintf('目标3最优（覆盖率最大）\n负信号强度=%.2f, 切换次数=%.1f, 覆盖率=%.1f%%', ...
                                    PopObj(idx_obj3,1), switchCount_obj3, coverageRatio_obj3*100));
    end
    
    xlabel('X坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Y坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
    zlabel('Z坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
    if numObjectives >= 3
        title('DCMOCPSO: 三个目标最优解的路径对比（3D）', 'FontSize', 14, 'FontWeight', 'bold');
    else
        title('DCMOCPSO: 两个目标最优解的路径对比（3D）', 'FontSize', 14, 'FontWeight', 'bold');
    end
    legend('Location', 'best', 'FontSize', 9);
    grid on;
    axis equal;
    xlim([-5, 505]);  % 地图范围0-500米
    ylim([-5, 505]);  % 地图范围0-500米
    % zlim需要覆盖建筑物高度和基站高度，设置为-5到90米
    if obstacleDrawn && maxBuildingHeight > 0
        zlim([-5, max(maxBuildingHeight + 10, 90)]);  % 至少到最高建筑物+10米
    else
        zlim([-5, 90]);  % 默认到90米，覆盖可能的基站高度
    end
    
    % 添加基站标签（3D）
    for i = 1:min(size(baseStations, 1), 20)  % 最多显示20个基站标签
        text(baseStations(i,1)+2, baseStations(i,2)+2, baseStations(i,3)+2, ...
             sprintf('BS%d', i), 'FontSize', 8, 'Color', 'red');
    end
    
    % 设置3D视角
    view(45, 30);
    
    hold off;
    
    %% 为每个最优解单独创建图，显示虚线信号连接基站
    fprintf('\n=== 为每个最优解创建单独路径图（含基站虚线连接） ===\n');
    
    % 准备路径数据
    paths = {actualPath_obj1, actualPath_obj2};
    pathNames = {'目标1最优（信号强度最大）', '目标2最优（切换次数最小）'};
    pathColors = {'g', 'm'};
    pathMarkers = {'s', 'd'};
    pathIndices = [idx_obj1, idx_obj2];
    
    if numObjectives >= 3
        paths{end+1} = actualPath_obj3;
        pathNames{end+1} = '目标3最优（覆盖率最大）';
        pathColors{end+1} = 'c';
        pathMarkers{end+1} = 'p';
        pathIndices(end+1) = idx_obj3;
    end
    
    % 为每个最优解创建单独图
    for pathIdx = 1:length(paths)
        currentPath = paths{pathIdx};
        currentName = pathNames{pathIdx};
        currentColor = pathColors{pathIdx};
        currentMarker = pathMarkers{pathIdx};
        currentPopObj = PopObj(pathIndices(pathIdx), :);
        
        % 计算每个航点连接的基站
        numWaypoints = size(currentPath, 1);
        connectedBS = zeros(numWaypoints, 1);
        previousBS = 0;
        
        fprintf('计算 %s 的基站连接...\n', currentName);
        for wpIdx = 1:numWaypoints
            waypoint = currentPath(wpIdx, :);
            
            % 计算信号强度
            distances = sqrt(sum((baseStations - repmat(waypoint, size(baseStations, 1), 1)).^2, 2));
            signalStrengths = zeros(size(baseStations, 1), 1);
            
            for bsIdx = 1:size(baseStations, 1)
                hasLOS = Problem.checkLineOfSight(waypoint, baseStations(bsIdx, :));
                distances(bsIdx) = max(distances(bsIdx), 0.1);
                if hasLOS
                    signalStrengths(bsIdx) = -20*log10(distances(bsIdx)) - 61.4;
                else
                    signalStrengths(bsIdx) = -40*log10(distances(bsIdx)) - 72;
                end
            end
            
            [maxSignal, currentBS] = max(signalStrengths);
            
            if wpIdx == 1
                connectedBS(wpIdx) = currentBS;
                previousBS = currentBS;
            else
                if maxSignal < Problem.getSwitchThreshold()
                    connectedBS(wpIdx) = currentBS;
                    previousBS = currentBS;
                else
                    connectedBS(wpIdx) = previousBS;
                end
            end
        end
        
        % 重新计算切换次数
        switchCount_current = 0;
        previousBS_switch = connectedBS(1);
        for wpIdx2 = 2:numWaypoints
            if connectedBS(wpIdx2) ~= previousBS_switch
                switchCount_current = switchCount_current + 1;
            end
            previousBS_switch = connectedBS(wpIdx2);
        end
        
        % 为基站分配颜色
        uniqueBSOrder = [];
        for i = 1:length(connectedBS)
            if i == 1 || connectedBS(i) ~= connectedBS(i-1)
                uniqueBSOrder = [uniqueBSOrder, connectedBS(i)];
            end
        end
        numUsedBS = length(uniqueBSOrder);
        numBS = size(baseStations, 1);
        bsColors = zeros(numBS, 3);
        
        if numUsedBS > 0
            goldenAngle = 0.618;
            for idx = 1:numUsedBS
                bsIdx = uniqueBSOrder(idx);
                if bsIdx > 0 && bsIdx <= numBS
                    hue = mod((idx - 1) * goldenAngle, 1);
                    bsColors(bsIdx, :) = hsv2rgb([hue, 0.85, 0.95]);
                end
            end
            for bsIdx = 1:numBS
                if ~ismember(bsIdx, uniqueBSOrder)
                    bsColors(bsIdx, :) = [0.85, 0.85, 0.85];
                end
            end
        else
            bsColors = lines(numBS);
        end
        
        % 创建单独图
        figure('Name', sprintf('%s - 路径与基站连接', currentName), ...
               'Position', [100 + pathIdx*50, 100 + pathIdx*50, 1200, 900]);
        hold on;
        
        % 绘制障碍物
        if exist('obstacles', 'var') && ~isempty(obstacles) && ndims(obstacles) == 3
            [gridX, gridY, ~] = size(obstacles);
            obsCount = 0;
            for x = 1:gridX
                for y = 1:gridY
                    obs = obstacles(x, y, :);
                    obs = obs(:)';
                    x_min = obs(1); y_min = obs(2);
                    x_max = obs(3); y_max = obs(4);
                    height = obs(5);
                    
                    vertices = [
                        x_min, y_min, 0; x_max, y_min, 0;
                        x_max, y_max, 0; x_min, y_max, 0;
                        x_min, y_min, height; x_max, y_min, height;
                        x_max, y_max, height; x_min, y_max, height
                    ];
                    faces = [1,2,3,4; 5,6,7,8; 1,2,6,5; 3,4,8,7; 1,4,8,5; 2,3,7,6];
                    
                    obsCount = obsCount + 1;
                    if obsCount == 1
                        patch('Faces', faces, 'Vertices', vertices, ...
                             'FaceColor', [0.7, 0.7, 0.7], 'FaceAlpha', 0.3, ...
                             'EdgeColor', 'k', 'LineWidth', 1, ...
                             'DisplayName', '建筑物障碍物');
                    else
                        patch('Faces', faces, 'Vertices', vertices, ...
                             'FaceColor', [0.7, 0.7, 0.7], 'FaceAlpha', 0.3, ...
                             'EdgeColor', 'k', 'LineWidth', 1, ...
                             'HandleVisibility', 'off');
                    end
                end
            end
        end
        
        % 绘制预设路径
        plot3(presetPath(:,1), presetPath(:,2), presetPath(:,3), 'b-o', ...
             'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'b', ...
             'DisplayName', '预设路径');
        
        % 绘制基站
        scatter3(baseStations(:,1), baseStations(:,2), baseStations(:,3), 200, 'r', '^', ...
                'filled', 'LineWidth', 2, 'DisplayName', '基站（建筑物顶端）');
        
        % 绘制路径线段（按基站颜色）
        for wpIdx = 1:numWaypoints-1
            wp1 = currentPath(wpIdx, :);
            wp2 = currentPath(wpIdx+1, :);
            bsIdx = connectedBS(wpIdx);
            plot3([wp1(1), wp2(1)], [wp1(2), wp2(2)], [wp1(3), wp2(3)], ...
                 '-', 'Color', bsColors(bsIdx, :), 'LineWidth', 2.5);
        end
        
        % 绘制航点和基站虚线连接
        for wpIdx = 1:numWaypoints
            waypoint = currentPath(wpIdx, :);
            bsIdx = connectedBS(wpIdx);
            
            % 绘制航点
            scatter3(waypoint(1), waypoint(2), waypoint(3), 150, ...
                    bsColors(bsIdx, :), currentMarker, 'filled', ...
                    'LineWidth', 2, 'MarkerEdgeColor', 'k');
            
            % 添加文本标签
            text(waypoint(1)+1, waypoint(2)+1, waypoint(3)+2, ...
                 sprintf('WP%d\nBS%d', wpIdx, bsIdx), ...
                 'FontSize', 8, 'Color', bsColors(bsIdx, :), ...
                 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
            
            % 绘制从航点到基站的虚线（关键！）
            plot3([waypoint(1), baseStations(bsIdx, 1)], ...
                 [waypoint(2), baseStations(bsIdx, 2)], ...
                 [waypoint(3), baseStations(bsIdx, 3)], ...
                 '--', 'Color', bsColors(bsIdx, :), 'LineWidth', 1, 'LineStyle', '--');
        end
        
        % 添加基站标签
        for bsIdx = 1:numBS
            text(baseStations(bsIdx,1)+2, baseStations(bsIdx,2)+2, baseStations(bsIdx,3)+2, ...
                 sprintf('BS%d', bsIdx), 'FontSize', 10, 'Color', 'red', ...
                 'FontWeight', 'bold');
        end
        
        % 设置标题和标签
        xlabel('X坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Y坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
        zlabel('Z坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
        
        % 根据目标数量显示不同的标题
        if numObjectives >= 3
            coverageRatio_current = -currentPopObj(3);
            title(sprintf('%s\n负信号强度=%.2f, 切换次数=%.1f, 覆盖率=%.1f%%', ...
                         currentName, currentPopObj(1), switchCount_current, coverageRatio_current*100), ...
                  'FontSize', 14, 'FontWeight', 'bold');
        else
            title(sprintf('%s\n负信号强度=%.2f, 切换次数=%.1f', ...
                         currentName, currentPopObj(1), switchCount_current), ...
                  'FontSize', 14, 'FontWeight', 'bold');
        end
        
        grid on;
        axis equal;
        xlim([-5, 505]);
        ylim([-5, 505]);
        if obstacleDrawn && maxBuildingHeight > 0
            zlim([-5, max(maxBuildingHeight + 10, 90)]);
        else
            zlim([-5, 90]);
        end
        
        view(45, 30);
        hold off;
        
        fprintf('  %s 图已创建\n', currentName);
    end
    
    %% 打印解的完整目标值信息
    if numObjectives >= 3
        fprintf('\n三个最优解的完整目标值：\n');
    else
        fprintf('\n两个/三个最优解的完整目标值：\n');
    end
    fprintf('  目标1最优解：\n');
    fprintf('    负平均信号强度: %.4f\n', PopObj(idx_obj1,1));
    fprintf('    切换次数: %.1f\n', PopObj(idx_obj1,2));
    if numObjectives >= 3
        fprintf('    负覆盖率: %.4f (覆盖率=%.2f%%)\n', PopObj(idx_obj1,3), -PopObj(idx_obj1,3)*100);
    end
    fprintf('  目标2最优解：\n');
    fprintf('    负平均信号强度: %.4f\n', PopObj(idx_obj2,1));
    fprintf('    切换次数: %.1f\n', PopObj(idx_obj2,2));
    if numObjectives >= 3
        fprintf('    负覆盖率: %.4f (覆盖率=%.2f%%)\n', PopObj(idx_obj2,3), -PopObj(idx_obj2,3)*100);
    end
    if numObjectives >= 3
        fprintf('  目标3最优解：\n');
        fprintf('    负平均信号强度: %.4f\n', PopObj(idx_obj3,1));
        fprintf('    切换次数: %.1f\n', PopObj(idx_obj3,2));
        fprintf('    负覆盖率: %.4f (覆盖率=%.2f%%)\n', PopObj(idx_obj3,3), -PopObj(idx_obj3,3)*100);
    end
    
    %% 显示分治算法的统计信息
    fprintf('\n=== DCMOCPSO算法统计信息 ===\n');
    fprintf('总函数评估次数: %d\n', Problem.FE);
    fprintf('分治策略: %d段，每段重叠%d个航点\n', 5, 1);
    fprintf('每段平均函数评估次数: %.0f\n', Problem.FE / 5);
    
else
    fprintf('种群为空，无法进行可视化\n');
end

fprintf('\n所有示例完成！\n');
