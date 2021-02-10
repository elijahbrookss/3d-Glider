local UIS = game:GetService("UserInputService");
local Events = script.Parent:WaitForChild("Events")
local Event = Events:WaitForChild("RemoteEvent");
local Tilt = Events:WaitForChild('TiltEvent');
local Camera = Events:WaitForChild('Camera');
local Sprint = Events:WaitForChild('Sprint');
local XTilt = Events:WaitForChild('XTilt');
local tween = Events:WaitForChild('tween');

local Glider = script.Parent;
local flying = false;

local currentCamera = workspace.CurrentCamera;
local localPlayer = game.Players.LocalPlayer;
local mouse = localPlayer:GetMouse();

local defaultMouseIcon = 'rbxassetid://5562969039';
local flyingMouseIcon = 'rbxassetid://914159181';
mouse.Icon = defaultMouseIcon;

local tweenDebounce = nil;

local char = localPlayer.Character or localPlayer.CharacterAdded:wait();

local TS = game:GetService('TweenService');
local RS = game:GetService('RunService');

local sprinting = false;

UIS.InputBegan:Connect(function(key, gpe)
	if gpe then
		if key.KeyCode == Enum.KeyCode.LeftShift then
			Sprint:FireServer(true);
		end
		return
	end
	if key.KeyCode == Enum.KeyCode.E then
		Event:FireServer();
	elseif key.KeyCode == Enum.KeyCode.A then
		Tilt:FireServer('left', true);
	elseif key.KeyCode == Enum.KeyCode.D then
		Tilt:FireServer('right', true);
	end
end)

UIS.InputEnded:Connect(function(key, gpe)
	if gpe then return end

	if key.KeyCode == Enum.KeyCode.A then
		Tilt:FireServer('left', false);
	elseif key.KeyCode == Enum.KeyCode.D then
		Tilt:FireServer('right', false);
	elseif key.KeyCode == Enum.KeyCode.LeftShift then
		Sprint:FireServer(false);
	end
end)

Camera.OnClientEvent:Connect(function(object)
	local GameSettings = UserSettings():GetService("UserGameSettings")

	if object then
		flying = true

		coroutine.wrap(function()
			while flying do
				RS.RenderStepped:Wait();
				GameSettings.RotationType = Enum.RotationType.CameraRelative;
				UIS.MouseBehavior = Enum.MouseBehavior.LockCenter;
				mouse.Icon = flyingMouseIcon;
			end
		end)()

		TS:Create(currentCamera, TweenInfo.new(.5), { FieldOfView = 80 }):Play();
	else
		flying = false;
		GameSettings.RotationType = Enum.RotationType.MovementRelative
		UIS.MouseBehavior = Enum.MouseBehavior.Default;
		mouse.Icon = defaultMouseIcon;

		TS:Create(currentCamera, TweenInfo.new(.5), { FieldOfView = 70 }):Play();
	end
end)

Sprint.OnClientEvent:Connect(function(mode)
	if mode then
		sprinting = true;
		TS:Create(currentCamera, TweenInfo.new(3), { FieldOfView = 100 }):Play();
		coroutine.wrap(function()
			local char = localPlayer.Character;
			while sprinting and char do
				local humanoid = char.Humanoid;
				local frequency = 2
				local x, y, z = math.random(frequency), math.random(frequency), math.random(frequency);
				local camOffset =  (
					Vector3.new(x, y, z) * .07
				);
				humanoid.CameraOffset = camOffset;
				wait(.03);
			end
		end)()
	else
		sprinting = false;
		TS:Create(currentCamera, TweenInfo.new(.5), { FieldOfView = 80 }):Play();
	end
end)

currentCamera.Changed:Connect(function(change)

	if change == 'CFrame' then
		XTilt:FireServer(currentCamera.CFrame);
	end
end)

tween.OnClientEvent:Connect(function(props)
	if tweenDebounce then tweenDebounce:Cancel() end
	tweenDebounce = TS:Create(props.Object, TweenInfo.new(props.Info), props.Properties)
	tweenDebounce:Play();
end)
