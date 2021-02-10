local TweenService = game:GetService('TweenService');
local RunService = game:GetService('RunService');

local Glider = script.Parent;
local Players = game.Players;
local bodyV = Glider.PrimaryPart:WaitForChild('BodyVelocity');
local animation = script.Animation;

local AnimationTrack;
local jumpConnection;
local lowerTorsoOffset;
local mainTween;
local flyingUp;
local flyingDown;

local vVelo = Vector3.new(0, 0, 0);
local mathrad, mathabs, vect, cfa, cfn = math.rad, math.abs, Vector3.new, CFrame.Angles, CFrame.new;

local readyToFly, equipped, flying, sprinting, turning = false, false, false, false, false;
local decelerationEffect, stalling = false, false;
local turningLeft, turningRight = false, false;

local flightSpeed, sprintSpeed = 20, 60;
local tiltValue, xTiltValue, turnValue = 0, 0, 0;
local dropSpeed = 0;

local MainGlider = Glider.Parts:WaitForChild('MainGlider');
local Trails = {};

for _,v in pairs(MainGlider:GetChildren()) do
	if v:IsA('Trail') then
		table.insert(Trails, v);
	end
end

local Events = script.Parent:WaitForChild("Events")
local Event = Events:WaitForChild("RemoteEvent");
local Tilt = Events:WaitForChild('TiltEvent');
local Camera = Events:WaitForChild('Camera');
local Sprint = Events:WaitForChild('Sprint');
local XTilt = Events:WaitForChild('XTilt');
local tween = Events:WaitForChild('tween');

local diveSound = Events:WaitForChild('Wind Howl');
local flightSound = Events:WaitForChild('Wind Loop');

Glider.AncestryChanged:Connect(function(attr)
	local player = Players:GetPlayerFromCharacter(attr);
	if player then
		equipped = true;
		weldToBack(player);
		loadEvents();
	else
		equipped = false;
	end
end)

function loadEvents()
	Event.OnServerEvent:Connect(function(player)
		if equipped then
			if not readyToFly then
				lowerTorsoOffset = player.Character.LowerTorso.Root.C0.Y;
				ActivateFlight(player);
			else
				UnactivateFlight(player);
			end
		end
	end)
	
	Tilt.OnServerEvent:Connect(function(player, mode, pressed)
		if flying then
			if pressed then
				if mode == 'left' then
					coroutine.wrap(tiltLeft)(player);
				else
					coroutine.wrap(tiltRight)(player);
				end
			else
				if mode == 'left' then
					turningLeft = false;
				else
					turningRight = false;
				end
			end
		end
	end)
	
	XTilt.OnServerEvent:Connect(function(player, cameraCFrame)
		if flying then
			local cameraDirection = cameraCFrame.LookVector;
			local lookVect = Glider.PrimaryPart.CFrame.UpVector;
			local y = ((lookVect.Y) * flightSpeed);
			
			vVelo = vect(
				lookVect.X * flightSpeed, 
				y, 
				lookVect.Z * flightSpeed
			);
						
			bodyV.Velocity = vVelo;
			xTiltValue = cameraDirection.y * 1.4;	
			
			if xTiltValue < -.5 and flyingDown and flightSpeed < 30 then
				flightSpeed = 30;
				bodyV.MaxForce = vect(math.huge, math.huge, math.huge);
			end
			
			if (sprinting) then
				bodyV.MaxForce = vect(math.huge, math.huge, math.huge);
			end
			
			if xTiltValue <= -1.37  then -- NoseDive
				flyingUp = false;
				flyingDown = false;
				
				if not sprinting then
					accelerate(player);
					diveSound:Play();
					TweenService:Create(diveSound, TweenInfo.new(.1), {Volume = 0.1}):Play();
				end
			elseif xTiltValue < 0 then -- Tilting Down
				flyingUp = false;
				if not flyingDown then
					decelerate(player);
					flyingDown = true;

					coroutine.wrap(function()
						repeat
							flightSpeed = (flightSpeed + mathabs(xTiltValue) * .09);
							RunService.Heartbeat:Wait();
						until flyingDown == false or flightSpeed >= 80;
					end)();
				end
			elseif xTiltValue >=  0 then -- Tilting Up
				flyingDown = false;
				if not flyingUp then
					decelerate(player);
					flyingUp = true;
					coroutine.wrap(function()
						repeat
							flightSpeed = flightSpeed - (xTiltValue * .3);
							RunService.Heartbeat:Wait();
						until flyingUp == false or flightSpeed <= 0;
						
						bodyV.MaxForce = vect(math.huge, 2500, math.huge);
					end)();
				end
			end
			
			applyAngleChange();
		end
	end)
	
end

function tiltLeft(player)
	turningLeft = true;
	turningRight = false;
	local waft = 25;
	
	while turningLeft do
		RunService.Heartbeat:Wait();
		tiltValue = tiltValue + 5;
		applyAngleChange();
	end
	if (not turningRight) and (not turningLeft) then
		resetTilt();
	end
end

