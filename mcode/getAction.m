%函数功能：输入状态，输出可选的所有动作
%伪代码中，根据Q_eval选取动作

function action = getAction(DSM,use_re,total_re,S,epsilon,QNet_eval)

Com_size = 32;

%1  计算当前状态 S 的动作可能 
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
                if n>50 && min(R<r_re*0.6)==1
                    continue
                end
                
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

%%
%2 根据epsilon贪心策略选择a   
%step1 计算Qsa
S_batch = zeros(3,n);
px=sum(find(S(2,:)~=0))+1;
py=sum(find(S(3,:)~=0))+1; 
for i = 1:n
    pz=sum(find(A(i,:)~=0))+1;
    S_batch(:,i) = [px;py;pz];
end
Qeval_S = sim(QNet_eval,S_batch);
%step2 设置随机种子，挑选a  
RandSeed = rand(1);
if RandSeed>epsilon
    [~,PoMax] = max(Qeval_S);
    action=A(PoMax,:); 

else
    PoMax = unidrnd(n);
    action=A(PoMax,:); 
end
% 得到action

end


