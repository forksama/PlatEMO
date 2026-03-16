%% Polynomial mutation
% 参数：
%   Problem: 问题对象
%   OffDec: 决策变量矩阵 (2*N x D)
%   OffVel: 速度矩阵 (2*N x D)
%   N: 粒子数量
%   D: 决策变量维度
%   mutationRateMultiplier: 变异率乘数（可选，默认1.0）
%       - 用于动态调整变异概率，例如：
%         0-20%迭代: 2.0 (强化探索)
%         20-40%: 1.5
%         40-60%: 1.0 (标准)
%         60-80%: 0.75
%         80-100%: 0.5 (强化收敛)
function Offspring = Polynomial_mutation(Problem,OffDec,OffVel,N,D,mutationRateMultiplier)
        % 处理可选参数
        if nargin < 6
            mutationRateMultiplier = 1.0;  % 默认不改变变异率
        end
        
        Lower  = repmat(Problem.lower,2*N,1);
        Upper  = repmat(Problem.upper,2*N,1);
        disM   = 20;
        
        % 动态变异概率：基础概率 1/D * mutationRateMultiplier
        % 限制在 [0, 1] 范围内
        mutationRate = min(1.0, (1/D) * mutationRateMultiplier);
        Site   = rand(2*N,D) < mutationRate;
        mu     = rand(2*N,D);
        temp   = Site & mu<=0.5;
        OffDec       = max(min(OffDec,Upper),Lower);
        OffDec(temp) = OffDec(temp)+(Upper(temp)-Lower(temp)).*((2.*mu(temp)+(1-2.*mu(temp)).*...
                        (1-(OffDec(temp)-Lower(temp))./(Upper(temp)-Lower(temp))).^(disM+1)).^(1/(disM+1))-1);
        temp  = Site & mu>0.5; 
        OffDec(temp) = OffDec(temp)+(Upper(temp)-Lower(temp)).*(1-(2.*(1-mu(temp))+2.*(mu(temp)-0.5).*...
                        (1-(Upper(temp)-OffDec(temp))./(Upper(temp)-Lower(temp))).^(disM+1)).^(1/(disM+1)));
        
        Offspring = SOLUTION(OffDec,OffVel);
end