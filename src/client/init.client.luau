--!strict
-- Haymaker Tussle - client entry point.
-- Boots Knit (Controllers). Keep this file to the boot only; logic lives in Controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddControllers(script.Controllers)

Knit.Start()
	:andThen(function()
		-- BUILD STAMP - see the note in the server boot.
		print("[Haymaker Tussle] Client started - BUILD kits-1b")
	end)
	:catch(warn)
