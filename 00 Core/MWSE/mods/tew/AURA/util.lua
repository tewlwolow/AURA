local util = {}

function util.metadataMissing()
	tes3.messageBox{
		message = "AURA.toml file is missing. Please install."
	}
end

return util