% example_visualize_UAV.m
% 使用示例：可视化UAVPathPlanning数据
%
% 注意：文件名格式已更新为 UAVPathPlanning-BS%d.mat
%       航点数量不再需要指定，会根据路径长度和速度自动计算

clear; clc; close all;

%% 示例1：基本使用 - 读取并显示2D图（10个基站）
fprintf('示例1：显示2D平面图（10个基站）\n');
visualize_UAVPathPlanning(10);

pause(2);

%% 示例2：显示3D图
fprintf('\n示例2：显示3D图（10个基站）\n');
visualize_UAVPathPlanning(10, [], true);

pause(2);

%% 示例3：同时显示实际路径（2D）
fprintf('\n示例3：显示预设路径和实际路径对比（2D）\n');
% 生成一个示例实际路径（随机生成，仅用于演示）
% 注意：实际路径的航点数量应该与问题自动计算的航点数量匹配
actualPath = rand(30, 2) * 100;
visualize_UAVPathPlanning(10, actualPath, false);

pause(2);

%% 示例4：同时显示实际路径（3D）
fprintf('\n示例4：显示预设路径和实际路径对比（3D）\n');
visualize_UAVPathPlanning(10, actualPath, true);

pause(2);

%% 示例5：读取不同基站数量的数据文件
fprintf('\n示例5：读取15个基站的数据\n');
if exist('UAVPathPlanning-BS15.mat', 'file')
    visualize_UAVPathPlanning(15);
else
    fprintf('文件不存在，请先运行UAVPathPlanning问题生成数据\n');
    fprintf('可以使用以下命令生成：\n');
    fprintf('  Problem = UAVPathPlanning(''parameter'', {15, 10, 1, -80});\n');
end

pause(2);

%% 示例6：读取30个基站的数据
fprintf('\n示例6：读取30个基站的数据\n');
if exist('UAVPathPlanning-BS30.mat', 'file')
    visualize_UAVPathPlanning(30);
else
    fprintf('文件不存在，请先运行UAVPathPlanning问题生成数据\n');
end

fprintf('\n所有示例完成！\n');

