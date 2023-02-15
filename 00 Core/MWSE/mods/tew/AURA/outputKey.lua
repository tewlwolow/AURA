local config = require("tew.AURA.config")
local moduleData = require("tew.AURA.moduleData")
local messages = require(config.language).messages

event.register("keyDown", function(e)
    if e.isShiftDown then
		local output = ""
		for module, data in pairs(moduleData) do
			local old, new = messages.none, messages.none
			if data.old then
				old = data.old.id or old
			end
			if data.new then
				new = data.new.id or new
			end

			output = output .. string.format("AURA %s module\n%s: %s\n%s: %s\n\n", module, messages.oldTrack, old, messages.newTrack, new)

		end
		tes3.messageBox{
			message = string.sub(output, 1, -3)
		}
	end
end, {filter = config.outputKey.keyCode})