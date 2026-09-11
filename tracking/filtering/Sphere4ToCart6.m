function cart = Sphere4ToCart6(sphere4)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : Sphere4ToCart6.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Convert [range, azimuth, elevation, doppler] to cart6
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

R = sphere4(1);
Azimuth = sphere4(2);
Elevation = sphere4(3);
Velocity = sphere4(4);

X = R * cos(Elevation) * sin(Azimuth);
Y = R * cos(Elevation) * cos(Azimuth);
Z = R * sin(Elevation);
Vx = Velocity * cos(Elevation) * sin(Azimuth);
Vy = Velocity * cos(Elevation) * cos(Azimuth);
Vz = Velocity * sin(Elevation);

cart = [X; Y; Z; Vx; Vy; Vz];

end
