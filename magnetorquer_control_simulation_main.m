%% *********************************************************************** 
%  Magnetorquer Control Model
%  Space Systems Research Laboaratory
%  --------------------------------
%  Nicholas Mercadante
%
%  Project: Rascal-1
%
%
% Name          | Date      | Description
% ------------------------------------------------------------------------
% N.Mercadante   02-26-2017  This script will develop the control
%                            simulation for the Rascal-1 magnetorquer
%                            payload.
%
%                            Note that there are three refrence frames used
%                            in this simulation. There is the intertial
%                            reference frame, which is an earth-fixed
%                            frame. This frame will be used for the
%                            environmental torques. There is the space
%                            reference frame, wich is fixed on the orbit
%                            path, and then the body-fixed frame.
% ------------------------------------------------------------------------
%
% COPYRIGHT 2017 Space Systems Research Laboratory, all rights reserved.
%
% ************************************************************************

clear; clc; close all;
set(0,'units','pixels');
screen_size = get(0,'screensize');

print_intro_to_term('Magnetorquer Control Simulation');

d2r = pi/180;
r2d = 180/pi;
%% Parameters

mass = 10;              % kg

% SPACECRAFT Dimensions -- on Body Axis system
x_dimension = 0.100;    % m
y_dimension = 0.100;    % m
z_dimension = 0.681;    % m

% Inertia Tensor -- on BODY Axis system
I_B = inertiaTensor(mass, x_dimension, y_dimension, z_dimension);

% Orbit Period
orbitPeriod = 60*1;    % sec
dt = 0.001;             % sec
t = 0 : dt : orbitPeriod;

% Matrix initialization:

H_B = zeros(3, numel(t));     % Angular Momentum (body-coords)
w_B = zeros(3, numel(t));     % Body-Fixed rotation rates
T_B = zeros(3, numel(t));     % Torque (body-fixed)
B_I = zeros(3, numel(t));    
B_B = zeros(3, numel(t));

Euler     = zeros(3, numel(t)); % Euler-Angles (inertial-fixed)
q_BtoI    = zeros(4, numel(t));
qdot_BtoI = zeros(4, numel(t));

% For debugging - euler axis and rotations
axis_angle = zeros(1, numel(t));
euler_axis = zeros(1, numel(t));

% Initial Values:
w_B(:, 1) = [0.01; 0.01; 0.01];    % rad/s
H_B(:, 1) = I_B * w_B(:,1); 

q_BtoI(:, 1) = dc2q( [ 0 0 -1 ;    % In initial position.
                      -1 0  0 ;
                       0 1  0 ]); 

%% Environmental Effects:

% Earth's magnetic field (IGRF Model) - SPACE FRAME
c = 0.0;
B_I(1, :) = 0.05 * c.*t; %sin(c.*t);
B_I(2, :) = 0.05 * c.*t; %cos(c.*t);
B_I(3, :) = 0.05 * c.*t; %sin(c.*t).^2;

% Initialize the body-fixed B to the space-fized B.
B_B(:, 1) = B_I(:, 1);

% Control torque - BODY FRAME
a = 0;
mu_B = zeros(3, numel(t));
mux = a*0.1;   mu_B(1,:) = pulse(dt, 15, 1, mux, mu_B(1,:));
muy = a*0.1;   mu_B(2,:) = pulse(dt, 25, 1, muy, mu_B(2,:));
muz = a*0.1;   mu_B(3,:) = pulse(dt, 30, 1, muz, mu_B(3,:));

h = waitbar(0,'Initializing waitbar...');
%% Simulation
% matlabpool open 4
for i = 2:numel(t)
    % Shift the B vector from Inertial to Body reference
    B_B(:, i) = qRotate(q_BtoI(:, i-1), B_I(:, i));
    
    % Calculate Control Torque in body-frame
    T_B(:, i) = magneticTorque(B_B(:, i), mu_B(:, i));
    
    % Calculate the body rate changes
    H_B(:, i) = H_B(:, i-1) + T_B(:, i) .* dt;
    w_B(:, i) = I_B \ H_B(:, i);
    
    % Quaternion Math
    S = quatSkew(w_B(:, i));
    qdot_BtoI(:, i) = 0.5 .* S * q_BtoI(:, i-1);
    
    % Numerically Integrate and Normalize
    q_BtoI(:, i) = normalize(  q_BtoI(:, i-1) + qdot_BtoI(:, i)*dt  );
        
    Euler(:, i) = quat2Euler(q_BtoI(:, i));
    
    % Display to screen: Adds 0.8% to the sim time. That's ~5 seconds on a
    %                    10 minute simulation.
    if mod(i, 1000) == 0
        waitbar( i/numel(t) , h,  'Percent Complete:'); 
    end
    
    % For debugging. Euler axis and rotations.
    axis_angle(i)    = 2*acos(q_BtoI(4, i));
    euler_axis(1, i) = q_BtoI(1, i)/sin(axis_angle(i)/2);
    euler_axis(2, i) = q_BtoI(2, i)/sin(axis_angle(i)/2);
    euler_axis(3, i) = q_BtoI(3, i)/sin(axis_angle(i)/2);
    
