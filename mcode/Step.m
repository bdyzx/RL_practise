%函数功能：输入状态和动作，输出即时奖励和下一状态

function [SNext,Reward,isdone] = Step(dur,S,action)

Com_size = 32;
S_end = zeros(3,Com_size); S_end(3,:) = 1;
A_end = zeros(1,Com_size); A_end(Com_size) = 1;
%%
%3 根据action产生的后续状态sn,分两步转换。得到r    
NS=S; %S的下一状态

if isempty(find(action)) && S(2,Com_size)==1 %动作为空且虚尾为进行中活动 执行step2出错因为第一行dur时间为0
    %此时n必定为1
    NS(2,Com_size)=0; 
    NS(3,Com_size)=1;
    minNNS=1; %执行虚尾给一个固定奖励1 要是算的话是0/0
else %动作不为空 %还有一种可能动作为空 但虚尾不是进行活动，空动作可以执行下列
    for j =1:Com_size  %遍历动作向量32个位置，每个j对应动作编号
        if action(j)==1
            NS(2,j)=1;
            NS(1,j)=dur(j);
        end
    end
    %以上step1  
    %以下step2 减去最小时间（非零）相应位移到第三行
    NNS=NS; %NNS为中间量
    for j=1:Com_size
        if NNS(1,j)==0
            NNS(1,j)=1000;
        end
    end
    minNNS=min(NNS(1,:)); 
    if minNNS==1000
        minNNS=0;
    end
    %得到最小时间minNNS---即时奖励
    
    poNNS=find(NNS(1,:)==minNNS); 
    for j=1:Com_size
        if NS(1,j)~=0
            NS(1,j)=NS(1,j)-minNNS;
        end
    end
    for j=1:size(poNNS,2)
        NS(2,poNNS(j))=0; NS(3,poNNS(j))=1;
    end
    %以上都基于，动作的持续时间不为0
    %针对末尾活动持续时间为0
    if action == A_end
        NS(2,Com_size) = 0; NS(3,Com_size) = 1;
    end


end

%存到返回变量里 
SNext=NS;    
Reward=-minNNS; 

if sum(find(action)) == size(dur,1)
    isdone = 1; %第6位表示isdone
else
    isdone = 0;
end



end