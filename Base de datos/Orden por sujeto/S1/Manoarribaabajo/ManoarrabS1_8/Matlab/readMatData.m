% Column 1 (Equipment):1 is WT901BLE67(d0:1c:1b:3a:ee:9d)(d0:1c:1b:3a:ee:9d)   
% Column 2:Chip Time   The interval (in seconds) between each piece of data and the start time, with the start time as the starting point
% Column 3:Acceleration X(g)
% Column 4:Acceleration Y(g)
% Column 5:Acceleration Z(g)
% Column 6:Angular velocity X(°/s)
% Column 7:Angular velocity Y(°/s)
% Column 8:Angular velocity Z(°/s)
% Column 9:ShiftX(mm)
% Column 10:ShiftY(mm)
% Column 11:ShiftZ(mm)
% Column 12:SpeedX(mm/s)
% Column 13:SpeedY(mm/s)
% Column 14:SpeedZ(mm/s)
% Column 15:Angle X(°)
% Column 16:Angle Y(°)
% Column 17:Angle Z(°)
% Column 18:Magnetic field X(ʯt)
% Column 19:Magnetic field Y(ʯt)
% Column 20:Magnetic field Z(ʯt)
% Column 21:Temperature(℃)
% Column 22:Quaternions 0
% Column 23:Quaternions 1
% Column 24:Quaternions 2
% Column 25:Quaternions 3
% 函数调用：a=readMatData;
function d = readMatData(file)

    if nargin<1
        disp('默认数据')
        file='data.mat';
    else
        disp(file);
    end

    disp('加载mat文件')
    load('data.mat')
    S=whos;
    len = length(S)-1;
    dend = eval(S(len).name);
    d1 = eval(S(1).name);
    len_m = length(d1);
    len_n = length(d1(1,:));

    d=zeros(len_m*(len-1)+length(dend),len_n);
    %h=waitbar(0,'数据合并中……');
    for i=1:len-1
        dTemp = eval(S(i).name);
        d(len_m*(i-1)+1:len_m*i,:)=[dTemp];
        m=len-1;
        %p=fix(i/(m)*len_m)/100; %这样做是可以让进度条的%位数为2位
        %str=['正在合并，目前进度为 ',num2str(p),' %，完成 ',num2str(i),'/',num2str(m)];%进度条上显示的内容
        %waitbar(i/m,h,str);
    end
    d(len_m*(len-1)+1:len_m*(len-1)+length(dend),:)=dend;

end