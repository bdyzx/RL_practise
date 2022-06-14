%填满经验复用池的策略要求不严格 
%主程序中动作挑选epsilon贪心，Q值由Q_eval计算得出
%初始化中，随机选择


function [ReMemo,ReMemoReward] = Full_ReMemo(DSM,dur,use_re,total_re,memo_size)

Com_size = 32;
S_end = zeros(3,Com_size); S_end(3,:) = 1;
A_end = zeros(1,Com_size); A_end(Com_size) = 1;

%初始化 
FLAG = 0;
flag_node=0;
S_init = zeros(3,Com_size); S_init(3,1) = 1; 
ReMemo = zeros(6,memo_size);
ReMemoReward = zeros(1,memo_size);

while 1  %episode循环
    if FLAG ==1
        break 
    end
    
    flag = 0;
    S_next = S_init;
    
    while flag==0  %episode内每步循环
        S = S_next;
    
%2  计算当前状态 S 的动作可能 
        po = find(S(3,:)==1);
        dsm = (1:Com_size)';dsm = [DSM,dsm];%############
        Rmark = size(po,2);
        for i = 1:Rmark   
            for j=1:size(dsm,1)
                if(dsm(j,size(dsm,2))==po(i)) %寻找删除
                    MSD=dsm;
                    MSD(:,j)=[];
                    MSD(j,:)=[];
                    dsm=MSD;
                    break;
                end
            end
        end

        record = [];       %一个活动结束后，时序关系上可以进行的新活动 
        Rmark=size(dsm,1);
        for i=1:Rmark
            for j=1:Rmark
                if(dsm(i,j)==1)
                    break
                end
                if(j==Rmark)
                    record=[record,dsm(i,Rmark+1)];
                end
            end
        end
        %进行中的活动不能进record
        [~, ia] = setdiff(record,find(S(2,:)));
        record = record(sort(ia));

        A = zeros(5000,Com_size);%##########
        n=1;

        if ~isempty(record)  %如果record为空，则只能进行空动作  
            %剩余资源总量
            r_re = total_re;
            for i=1:Com_size
                if S(2,i)~=0
                    r_re = r_re-use_re(i,:); %每次要计算当前状态下的剩余资源,每次从全资源开始
                end
            end
            
            Rmark = size(record,2);
            for i = Rmark:-1:1
                B=nchoosek(record,i);
                for j = 1:size(B,1)
                    a=zeros(1,Com_size);
                    for k = 1:i
                        a(B(j,k))=1; 
                    end
                    %以上产生动作，以下判断该动作所需资源
                    R=a*use_re;
                    if min(R<=r_re)==1  %四个资源全部满足条件——小于当前资源总量
                        n=n+1;
                        A(n,:)=a;
                    end
                end
            end
            %A为动作集合 n记录着有几个动作 用资源约束筛选哪些动作实际可行

            if isempty(find(S(2,:))) %&& max(A(n,:))~=0 %后面这个条件为了防止当前时刻只能进行空活动
            %执行说明第二行全零 无进行中活动
                n=n-1;
                A(1,:) = [];
            end

        end
        %进行中的活动为空的状态不能选取空动作，不然会套娃

%得到A和n

%__________________________________________________________________________
        %经验复用池填满，就用随机策略了——也可更改
        action = unidrnd(n);

%__________________________________________________________________________
    
    %3   动作产生的后续状态,分两步转换
        i = action;
        NS=S; %S的下一状态
        if isempty(find(A(action,:))) && S(2,Com_size)==1 %动作为空且虚尾为进行中活动 执行step2出错因为第一行dur时间为0
            %此时n必定为1
            break %跳出就相当于结束这个环节
        end

        if ~isempty(find(A(action,:))) %动作不为空
            for j =1:Com_size  %遍历动作向量32个位置，每个j对应动作编号
                if A(i,j)==1
                    NS(2,j)=1;
                    NS(1,j)=dur(j);
                end
            end
            %以上step1  以下step2 减去最小时间（非零）相应位移到第三行
        end

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
        if A(action,:) == A_end
            NS(2,Com_size) = 0; NS(3,Com_size) = 1;
        end

        %到此得到S状态下选取一个动作的后续状态 
        
        %记录到经验复用池
        flag_node = flag_node + 1;
        ReMemo(1,flag_node) = sum(find(S(2,:)))+1;
        ReMemo(2,flag_node) = sum(find(S(3,:)))+1;
        ReMemo(3,flag_node) = sum(find(A(action,:)))+1;
        ReMemo(4,flag_node) = sum(find(NS(2,:)))+1;
        ReMemo(5,flag_node) = sum(find(NS(3,:)))+1;
        ReMemoReward(flag_node) = -minNNS;

        S_next = NS;
        %episode终止判定 更新的S如果是虚尾则结束
        if isequal(S_next,S_end)
            flag=1; 
        end
        if flag_node == memo_size
            FLAG = 1;
            break 
        end
    end    
end

for i = 1:memo_size
    if ReMemo(3,i) == size(DSM,1)+1 
        ReMemo(6,i) = 1; %第6位表示isdone
    end
end




