function Fitness = calFitness(PopObj)
% Calculate the fitness by shift-based density

    N      = size(PopObj,1);
    fmax   = max(PopObj,[],1);
    fmin   = min(PopObj,[],1);
    PopObj = (PopObj-repmat(fmin,N,1))./repmat(fmax-fmin,N,1);
    Dis    = inf(N);

    % 如果PopObj(i,:)优于（小于）PopObj(j,:)，则Dis(i,j) 有值
    % 如果PopObj(i,:)劣于（大于）PopObj(j,:)，则Dis(i,j) = 0
    % 也就是说，Dis(i,j) 的值越大，PopObj(i,:) 越优秀
    % 因此，Fitness 表示的是，PopObj(i,:) 与其他所有解的距离的最小值，越大则说明PopObj(i,:)总体上越优秀
    for i = 1 : N
        SPopObj = max(PopObj,repmat(PopObj(i,:),N,1));
        for j = [1:i-1,i+1:N]
            Dis(i,j) = norm(PopObj(i,:)-SPopObj(j,:));
        end
    end
    Fitness = min(Dis,[],2);
end