end

%% Display Results

% Body Rates vs. Torque
% figure('position',[screen_size(3)/4, screen_size(4)/4, 1000, 500])
%     subplot(2, 1, 1)
%         plot(t, w_B(1,:).*r2d, t, w_B(2,:).*r2d, t, w_B(3,:).*r2d), grid on,
%         legend({'\omega_{x}', '\omega_{y}', '\omega_{z}'}),
%         title('Body-Rates'), xlabel('Seconds'), ylabel('degrees/sec');
%     subplot(2,1,2)
%         plot(t, T_B(1,:), t, T_B(2,:), t, T_B(3,:)), grid on,
%         legend({'x', 'y', 'z'}), %axis([0 orbitPeriod -0.01 0.01]),
%         title('Torques');
    
% Euler Angles vs. Torque
% figure('position',[screen_size(3)/4, screen_size(4)/4, 1000, 500])
%     subplot(2,1,1)
%         plot(t, Euler(1,:).*r2d, t, Euler(2,:).*r2d, t, Euler(3,:).*r2d), grid on,
%         legend({'\Phi (Roll)', '\Theta (Pitch)', '\Psi (Yaw)'}),
%         title('Euler Angels'), xlabel('Seconds'), ylabel('degrees');    
%     subplot(2,1,2)
%         plot(t, T_B(1,:), t, T_B(2,:), t, T_B(3,:)), grid on,
%         legend({'x', 'y', 'z'}), %axis([0 orbitPeriod -0.01 0.01]),
%         title('Torques');

% Quaternion Components        
figure('position',[screen_size(3)/4, screen_size(4)/4, 1000, 500])
    subplot(2,1,1)
        plot(t, euler_axis(1,:), t, euler_axis(2,:), t, euler_axis(3,:)), grid on,
        legend({'e_x', 'e_y', 'e_z'}),
        title('Euler Axis'), xlabel('Seconds');    
    subplot(2,1,2)
        plot(t, axis_angle.*r2d), grid on,
        xlabel('Seconds'), ylabel('Degrees'), %axis([0 orbitPeriod -180 180]),
        title('Euler Axis Rotation');

% Body Rates
figure('position',[screen_size(3)/4, screen_size(4)/4, 1000, 500])
    subplot(3, 1, 1)
        plot(t, w_B(1, :).*r2d), title('Body - X rotation'), grid on,
        xlabel('Orbits'), ylabel('Degree/s'),
        %axis([0 orbitPeriod -180 180]);
    subplot(3, 1, 2)
        plot(t, w_B(2, :).*r2d), title('Body - Y rotation'), grid on,
        xlabel('Orbits'), ylabel('Degree/s'),
        %axis([0 orbitPeriod -180 180]);
    subplot(3, 1, 3)
        plot(t, w_B(3, :).*r2d), title('Body - Z rotation'), grid on,
        xlabel('Orbits'), ylabel('Degree/s'),
        %axis([0 orbitPeriod -180 180]);
 
% Euler Angles
figure('position',[screen_size(3)/4, screen_size(4)/4, 1000, 500])
    subplot(3, 1, 1)
        plot(t, Euler(1, :).*r2d), title('\Phi (Roll)'), grid on,
        xlabel('Orbits'), ylabel('Degrees'),
        %axis([0 orbitPeriod -180 180]);
    subplot(3, 1, 2)
        plot(t, Euler(2, :).*r2d), title('\Theta (Pitch)'), grid on,
        xlabel('Orbits'), ylabel('Degrees'),
        %axis([0 orbitPeriod -180 180]);
    subplot(3, 1, 3)
        plot(t, Euler(3, :).*r2d), title('\Psi (Yaw)'), grid on,
        xlabel('Orbits'), ylabel('Degrees'),
        %axis([0 orbitPeriod -180 180]);    
    
 % Torques
 figure('position',[screen_size(3)/4, screen_size(4)/4, 1000, 500])
    subplot(3, 1, 1)
        plot(t, T_B(1, :)), title('Body x Torque'), grid on,
        xlabel('Orbits'), ylabel('Newton-Meters'),
        %axis([0 orbitPeriod -180 180]);
    subplot(3, 1, 2)
        plot(t, T_B(2, :)), title('Body y Torque'), grid on,
        xlabel('Orbits'), ylabel('Newton-Meters'),
        %axis([0 orbitPeriod -180 180]);
    subplot(3, 1, 3)
        plot(t, T_B(3, :)), title('Body z Torque'), grid on,
        xlabel('Orbits'), ylabel('Newton-Meters'),
        %axis([0 orbitPeriod -180 180]);  
    


