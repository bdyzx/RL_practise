clear
clc
filename = 'j30_10_1.xlsx';%#
A = xlsread(filename);
DSM = zeros(32,32);%#
for i=1:32%#
    for j=1:A(i,3)
        DSM(A(i,j+3),i)=1;
    end
end

total_re = A(1,15:18);%#

use_re = A(:,10:13);%#

dur = A(:,9);%#

save initial_data.mat DSM total_re use_re dur



