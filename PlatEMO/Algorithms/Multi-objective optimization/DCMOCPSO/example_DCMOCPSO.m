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
% 参数格式：{numSegments, segmentOverlap}
%   numSegments: 将问题分成多少段（子问题数量），默认5
%   segmentOverlap: 相邻段之间的重叠航点数，默认1
Algorithm = DCMOCPSO('parameter', {10, 1});

% 创建UAVPathPlanning问题
% 参数格式：{bsPerKm2, velocity, TTT, switchThreshold, obstacleMethod}
%   bsPerKm2: 每平方公里的基站数量
%   velocity: 无人机最大速度（m/s）
%   TTT: 时间间隔（s）
%   switchThreshold: 切换阈值（dBm）
%   obstacleMethod: 障碍物生成方法（0=default）
Problem = UAVPathPlanning('N', 50, 'maxFE', 100, 'parameter', {100, 10, 1, -85, 0});

fprintf('问题设置：\n');
fprintf('  航点数量: %d\n', Problem.D / 3);
fprintf('  种群大小: %d\n', Problem.N);
fprintf('  最大函数评估次数: %d\n', Problem.maxFE);
fprintf('  分治参数: %d段，每段重叠%d个航点\n', 10, 1);
fprintf('\n');

% 运行优化
Algorithm.Solve(Problem);

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
    PopObj = finalPopulation.objs;  % N×2矩阵，每行是一个解的目标值（两个目标）
    % 目标1：负平均信号强度（越小越好，即平均信号强度越大越好）
    % 目标2：切换次数（越小越好）
    
    % 找到每个目标的最优解
    [~, idx_obj1] = min(PopObj(:,1));  % 目标1最优（负信号强度最小，即信号强度最大）
    [~, idx_obj2] = min(PopObj(:,2));  % 目标2最优（切换次数最小）
    
    fprintf('目标1最优解索引: %d (负平均信号强度=%.4f)\n', idx_obj1, PopObj(idx_obj1,1));
    fprintf('目标2最优解索引: %d (切换次数=%.4f)\n', idx_obj2, PopObj(idx_obj2,2));
    
    % 如果只有一个解，使用同一个解
    if length(finalPopulation) == 1
        idx_obj2 = idx_obj1;
        fprintf('注意：只有一个解，两个目标使用同一个解\n');
    end
    
    % 提取两个最优解的路径（3D坐标：x, y, z）
    actualPath_obj1 = reshape(finalPopulation(idx_obj1).decs, 3, [])';
    actualPath_obj2 = reshape(finalPopulation(idx_obj2).decs, 3, [])';
    
    % 创建对比图（3D）
    figure('Name', 'DCMOCPSO: 两个目标最优解的路径对比', 'Position', [100, 100, 1400, 900]);
    
    % 加载预设路径、基站和障碍物
    % 文件名格式：UAVPathPlanning-%d-%d.mat（包含障碍物方法和每平方公里基站数量）
    obstacleMethod = 0;  % 与Problem创建时使用的障碍物方法一致
    bsPerKm2 = 100;    % 与Problem创建时使用的每平方公里基站数量一致
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
    
    % 重新计算切换次数以确保一致性（使用相同的Problem对象和参数）
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
    title('DCMOCPSO: 两个目标最优解的路径对比（3D）', 'FontSize', 14, 'FontWeight', 'bold');
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
    
    %% 打印解的完整目标值信息
    fprintf('\n两个最优解的完整目标值：\n');
    fprintf('  目标1最优解：\n');
    fprintf('    负平均信号强度: %.4f\n', PopObj(idx_obj1,1));
    fprintf('    切换次数: %.1f\n', PopObj(idx_obj1,2));
    fprintf('  目标2最优解：\n');
    fprintf('    负平均信号强度: %.4f\n', PopObj(idx_obj2,1));
    fprintf('    切换次数: %.1f\n', PopObj(idx_obj2,2));
    
    %% 显示分治算法的统计信息
    fprintf('\n=== DCMOCPSO算法统计信息 ===\n');
    fprintf('总函数评估次数: %d\n', Problem.FE);
    fprintf('分治策略: %d段，每段重叠%d个航点\n', 5, 1);
    fprintf('每段平均函数评估次数: %.0f\n', Problem.FE / 5);
    
else
    fprintf('种群为空，无法进行可视化\n');
end

fprintf('\n所有示例完成！\n');
