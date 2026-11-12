--!strict
-- Haymaker Tussle - server entry point.
-- Boots Knit (Services). Keep this file to the boot only; logic lives in Services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(script.Services)

Knit.Start()
	:andThen(function()
		-- BUILD STAMP. If this exact line is not in Output on Play, Studio is NOT
		-- running the code on disk. Check the Rojo plugin is actually CONNECTED
		-- and syncing before debugging anything else - an established connection
		-- is not the same as an accepted one.
		print("[Haymaker Tussle] Server started - BUILD ground-1")
	end)
	:catch(warn)
