%完全按照伪代码中格式设置程序

clear
clc
load initial_data.mat
Com_size = 32;
S_end = zeros(3,Com_size); S_end(3,:) = 1;

%% 参数初始化
%算法参数
dataBatch = 600;  %一批次送进神经网络训练的数据量
TrainSet = zeros(7,dataBatch);

%经验复用池参数
memo_size = 4000;
%ReMemo = zeros(5,memo_size); %经验复用池格式 一列为一个样本 (px,py),pz,(npx,npz) ?????有必要下一状态吗
MemoPointer = 1; %经验复用池指针，用于标记新数据放到复用池的什么位置

%神经网络相关参数
%网络更新参数  
%更新Q_target的频率高，则经验复用池里，数据更新量和提取量
eval_renew_step_num = 300;             
target_renew_step_num = eval_renew_step_num*3;

%% 经验复用池（记忆库）初始化
% 填满经验复用池，利用之前的训练结果，也可以用观察期替代
[ReMemo,ReMemoReward] = Full_ReMemo(DSM,dur,use_re,total_re,memo_size);

%% 神经网络初始化
% QNet_eval 与环境交互
% QNet_target 学习/训练结果

QNet_eval = fitnet([50,50,50]);
%设置神经网络训练算法 自适应动量梯度下降法
QNet_eval.trainFcn = 'traingdx';
%关闭训练图窗
QNet_eval.trainParam.showWindow = 0;
%网络初始化初始化 
%训练三步 step1 选出数据；step2 计算Q_target; step3 训练     
for k = 1:dataBatch
    num = unidrnd(memo_size);
    TrainSet(1:3,k) = ReMemo(1:3,num);
    px = TrainSet(1,k);
    py = TrainSet(2,k);
    pz = TrainSet(3,k);
    TrainSet(4,k) = ReMemoReward(num);
end
QNet_eval = train(QNet_eval,TrainSet(1:3,:),TrainSet(4,:));
QNet_target = QNet_eval;

%% 动态绘图
DrawBZtime = zeros(1,1);
NNperformance = zeros(1,1);


%% start
TrainEpisode = 100000;
step_node = 0;
for episode = 1:TrainEpisode 
    
    %设置迭代初始状态
    S_init = zeros(3,Com_size); S_init(3,1) = 1; 
    SNext = S_init;
    
    %设置贪心率  ----用于更新经验复用池的数据
    if episode<100      
        epsilon=0.12;
    elseif episode>=100&&episode<500
        epsilon=0.09;
    elseif episode>=500
        epsilon=0.03;
    end
    
    
%0  轨迹内的每一步
    while 1 

        %S更新 step_node更新
        S = SNext;
        step_node = step_node + 1; 
        
%1      %调用函数 贪心策略选择动作a 得到即时奖励r和下一状态s'  同时计算maxQa_NS  和isdone存在关系
        action = getAction(DSM,use_re,total_re,S,epsilon,QNet_eval);
        [SNext,Reward,isdone] = Step(dur,S,action); 
        if isdone ~= 1
            isdone = maxQa_NS(DSM,use_re,total_re,SNext,QNet_target);
        end

%2      记录到经验复用池中 
        ReMemo(1,MemoPointer) = sum(find(S(2,:)))+1;  
        ReMemo(2,MemoPointer) = sum(find(S(3,:)))+1;
        ReMemo(3,MemoPointer) = sum(find(action))+1;
        ReMemo(4,MemoPointer) = sum(find(SNext(2,:)))+1;
        ReMemo(5,MemoPointer) = sum(find(SNext(3,:)))+1;
        ReMemo(6,MemoPointer) = isdone;
        ReMemoReward(MemoPointer) = Reward;
        %复用池指针更新
        MemoPointer = MemoPointer+1;
        if MemoPointer>memo_size
            MemoPointer = 1;
        end
       
%3      一定步数后，从经验复用池采样，计算TD，训练网络。
        %判断是否更新QNet_target
        if rem(step_node,eval_renew_step_num) == 0
            TD = zeros(1,dataBatch);
            TrainSet = zeros(7,dataBatch);
            %从ReMemo中生成数据
            for i =1:dataBatch
                pos = unidrnd(memo_size);
                TrainSet(1:6,i) = ReMemo(:,pos);
                TrainSet(7,i) = ReMemoReward(pos);
            
            %计算TD
                if TrainSet(6,i) == 1
                    TD(i) = TrainSet(7,i);
                else
                    TD(i) = TrainSet(7,i) + TrainSet(6,i);
                end
            end

            %训练网络
            QNet_eval = train(QNet_eval,TrainSet(1:3,:),TD);
            
        end
        
        %判断更新QNet_target
        if rem(step_node,target_renew_step_num) == 0
            QNet_target = QNet_eval;
            
            %动态绘图
            figure(1)
            subplot(1,2,1)
            BZtime = DrawPlot(QNet_target,DSM,dur,use_re,total_re);  
            DrawBZtime = [DrawBZtime,BZtime];
            plot(DrawBZtime)
            drawnow
            
            subplot(1,2,2)
            outputs = QNet_target(TrainSet(1:3,:));
            performance = perform(QNet_target, TD, outputs);
            NNperformance = [NNperformance,performance];
            plot(NNperformance)
            drawnow

            figure(2)
            plotregression(TD,outputs,'Regression')

        end

%4      episode终止判定 更新的S如果是虚尾则结束
        if isequal(SNext,S_end)
            break
        end
        
    end
    
    %% 动态绘图
%     if mod(episode,10) == 0
%         subplot(1,2,1)
%         BZtime = DrawPlot(QNet_target,DSM,dur,use_re,total_re);  
%         DrawBZtime = [DrawBZtime,BZtime];
%         plot(DrawBZtime)
%         drawnow
%         
%         subplot(1,2,2)
%         outputs = QNet_eval(TrainSet(1:3,:));
%         performance = perform(QNet_eval, TD, outputs);
%         NNperformance = [NNperformance,performance];
%         plot(NNperformance)
%         drawnow
%     end
  
    
    
    
    switch episode
        case 1000
            QNet1k = QNet_target;
            save QNet1k.mat QNet1k
        case 5000
            QNet5k = QNet_target;
            save QNet5k.mat QNet5k
        case 10000
            QNet1w = QNet_target;
            save QNet1w.mat QNet1w
        case 50000
            QNet5w = QNet_target;
            save QNet5w.mat QNet5w
        case 100000
            QNet10w = QNet_target;
            save QNet10w.mat QNet10w
    end
    
    
    
    
    
    
    
end


    
    
    
    
    
    
    
    
    
    
    
    
   





