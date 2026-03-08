function Population = EnvironmentalSelection(Population,V,theta,forceFeasible)
    % The environmental selection of LMOCSO
    % 只从可行解中筛选参考向量的对应解
    %
    %   输入参数：
    %       Population - 种群
    %       V - 参考向量
    %       theta - APD参数
    %       forceFeasible - 可选，已废弃（保持向后兼容，但不再使用）
    %
    %------------------------------- Copyright --------------------------------
    % Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
    % research purposes. All publications which use this platform or any code
    % in the platform should acknowledge the use of "PlatEMO" and reference "Ye
    % Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
    % for evolutionary multi-objective optimization [educational forum], IEEE
    % Computational Intelligence Magazine, 2017, 12(4): 73-87".
    %--------------------------------------------------------------------------
    
        % 保持向后兼容性（参数已废弃，不再使用）
        if nargin < 4
            forceFeasible = false;
        end
    
        % 检查输入种群是否为空
        if isempty(Population)
            warning('EnvironmentalSelection: 输入种群为空');
            return;
        end
        
        PopObj = Population.objs;

        [N,M]  = size(PopObj);
        NV     = size(V,1);
        
        %% Translate the population
        PopObj = PopObj - repmat(min(PopObj,[],1),N,1);
        
        %% Calculate the degree of violation of each solution
        CV = sum(max(0,Population.cons),2);
        
        %% Calculate the smallest angle value between each vector and others
        cosine = 1 - pdist2(V,V,'cosine');
        cosine(logical(eye(length(cosine)))) = 0;
        gamma  = min(acos(cosine),[],2);
    
        %% Associate each solution to a reference vector
        Angle = acos(1-pdist2(PopObj,V,'cosine'));
        % angle的长度是PopObj的行数，即解的个数，每一行表示解与各个参考向量的夹角
        % associate的长度是PopObj的行数，即解的个数，每个值表示对应最接近的参考向量的索引
        [~,associate] = min(Angle,[],2);
    
        %% Select one solution for each reference vector
        % 只从可行解中筛选参考向量的对应解
        Next = zeros(1,NV);
        for i = unique(associate)'
            % 对associate去重，反过来去找每个参考向量所对应要去选择的PopObj中的解
            % 只考虑可行解（CV==0）
            current = find(associate==i & CV==0);
            if ~isempty(current)
                % Calculate the APD value of each solution
                % 左半边表示解与最近的那个参考向量的夹角，越小越好，用于表示多样性
                % 右半边表示解与理想点的距离，理想点为各目标的最小值，越小越好，用于表示收敛性
                APD = (1+M*theta*Angle(current,i)/gamma(i)).*sqrt(sum(PopObj(current,:).^2,2));
                % Select the one with the minimum APD value
                [~,best] = min(APD);
                Next(i)  = current(best);
            end
            % 如果某个参考向量没有对应的可行解，则Next(i)保持为0，该参考向量不会被选择
        end
        % Population for next generation
        Population = Population(Next(Next~=0));
        % Population = Population(Next(Next~=0));
        
        % Next = Next(Next~=0);
        % if ~isempty(Next)
        %     Population = Population(Next);
        % else
        %     % 如果没有可行解，至少保留一些不可行解（约束违反度最小的）
        %     warning('EnvironmentalSelection: 没有可行解，保留约束违反度最小的解');
        %     if N > 0
        %         [~, sortedIdx] = sort(CV);
        %         % 至少保留min(NV, N)个解，但不超过种群大小
        %         numKeep = min(NV, N);
        %         Population = Population(sortedIdx(1:numKeep));
        %     else
        %         % 如果种群本身为空，返回空种群
        %         Population = Population([]);
        %     end
        % end
    end