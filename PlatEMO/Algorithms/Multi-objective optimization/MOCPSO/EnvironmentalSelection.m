function Population = EnvironmentalSelection(Population,V,theta)
    % The environmental selection of LMOCSO
    
    %------------------------------- Copyright --------------------------------
    % Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
    % research purposes. All publications which use this platform or any code
    % in the platform should acknowledge the use of "PlatEMO" and reference "Ye
    % Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
    % for evolutionary multi-objective optimization [educational forum], IEEE
    % Computational Intelligence Magazine, 2017, 12(4): 73-87".
    %--------------------------------------------------------------------------
    
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
        Next = zeros(1,NV);
        for i = unique(associate)'
            % 对associate去重，反过来去找每个参考向量所对应要去选择的PopObj中的解
            current1 = find(associate==i & CV==0);
            current2 = find(associate==i & CV~=0);
            if ~isempty(current1)
                % Calculate the APD value of each solution
                % 左半边表示解与最近的那个参考向量的夹角，越小越好，用于表示多样性
                % 右半边表示解与理想点的距离，理想点为各目标的最小值，越小越好，用于表示收敛性
                APD = (1+M*theta*Angle(current1,i)/gamma(i)).*sqrt(sum(PopObj(current1,:).^2,2));
                % Select the one with the minimum APD value
                [~,best] = min(APD);
                Next(i)  = current1(best);
            elseif ~isempty(current2)
                % Select the one with the minimum CV value
                [~,best] = min(CV(current2));
                Next(i)  = current2(best);
            end
        end
        % Population for next generation
        Population = Population(Next(Next~=0));
    end