% example_visualize_with_result.m
% 示例：从优化结果中提取实际路径并可视化
%
% 这个示例展示如何：
% 1. 运行优化算法获取结果
% 2. 从结果中提取实际路径（航点坐标）
% 3. 对比不同目标的最优解

clear; clc; close all;

%% 运行优化算法
fprintf('=== 运行优化算法 ===\n');

% 运行优化并保存结果
Algorithm = MOCPSO();
% 参数格式：{bsPerKm2, velocity, TTT, switchThreshold, obstacleMethod}
%   bsPerKm2: 每平方公里的基站数量
%   velocity: 无人机最大速度（m/s）
%   TTT: 时间间隔（s）
%   switchThreshold: 切换阈值（dBm）
%   obstacleMethod: 障碍物生成方法（0=default）
% 如果不指定obstacleMethod，默认使用0
% 注意：地图面积约为0.09 km²（300m x 300m），所以每平方公里基站数量会按比例计算
% 预设路径是固定的：起点(45,45,40) -> 终点(268,223,40)，包含6个路径点
Problem = UAVPathPlanning('N', 50, 'maxFE', 500, 'parameter', {100, 10, 1, -85, 0});
Algorithm.Solve(Problem);

% 获取最终种群
finalPopulation = Algorithm.result{end};
fprintf('最终种群大小: %d\n', length(finalPopulation));
fprintf('\n');

%% 方法3：对比两个不同目标的最优解
fprintf('\n=== 方法3：对比两个不同目标的最优解 ===\n');

