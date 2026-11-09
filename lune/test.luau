--!strict
-- Headless test runner: `lune run test`
--
-- Runs every tests/*.spec.luau as a plain Luau module returning
-- { [testName]: () -> () }. A test passes unless it errors (use assert).
-- Pure modules in src/shared/Core are required directly - no Roblox engine, no
-- Studio, no play mode.

local fs = require("@lune/fs")
local process = require("@lune/process")

local TESTS_DIR = "tests"

local passed, failed = 0, 0

if not fs.isDir(TESTS_DIR) then
	print("No tests/ directory - nothing to run.")
	process.exit(0)
end

for _, fileName in fs.readDir(TESTS_DIR) do
	if not fileName:match("%.spec%.luau$") then
		continue
	end
	local specPath = `{TESTS_DIR}/{fileName}`
	-- Lune's require appends .luau itself and resolves relative to the CWD,
	-- so this must be run from the project root.
	local requirePath = `{TESTS_DIR}/{fileName:gsub("%.luau$", "")}`
	local ok, specOrErr = pcall(require, requirePath)
	if not ok then
		failed += 1
		print(`FAIL {specPath} (could not load): {specOrErr}`)
		continue
	end
	for testName, testFn in specOrErr :: { [string]: () -> () } do
		local testOk, err = pcall(testFn)
		if testOk then
			passed += 1
			print(`PASS {fileName} :: {testName}`)
		else
			failed += 1
			print(`FAIL {fileName} :: {testName}\n     {err}`)
		end
	end
end

print(`\n{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