function tiltRight(player)
	turningRight = true;
	turningLeft = false;
	local waft = -25;

	while turningRight do
		tiltValue = tiltValue - 5;
		RunService.Heartbeat:Wait();
		applyAngleChange();
		
	end
	
	if (not turningRight) and (not turningLeft) then
		resetTilt();
	end
end

function ActivateFlight(player)
	readyToFly = true;
	weldToHand(player);
	startActivationEvents(player);
end

function UnactivateFlight(player)
	readyToFly = false;
	Unfly(player);
	weldToBack(player);
	jumpConnection:Disconnect();
end

function weldToBack(player)
	local char = player.Character;
	if char then
		removeWelds(char);		
		local c1 = cfn(0, 0, -0.7);
		weld(char.UpperTorso, Glider.PrimaryPart, c1)
	end
end

function weldToHand(player)
	local char = player.Character;
	if char then
		removeWelds(char);
		local c1 = cfn(0, 0, 0) * 
			cfa(mathrad(-90), mathrad(180), 0)
		
		weld(char.LeftHand, Glider.PrimaryPart, c1)
	end
end

function weld(part0, part1, c1)
	local weld = Instance.new('Weld', part0);
	weld.Name = 'GliderWeld'
	weld.Part1 = part1;
	weld.Part0 = part0;
	weld.C1 = c1
end

function startActivationEvents(player)
	local char = player.Character;
	local HRP = player.Character.HumanoidRootPart;
	local humanoid = char.Humanoid;
	local tab = char:GetChildren();

	if humanoid then
		local landed = false;
		
		jumpConnection = RunService.Heartbeat:Connect(function()			
			if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
				if not flying then
					local ray = Ray.new(HRP.Position, HRP.CFrame.UpVector * -200);
					local hit, position = game.Workspace:FindPartOnRayWithIgnoreList(ray, tab);
					if (HRP.Position - position).Magnitude > 30 then
						Fly(player);
						weldToBack(player);
					end
				end
			else
				landed = true;
				weldToHand(player);
				Unfly(player);
			end
		end)
	end

end

function Fly(player)
	flying = true
	
	flightSound:Play();
	TweenService:Create(flightSound, TweenInfo.new(3), {Volume = .005}):Play();

	local humanoid = player.Character.Humanoid;
	
	createFlight();
	
	Camera:FireClient(player, Glider.PrimaryPart);
	
	AnimationTrack = humanoid:LoadAnimation(animation);
	AnimationTrack:Play();
end

function Unfly(player)
	local lowerTorso = player.Character.LowerTorso.Root;
	decelerate(player);

	xTiltValue = 0;
	tiltValue = 0;
	turnValue = 0;
	flightSpeed = 20;
	vVelo = vect(0, 0, 0);
	turningLeft = false;
	turningRight = false;
	
	TweenService:Create(flightSound, TweenInfo.new(1), {Volume = 0}):Play();
	
	applyAngleChange();
	
	bodyV.MaxForce = vect(0, 0, 0);
	
	flying = false;
	if AnimationTrack then AnimationTrack:Stop() end
	diveSound:Stop();
	
	Camera:FireClient(player, false);
end

function applyAngleChange()
	local char = Glider.Parent;
	if mainTween then mainTween:Cancel() end
	if char then
		if char.LowerTorso then
			local lowerTorso = char.LowerTorso:FindFirstChild('Root');
			if lowerTorso then

				local cf = cfn(0, lowerTorsoOffset, 0) *
					cfa(xTiltValue, 0, math.rad(tiltValue))

				mainTween = TweenService:Create(lowerTorso, TweenInfo.new(.8), { C0 = cf })
				mainTween:Play();
			end
		end
	end
end

function resetTilt()
	tiltValue = 0;
	applyAngleChange()
end

function accelerate(player)
	sprinting = true
	accelerationEffect(player)
end

function decelerationEffect()
	coroutine.wrap(function()
		sprinting = false
		repeat
			RunService.Heartbeat:Wait();
			flightSpeed = flightSpeed - .1;
		until flightSpeed <= 20 or sprinting or (not flying);
	end)()
end

function accelerationEffect(player)
	coroutine.wrap(function()
		repeat
			RunService.Heartbeat:Wait();
			flightSpeed = flightSpeed + .4;
			
			if flightSpeed >= 50  then
				Sprint:FireClient(player, true);
				for _,v in pairs(Trails) do
					v.Enabled = true;
				end
			end
		until flightSpeed >= 100 or (not sprinting) or (not flying);
	end)()
end

function decelerate(player)
	if sprinting then decelerationEffect() end
	Sprint:FireClient(player, false);
	TweenService:Create(diveSound, TweenInfo.new(3), {Volume = 0}):Play();
	removeTrails();
end

function removeWelds(char)
	if char.UpperTorso:FindFirstChild('GliderWeld') then 
		char.UpperTorso.GliderWeld:Destroy() 
	end
	if char.LeftHand:FindFirstChild('GliderWeld') then 
		char.LeftHand.GliderWeld:Destroy() 
	end
end

function removeTrails()
	for _,v in pairs(Trails) do
		v.Enabled = false;
	end
end

function createFlight()
	bodyV.MaxForce = vect(math.huge, math.huge, math.huge);
	applyAngleChange();
end