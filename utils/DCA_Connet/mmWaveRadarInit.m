function mmWaveRadarInit()
%% 本文件用于MATLAB发送指令给mmwave studio配置雷达参数
 
% Initialize mmWaveStudio .NET connection
RSTD_DLL_Path = 'C:\ti\mmwave_studio_02_01_01_00\mmWaveStudio\Clients\RtttNetClientController\RtttNetClientAPI.dll';% fixed path
ErrStatus = Init_RSTD_Connection(RSTD_DLL_Path);
if (ErrStatus ~= 30000)
    disp('Error inside Init_RSTD_Connection');
    return;
end

strFilename = 'C:\\ti\\mmwave_studio_02_01_01_00\\mmWaveStudio\\Scripts\\DCAconnect.lua';
% remark：pls send DCAconnect.lua into mmWaveStudio path
% warnning: do not include chinese path

Lua_String = sprintf('dofile("%s")',strFilename);
%genearte lua cmd :
%"dofile("C:\\ti\\mmwave_studio_02_01_01_00\\mmWaveStudio\\Scripts\\DCAconnect.lua")"

ErrStatus = RtttNetClientAPI.RtttNetClient.SendCommand(Lua_String);
end
