function [sphere4, H] = Cart6ToSphere4AndJacobian(cart)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : Cart6ToSphere4AndJacobian.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Convert cart6 to radar spherical measurement
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

x = cart(1); y = cart(2); z = cart(3);
Vx = cart(4); Vy = cart(5); Vz = cart(6);

xy2 = max(x^2 + y^2, eps);
xy = sqrt(xy2);
r2 = max(x^2 + y^2 + z^2, eps);
r = sqrt(r2);
dotPV = x*Vx + y*Vy + z*Vz;

rangeVal = r;
azimuthVal = atan2(x, y);
elevationVal = atan2(z, xy);
velocityVal = dotPV / r;
sphere4 = [rangeVal; azimuthVal; elevationVal; velocityVal];

H = zeros(4, 6);
H(1,1) = x / r;
H(1,2) = y / r;
H(1,3) = z / r;

H(2,1) = y / xy2;
H(2,2) = -x / xy2;

H(3,1) = -x * z / (r2 * xy);
H(3,2) = -y * z / (r2 * xy);
H(3,3) = xy / r2;

H(4,1) = Vx / r - dotPV * x / r^3;
H(4,2) = Vy / r - dotPV * y / r^3;
H(4,3) = Vz / r - dotPV * z / r^3;
H(4,4) = x / r;
H(4,5) = y / r;
H(4,6) = z / r;

end
