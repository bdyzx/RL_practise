function BZtime = DrawPlot(Q_net,DSM,dur,use_re,total_re)

Com_size = 32;
S_end=zeros(3,Com_size); S_end(2,Com_size) = 1; S_end(3,:) = 1; S_end(3,Com_size) = 0;

QNet_target = Q_net;

S = zeros(3,Com_size);
S(3,1) = 1;
SS2 = zeros(3*1000,Com_size); %#################
gt=zeros(Com_size,2);
timepointer=0;


while ~isequal(S,S_end)
    r_re=total_re;
    for i=1:Com_size
        if S(2,i)~=0
            r_re = r_re-use_re(i,:); %t_re是资源总量，每次要计算当前状态下的剩余资源
        end
    end

%%
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
%2 由当前状态和各动作，在QNet_target里选择价值最高的动作
    %RR=zeros(1,n); %存储当前状态每个动作的价值，在Qsa里查询
    S_batch = zeros(3,n); %每一列是样本 状态 动作
    px=sum(find(S(2,:)~=0))+1;
    py=sum(find(S(3,:)~=0))+1; 
    for i = 1:n
        pz=sum(find(A(i,:)~=0))+1;
        S_batch(:,i)=[px,py,pz]';
    end
    
    %由QNet_target得到各动作价值
    RR = sim(QNet_target,S_batch);
    
    %找到时间最短的（价值最高的动作）
    [~,pos] = max(RR); %第几个动作 和 第几个动作对应的后续状态
    po=pos(1); %相当于随机选取一个 第po个动作
    
%3 得到下一状态NS 时间指针增加时间ti    
    NS = S;
    if isempty(find(A(po,:))) && S(2,Com_size)==1 %动作为空且虚尾为进行中活动 执行step2出错因为第一行dur时间为0
        %此时n必定为1
        NS(2,Com_size)=0; 
        NS(3,Com_size)=1;
        ti=0;
    
    else
        for j =1:Com_size  %遍历动作向量32个位置，每个j对应动作编号
            if A(po,j)==1
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
        %得到最小时间 为minNNS

        %改变状态
        poNNS=find(NNS(1,:)==minNNS);
        for j=1:Com_size
            if NS(1,j)~=0
                NS(1,j)=NS(1,j)-minNNS;
            end
        end 
        for j=1:size(poNNS,2)
            NS(2,poNNS(j))=0; 
            NS(3,poNNS(j))=1;
        end
        ti = minNNS;
    end     
%以上对于循环来说足够了，因为产生了下一个S
    
% 4 计算甘特表画甘特图
    %录入开始时间
    ir=find(A(po,:));
    for i=1:size(ir,2)
        gt(ir(i),1)=timepointer;
    end
    
    %时间指针更新
    timepointer=timepointer+ti;
    
    %选择录入结束时间
    er=NS(3,:)-S(3,:); %下一状态和当前状态 已完成活动做差 新增的已完成活动
    er=find(er);
    for i=1:size(er,2)
        gt(er(i),2)=timepointer;
    end
    
    %更新S 进行episode内下一步
    S = NS;    
        
end

BZtime = gt(Com_size,1);

% gt(32,2)=gt(32,1);
% 
% %画图 横轴时间 纵轴活动数
% time=gt(size(gt,1),2);
% num=size(gt,1);
% axis([0,time,0,num]);%x轴 y轴的范围
% set(gca,'xtick',0:10:time) ;%x轴的增长幅度
% set(gca,'ytick',0:10:num) ;%y轴的增长幅度
% xlabel('时间'),ylabel('活动');%x轴 y轴的名称
% title('甘特图');%图形的标题
% 
% 
% rec=[0,0,0,0];%temp data space for every rectangle  
% 
% for i =1:num
%    rec(1) = gt(i,1);%矩形的横坐标
%    rec(2) = i;  %矩形的纵坐标
%    rec(3) = gt(i,2)-gt(i,1);  %矩形的x轴方向的长度
%    rec(4) = 0.6; 
% 
%    n_job_id=[1 9 8 2 0 4 6 9 3 0 6 4 7 1 5 8 3 8 2 1 1 8 9 6 8 5 8 4 2 0 6 0 ]; %32个0-9的数字
%    color=[1,0,0;0,1,0;0,0,1;1,1,0;1,0,1;0,1,1;0.67,0,1;1,.5,0;.9,.5,.2;.5,.5,.5];
% 
%    txt=sprintf('(%d,%d)=%d',gt(i,1),gt(i,2),i);%将开始时间，结束时间，活动编号连成字符串
%    rectangle('Position',rec,'LineWidth',0.5,'LineStyle','-','FaceColor',[color(n_job_id(i)+1,1),color(n_job_id(i)+1,2),color(n_job_id(i)+1,3)]);%draw every rectangle  
%    text((gt(i,1)+gt(i,2))/2-0.85,i+0.3,txt,'FontWeight','Bold','FontSize',8);%label the id of every task  ，字体的坐标和其它特性
% end






















