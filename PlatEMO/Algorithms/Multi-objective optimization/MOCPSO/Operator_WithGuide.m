function [Offspring1, Offspring2, Offspring3] = Operator_WithGuide(Loser1, Loser2, Winner, GuideDec, c_guide, Problem)
% Operator_WithGuide - 带引导粒子的竞争粒子群优化器
%
% 在原始MOCPSO的Operator基础上，加入向引导粒子的权重项：
%   CV_Func: OutVel = r1.*LoserVel + r2.*(WinnerDec-LoserDec) + c_guide*r_guide.*(GuideDec-LoserDec)
%   DV_Func: OffVel = c1*r1.*LoserVel + c2*r2.*(WinnerDec-LoserDec) + c3.*(xr-LoserDec) 
%                    + c4*r3.*(LoserDec-TmpDec) + c_guide*r_guide.*(GuideDec-LoserDec)
%
% 输入参数：
%   Loser1, Loser2, Winner - 分组后的粒子群（SOLUTION对象）
%   GuideDec               - 引导粒子的决策变量 (1 x D)
%   c_guide                - 引导权重系数
%   Problem                - 问题对象
%
% 输出：
%   Offspring1, Offspring2, Offspring3 - 三组子代粒子
%
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% Parameter setting
    Loser1Dec = Loser1.decs;
    Loser2Dec = Loser2.decs;
    WinnerDec = Winner.decs;
    [N, D] = size(Loser1Dec);
    
    Loser1Vel = Loser1.adds(zeros(N, D));
    Loser2Vel = Loser2.adds(zeros(N, D));
    WinnerVel = Winner.adds(zeros(N, D));
    
    %% 更新操作（带引导粒子）
    % Winner: 保持纯DSS（不加引导，避免自我强化）
    [WinOffVel, WinOffDec] = DV_Func_WithGuide(Winner, Winner, [], 0, Problem);
    
    % Loser1: 35% CSS + 65% DSS（混合策略）
    if rand > 0.35
        [Loser1OffVel, Loser1OffDec] = CV_Func_WithGuide(Loser1, Winner, GuideDec, c_guide, Problem);
    else
        [Loser1OffVel, Loser1OffDec] = DV_Func_WithGuide(Loser1, Winner, GuideDec, c_guide, Problem);
    end
    
    % Loser2: 纯CSS
    [Loser2OffVel, Loser2OffDec] = CV_Func_WithGuide(Loser2, Winner, GuideDec, c_guide, Problem);
    
    %% Add the winners（保留Winner粒子）
    Loser1OffDec = [Loser1OffDec; WinnerDec];
    Loser1OffVel = [Loser1OffVel; WinnerVel];
    
    Loser2OffDec = [Loser2OffDec; WinnerDec];
    Loser2OffVel = [Loser2OffVel; WinnerVel];
    
    WinOffDec = [WinOffDec; WinnerDec];
    WinOffVel = [WinOffVel; WinnerVel];
    
    %% 多项式变异
    Offspring1 = Polynomial_mutation(Problem, Loser1OffDec, Loser1OffVel, N, D);
    Offspring2 = Polynomial_mutation(Problem, Loser2OffDec, Loser2OffVel, N, D);
    Offspring3 = Polynomial_mutation(Problem, WinOffDec, WinOffVel, N, D);
end

%% CV_Func_WithGuide - 收敛策略（带引导粒子）
function [OutVel, OutDec] = CV_Func_WithGuide(Loser, Winner, GuideDec, c_guide, Problem)
    LoserDec = Loser.decs;
    [N, D] = size(LoserDec);
    LoserVel = Loser.adds(zeros(N, D));
    WinnerDec = Winner.decs;
    
    if size(LoserVel, 1) == 0
        OutVel = LoserVel;
        OutDec = LoserDec;
        return;
    end
    
    % 原始参数
    c1 = 0.125;
    
    % 随机系数
    r1 = repmat(rand(N, 1), 1, D);
    r2 = repmat(rand(N, 1), 1, D);
    r3 = repmat(rand(N, 1), 1, D);
    
    % 原始速度更新
    OutVel = r1.*LoserVel + r2.*(WinnerDec - LoserDec);
    
    % 加入引导项（如果提供了引导粒子）
    if ~isempty(GuideDec) && c_guide > 0
        r_guide = repmat(rand(N, 1), 1, D);
        OutVel = OutVel + c_guide * r_guide .* (repmat(GuideDec, N, 1) - LoserDec);
    end
    
    % 位置更新
    OutDec = LoserDec + OutVel;
    
    % 向Winner微调
    OutDec = OutDec + c1 * r3 .* (WinnerDec - OutDec);
end

%% DV_Func_WithGuide - 发散策略（带引导粒子）
function [OutVel, OutDec] = DV_Func_WithGuide(Loser, Winner, GuideDec, c_guide, Problem)
    LoserDec = Loser.decs;
    [N, D] = size(LoserDec);
    LoserVel = Loser.adds(zeros(N, D));
    WinnerDec = Winner.decs;
    
    if size(LoserVel, 1) == 0
        OutVel = LoserVel;
        OutDec = LoserDec;
        return;
    end
    
    % 非支配排序和最近邻选择
    LoserObjs = Loser.objs;
    [FrontNo, MaxFNo] = NDSort(LoserObjs, inf);
    
    for i = 1:MaxFNo
        tmpNo = find(i == FrontNo);
        dis = pdist2(LoserObjs(tmpNo, :), LoserObjs(tmpNo, :));
        dis(dis == 0) = inf;
        [~, tmpIndex] = min(dis);
        FrontNo(tmpNo) = tmpIndex;
    end
    
    TmpDec = repmat(LoserDec(FrontNo, :), 1, 1);
    
    % 原始参数
    c1 = 1.3;
    c2 = 1.2;
    c3 = 0.13;
    c4 = 1.28;
    
    % 随机系数
    r1 = repmat(rand(N, 1), 1, D);
    r2 = repmat(rand(N, 1), 1, D);
    r3 = repmat(rand(N, 1), 1, D);
    
    % 随机探索范围
    max_tmp = max(LoserDec + 0.5, [], 2);
    min_tmp = min(LoserDec .* 0.1, [], 2);
    max_tmp = min(max_tmp, Problem.upper);
    min_tmp = max(min_tmp, Problem.lower);
    
    xr = unifrnd(repmat(min_tmp, 1, 1), repmat(max_tmp, 1, 1));
    
    % 原始速度更新
    OffVel = c1*r1.*LoserVel + c2*r2.*(WinnerDec - LoserDec) + c3.*(xr - LoserDec) + c4*r3.*(LoserDec - TmpDec);
    
    % 加入引导项（如果提供了引导粒子）
    if ~isempty(GuideDec) && c_guide > 0
        r_guide = repmat(rand(N, 1), 1, D);
        OffVel = OffVel + c_guide * r_guide .* (repmat(GuideDec, N, 1) - LoserDec);
    end
    
    % 位置更新
    OffDec = LoserDec + OffVel;
    
    OutDec = OffDec;
    OutVel = OffVel;
end