if length(finalPopulation) >= 2
    % 提取所有解的目标值
    PopObj = finalPopulation.objs;  % N×2矩阵，每行是一个解的目标值
    % 目标1：负平均信号强度（越小越好，即平均信号强度越大越好）
    % 目标2：切换次数（越小越好）
    
    % 找到每个目标的最优解
    [~, idx_obj1] = min(PopObj(:,1));  % 目标1最优（负信号强度最小，即信号强度最大）
    [~, idx_obj2] = min(PopObj(:,2));  % 目标2最优（切换次数最小）
    
    fprintf('目标1最优解索引: %d (负平均信号强度=%.4f)\n', idx_obj1, PopObj(idx_obj1,1));
    fprintf('目标2最优解索引: %d (切换次数=%.4f)\n', idx_obj2, PopObj(idx_obj2,2));
    
    % 提取两个最优解的路径（3D坐标：x, y, z）
    actualPath_obj1 = reshape(finalPopulation(idx_obj1).decs, 3, [])';
    actualPath_obj2 = reshape(finalPopulation(idx_obj2).decs, 3, [])';
    
    % 创建对比图（3D）
    figure('Name', '两个目标最优解的路径对比', 'Position', [100, 100, 1400, 900]);
    
    % 加载预设路径、基站和障碍物
    % 文件名格式：UAVPathPlanning-%d-%d.mat（包含障碍物方法和每平方公里基站数量）
    obstacleMethod = 0;  % 与Problem创建时使用的障碍物方法一致
    bsPerKm2 = 100;    % 与Problem创建时使用的每平方公里基站数量一致
    file = sprintf('UAVPathPlanning-%d-%d.mat', obstacleMethod, bsPerKm2);
    file = fullfile(fileparts(mfilename('fullpath')), file);
    
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
    for bs_idx = 1:size(baseStations, 1)
        fprintf('  基站 %d: (%.2f, %.2f, %.2f)\n', bs_idx, ...
                baseStations(bs_idx, 1), baseStations(bs_idx, 2), baseStations(bs_idx, 3));
    end
    
    scatter3(baseStations(:,1), baseStations(:,2), baseStations(:,3), 200, 'r', '^', ...
            'filled', 'LineWidth', 2, 'DisplayName', '基站（建筑物顶端）');
    
    % 重新计算切换次数以确保一致性（使用相同的Problem对象和参数）
    % 使用优化时的Problem对象，确保参数一致
    fprintf('重新计算两个最优解的切换次数以确保一致性...\n');
    switchCount_obj1 = Problem.calculateSwitchCount(actualPath_obj1);
    switchCount_obj2 = Problem.calculateSwitchCount(actualPath_obj2);
    
    fprintf('  目标1最优：切换次数=%.1f (原值=%.1f)\n', switchCount_obj1, PopObj(idx_obj1,2));
    fprintf('  目标2最优：切换次数=%.1f (原值=%.1f)\n', switchCount_obj2, PopObj(idx_obj2,2));
    
    % 绘制两个目标的最优解（3D）
    % 目标1最优：信号强度最大（绿色）
    plot3(actualPath_obj1(:,1), actualPath_obj1(:,2), actualPath_obj1(:,3), 'g-s', ...
         'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', 'g', ...
         'DisplayName', sprintf('目标1最优（信号强度最大）\n负信号强度=%.2f, 切换次数=%.1f', ...
                                PopObj(idx_obj1,1), switchCount_obj1));
    
    % 目标2最优：切换次数最小（品红色）
    plot3(actualPath_obj2(:,1), actualPath_obj2(:,2), actualPath_obj2(:,3), 'm-d', ...
         'LineWidth', 2.5, 'MarkerSize', 7, 'MarkerFaceColor', 'm', ...
         'DisplayName', sprintf('目标2最优（切换次数最小）\n负信号强度=%.2f, 切换次数=%.1f', ...
                                PopObj(idx_obj2,1), switchCount_obj2));
    
    xlabel('X坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Y坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
    zlabel('Z坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
    title('两个目标最优解的路径对比（3D）', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 9);
    grid on;
    axis equal;
    xlim([-5, 505]);  % 地图范围0-300米
    ylim([-5, 505]);  % 地图范围0-300米
    % zlim需要覆盖建筑物高度和基站高度，设置为-5到90米
    if obstacleDrawn && maxBuildingHeight > 0
        zlim([-5, max(maxBuildingHeight + 10, 90)]);  % 至少到最高建筑物+10米
    else
        zlim([-5, 90]);  % 默认到90米，覆盖可能的基站高度
    end
    
    % 添加基站标签（3D）
    for i = 1:size(baseStations, 1)
        text(baseStations(i,1)+2, baseStations(i,2)+2, baseStations(i,3)+2, ...
             sprintf('BS%d', i), 'FontSize', 8, 'Color', 'red');
    end
    
    % 设置3D视角
    view(45, 30);
    
    hold off;
    
    %% 为两个最优解分别创建单独的图，显示每个航点连接的基站
    fprintf('\n=== 创建两个最优解的单独路径图 ===\n');
    
    % 使用优化时的Problem对象，确保参数一致（特别是switchThreshold）
    % 不需要重新创建，直接使用优化时的Problem对象
    
    % 为每个最优解创建单独的图
    paths = {actualPath_obj1, actualPath_obj2};
    pathNames = {'目标1最优（信号强度最大）', '目标2最优（切换次数最小）'};
    pathColors = {'g', 'm'};
    pathMarkers = {'s', 'd'};
    pathIndices = [idx_obj1, idx_obj2];
    
    for pathIdx = 1:2
        currentPath = paths{pathIdx};
        currentName = pathNames{pathIdx};
        currentColor = pathColors{pathIdx};
        currentMarker = pathMarkers{pathIdx};
        currentPopObj = PopObj(pathIndices(pathIdx), :);
        
        % 计算每个航点连接的基站
        % 切换逻辑：信号强度低于阈值时才改变基站为信号最强的基站
        % 信号强度足够（>=阈值）时，保持当前基站不变
        numWaypoints = size(currentPath, 1);
        connectedBS = zeros(numWaypoints, 1);  % 存储每个航点连接的基站索引
        previousBS = 0;  % 上一个航点连接的基站索引
        
        fprintf('计算 %s 的基站连接...\n', currentName);
        for wpIdx = 1:numWaypoints
            waypoint = currentPath(wpIdx, :);
            
            % 计算当前航点到所有基站的距离（3D距离）
            distances = sqrt(sum((baseStations - repmat(waypoint, size(baseStations, 1), 1)).^2, 2));
            
            % 计算信号强度（考虑视距/非视距）
            signalStrengths = zeros(size(baseStations, 1), 1);
            for bsIdx = 1:size(baseStations, 1)
                % 检查是否有视距（LOS）
                hasLOS = Problem.checkLineOfSight(waypoint, baseStations(bsIdx, :));
                
                distances(bsIdx) = max(distances(bsIdx), 0.1);
                if hasLOS
                    % 视距（LOS）路径损耗模型
                    signalStrengths(bsIdx) = -20*log10(distances(bsIdx)) - 61.4;  % dBm
                else
                    % 非视距（NLOS）路径损耗模型（更大的衰减）
                    signalStrengths(bsIdx) = -40*log10(distances(bsIdx)) - 72;  % dBm
                end
            end
            
            % 选择信号最强的基站
            [maxSignal, currentBS] = max(signalStrengths);
            
            % 确保基站索引有效（MATLAB索引从1开始）
            if currentBS < 1 || currentBS > size(baseStations, 1)
                warning('航点 %d: 无效的基站索引 %d，使用索引1', wpIdx, currentBS);
                currentBS = 1;
            end
            
            % 判断是否需要改变基站
            if wpIdx == 1
                % 第一个航点，初始化基站连接
                connectedBS(wpIdx) = currentBS;
                previousBS = currentBS;
            else
                % 检查信号强度是否低于阈值
                if maxSignal < Problem.getSwitchThreshold()
                    % 信号强度低于阈值，改变基站为信号最强的基站
                    connectedBS(wpIdx) = currentBS;
                    previousBS = currentBS;
                else
                    % 信号强度足够（>=阈值），保持当前基站不变
                    connectedBS(wpIdx) = previousBS;
                    % previousBS保持不变
                end
            end
            
            % 重新计算切换次数以确保一致性
            % 切换的定义：信号强度低于阈值时才改变基站，一改变基站就算切换
            switchCount_current = 0;
            previousBS_switch = connectedBS(1);  % 第一个航点的基站
            
            for wpIdx2 = 2:numWaypoints
                % 如果基站改变，说明发生了切换
                if connectedBS(wpIdx2) ~= previousBS_switch
                    switchCount_current = switchCount_current + 1;
                    fprintf('    切换发生在航点 WP%d: 从 BS%d 切换到 BS%d\n', ...
                           wpIdx2, previousBS_switch, connectedBS(wpIdx2));
                end
                previousBS_switch = connectedBS(wpIdx2);
            end
            
            fprintf('  %s 切换次数: %.1f (优化时计算值: %.1f)\n', currentName, switchCount_current, currentPopObj(2));
            
            % 为基站分配颜色，确保相邻切换的基站颜色差异大
            % 找出路径中使用的基站（按出现顺序）
            usedBSOrder = connectedBS;  % 保持使用顺序
            uniqueBSOrder = [];
            for i = 1:length(usedBSOrder)
                if i == 1 || usedBSOrder(i) ~= usedBSOrder(i-1)
                    uniqueBSOrder = [uniqueBSOrder, usedBSOrder(i)];
                end
            end
            numUsedBS = length(uniqueBSOrder);
            
            % 获取基站总数
            numBS = size(baseStations, 1);
            
            % 创建颜色映射，确保相邻基站颜色差异大
            bsColors = zeros(numBS, 3);
            
            if numUsedBS > 0
                % 使用HSV颜色空间，在色相上均匀分布
                % 为了确保相邻颜色差异大，使用黄金角度分割（约137.5度）
                goldenAngle = 0.618;  % 黄金比例约0.618，对应约222.5度的色相
                
                % 为每个使用的基站分配颜色
                for idx = 1:numUsedBS
                    bsIdx = uniqueBSOrder(idx);
                    % 检查索引是否有效（必须是正整数且不超过numBS）
                    if bsIdx > 0 && bsIdx <= numBS
                        % 使用黄金角度分割，确保相邻颜色差异大
                        hue = mod((idx - 1) * goldenAngle, 1);
                        % HSV转RGB：H=hue, S=0.85, V=0.95（高饱和度，高亮度）
                        bsColors(bsIdx, :) = hsv2rgb([hue, 0.85, 0.95]);
                    else
                        warning('无效的基站索引: %d，跳过颜色分配', bsIdx);
                    end
                end
                
                % 未使用的基站使用浅灰色
                for bsIdx = 1:numBS
                    if ~ismember(bsIdx, uniqueBSOrder)
                        bsColors(bsIdx, :) = [0.85, 0.85, 0.85];
                    end
                end
            else
                % 如果没有使用的基站，使用默认颜色映射
                bsColors = lines(numBS);
            end
        end
        
        % 创建单独的图
        figure('Name', sprintf('%s - 路径与基站连接', currentName), ...
               'Position', [100 + pathIdx*50, 100 + pathIdx*50, 1200, 900]);
        hold on;
        
        % 绘制障碍物（建筑物）
        if exist('obstacles', 'var') && ~isempty(obstacles) && ndims(obstacles) == 3
            [gridX, gridY, ~] = size(obstacles);
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
                    
                    vertices = [
                        x_min, y_min, 0;
                        x_max, y_min, 0;
                        x_max, y_max, 0;
                        x_min, y_max, 0;
                        x_min, y_min, height;
                        x_max, y_min, height;
                        x_max, y_max, height;
                        x_min, y_max, height
                    ];
                    
                    faces = [
                        1, 2, 3, 4;
                        5, 6, 7, 8;
                        1, 2, 6, 5;
                        3, 4, 8, 7;
                        1, 4, 8, 5;
                        2, 3, 7, 6
                    ];
                    
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
        
        % 绘制实际路径，并用不同颜色/标记表示连接的基站
        numBS = size(baseStations, 1);
        
        % 绘制路径线段
        for wpIdx = 1:numWaypoints-1
            wp1 = currentPath(wpIdx, :);
            wp2 = currentPath(wpIdx+1, :);
            bsIdx = connectedBS(wpIdx);
            plot3([wp1(1), wp2(1)], [wp1(2), wp2(2)], [wp1(3), wp2(3)], ...
                 '-', 'Color', bsColors(bsIdx, :), 'LineWidth', 2.5);
        end
        
        % 绘制航点，并用颜色表示连接的基站
        for wpIdx = 1:numWaypoints
            waypoint = currentPath(wpIdx, :);
            bsIdx = connectedBS(wpIdx);
            
            % 绘制航点，颜色对应连接的基站
            scatter3(waypoint(1), waypoint(2), waypoint(3), 150, ...
                    bsColors(bsIdx, :), currentMarker, 'filled', ...
                    'LineWidth', 2, 'MarkerEdgeColor', 'k');
            
            % 添加文本标签，显示航点编号和连接的基站
            text(waypoint(1)+1, waypoint(2)+1, waypoint(3)+2, ...
                 sprintf('WP%d\nBS%d', wpIdx, bsIdx), ...
                 'FontSize', 8, 'Color', bsColors(bsIdx, :), ...
                 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
            
            % 绘制从航点到基站的连线（虚线，表示连接关系）
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
        
        xlabel('X坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Y坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
        zlabel('Z坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
        % 使用重新计算的切换次数
        title(sprintf('%s\n负信号强度=%.2f, 切换次数=%.1f', ...
                     currentName, currentPopObj(1), switchCount_current), ...
              'FontSize', 14, 'FontWeight', 'bold');
        
        % 创建图例
        legendEntries = {'预设路径', '基站（建筑物顶端）', '建筑物障碍物'};
        % 添加基站颜色说明
        for bsIdx = 1:min(numBS, 10)  % 最多显示10个基站的颜色
            legendEntries{end+1} = sprintf('连接BS%d的航点', bsIdx);
        end
        legend(legendEntries, 'Location', 'best', 'FontSize', 9);
        
        grid on;
        axis equal;
        xlim([-5, 305]);  % 地图范围0-300米
        ylim([-5, 305]);  % 地图范围0-300米
        if exist('obstacles', 'var') && ~isempty(obstacles) && ndims(obstacles) == 3
            % 找到最高建筑物高度
            maxHeight = 0;
            [gridX, gridY, ~] = size(obstacles);
            for x = 1:gridX
                for y = 1:gridY
                    height = obstacles(x, y, 5);
                    if height > maxHeight
                        maxHeight = height;
                    end
                end
            end
            zlim([-5, max(maxHeight + 10, 90)]);
        else
            zlim([-5, 90]);
        end
        
        view(45, 30);
        hold off;
        
        fprintf('  %s 图已创建\n', currentName);
    end
    
    % 打印两个解的完整目标值信息
    fprintf('\n两个最优解的完整目标值：\n');
    fprintf('  目标1最优解：\n');
    fprintf('    负平均信号强度: %.4f\n', PopObj(idx_obj1,1));
    fprintf('    切换次数: %.1f\n', PopObj(idx_obj1,2));
    fprintf('  目标2最优解：\n');
    fprintf('    负平均信号强度: %.4f\n', PopObj(idx_obj2,1));
    fprintf('    切换次数: %.1f\n', PopObj(idx_obj2,2));
else
    fprintf('种群大小不足，无法进行对比（需要至少2个解）\n');
end

fprintf('\n所有示例完成！\n');

