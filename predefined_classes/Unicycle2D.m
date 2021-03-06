classdef Unicycle2D

        properties(Access = public)
           id = 1;
           X = [0;0];
           yaw = 0;
           
           G = [0;0]; %goal  
           status = 'nominal';  % nominal or adversary
           
           % Dynamcs matrices for x_dot = f(x) + g(x)u
           f;
           g;
           
           safe_dist = 0;          
           D = 2;
           
           % figure ploit handles
           p1;         % plot current location
           p2;         % plot safe distance for leader
           p3; % only for leader
           p4;         % plot whole trajectory
           Xt = [];
           
           
        end
        
        properties(Access = private)
            iter = 0;
        end
        
        methods(Access = public)
           
            function quad = Unicycle2D(ID,x,y,yaw,r_safe,D,status)
               
                quad.X(1) = x;
                quad.X(2) = y;
                quad.yaw = yaw;
                quad.safe_dist = r_safe;
                quad.id=ID;                
                quad.D = D;
                quad.status = status;                
                quad = plot_update(quad); 
                
                % Dynamics
                quad.f = [0;
                         0;
                         0];
                quad.g = [cos(yaw) 0;
                         sin(yaw) 0;
                         0 1];
            end
            
            function d = plot_update(d)
                        
                center = [d.X(1) d.X(2)];
                radius = d.safe_dist;
                
                d.Xt = [d.Xt;center ];
                
                if strcmp('nominal',d.status)
                    color = 'g';
                else
                    color = 'b';
                end
                
                if (d.iter<1)
                    
                   figure(1)
                   if (d.id>0) % Follower
                       d.p1 = scatter(d.X(1),d.X(2),50,color,'filled');  
                       % Display the safe distance circle.
                       %d.p2 = viscircles(center,radius,'Color',color,'LineStyle','--');
                       d.p4 = plot( d.Xt(:,1),d.Xt(:,2) );
                       d.iter = 1;
                   else        % Leader
                       d.p1 = scatter(d.X(1),d.X(2),50,'r','filled');  
                       % Display the safe distance circle.
                       d.p2 = viscircles(center,radius,'Color','r','LineStyle','--');
                       d.p3 = viscircles(center,d.D,'Color','r','LineStyle','--');
                       d.iter = 1;
                   end
                   
                else
                    
                    set(d.p1,'XData',d.X(1),'YData',d.X(2));
                    set(d.p4,'XData',d.Xt(:,1),'YData',d.Xt(:,2));
                    delete(d.p2);
                    delete(d.p3);
                    
                    if (d.id>0) % Follower
                        %d.p2 = viscircles(center,radius,'Color',color,'LineStyle','--');                 
                    else        % Leader
                        %d.p2 = viscircles(center,radius,'Color','r','LineStyle','--'); 
                        d.p3 = viscircles(center,d.D,'Color','r','LineStyle','--');
                    end
           
                end
                      
            end
            
            
            function d = control_state(d,U,dt)
                
                % Euler update with Dynamics
                
                d.X = d.X + [ U(1)*cos(d.yaw);U(1)*sin(d.yaw) ]*dt;
                d.yaw = d.yaw + U(2)*dt;
                d.yaw = wrap_pi(d.yaw);
                
                d.g =[cos(d.yaw) 0;
                     sin(d.yaw) 0;
                     0 1];
                
                d = plot_update(d);
            
            end
            
            function [h, dh_dxi, dh_dxj] = agent_barrier(d,agent)
                
                global d_min
                %barrier
                h = d_min^2 - norm(d.X-agent.X)^2;
                dh_dxi = [-2*(d.X-agent.X)' 0];    % 0 because robot state is x,y,theta
                dh_dxj = [2*(d.X-agent.X)' 0];                
                
            end
            
            function [V, dV_dx] = goal_lyapunov(d)
               
                % Lyapunov
                V = norm(d.X-d.G)^2;
                dV_dx = [2*(d.X-d.G)' 0];  % 0 because robot state is x,y,theta
                
            end
            
            function [h, dh_dx] = obstacle_barrier(d,Obs)
                             
                % Simple barrier function: DOES NOT work for Unicycle
%                     h = (Obstacle(j).length)^2 - norm(robot(i).X-Obstacle(j).X)^2;
%                     dh_dxi = [-2*(robot(i).X-Obstacle(j).X)' 0];

                    % this is a very unique barrier function for Unicycle only                    
                    x1 = d.X(1); x2 = d.X(2); yaw = d.yaw; rho = Obs.length;
                    Ox1 = Obs.X(1); Ox2 = Obs.X(2);
                    
                    % Joseph's barrier function for Unicycle
                    sigma = 1.0;
                    h = rho - sqrt( norm([x1;x2]-[Ox1;Ox2] )^2 - wrap_pi( yaw - sigma*atan2(x2-Ox2,x1-Ox1) )^2   );
%                     dh_dx = [  ( -2*(x1-Ox1) + sigma*(x2-Ox2)/( (x1-Ox1)^2 + (x2-Ox2)^2 ) )/2/(rho-h)  ( -2*(x2-Ox2) - sigma*(x1-Ox1)/( (x1-Ox1)^2 + (x2-Ox2)^2 ) )/2/(rho-h) ( 1/(rho-h) )    ];
                    dh_dx = [ (-(x1-Ox1) + wrap_pi(yaw-sigma*atan2(x2-Ox2,x1-Ox1))*sigma*(x2-Ox2)/((x1-Ox1)^2+(x2-Ox2)^2)  )/(rho-h)  ( -(x2-Ox2) - wrap_pi( yaw - sigma*atan2( x2-Ox2,x1-Ox1 ) )*sigma*(x1-Ox1)/((x1-Ox1)^2+(x2-Ox2)^2)  )/(rho-h) wrap_pi(yaw-sigma*atan2((x2-Ox2),(x1-Ox1)))/(rho-h)];           
            end
            
            
            
            
            function uni_input = nominal_controller(d,u_min,u_max)
                
                dx = d.X - d.G;
                kw = 0.5*u_max(2)/pi;
                phi_des = atan2( -dx(2),-dx(1) );
                delta_phi = wrap_pi( phi_des - d.yaw );

                w0 = kw*delta_phi;
                kv = 1.0;%0.1;
                v0 = kv*norm(dx)*max(0.1,cos(delta_phi)^2);                

                uni_input = [v0;w0];      
                
            end
            
            
            
        end



end