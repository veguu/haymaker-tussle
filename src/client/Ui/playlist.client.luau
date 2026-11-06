local playlist = game:GetService("SoundService").Music

while true do
	-- selene: allow(unused_variable)
	for i, v in pairs(playlist:GetChildren()) do
		print(12)
		v:Play()
		v.Ended:Wait()
	end
end