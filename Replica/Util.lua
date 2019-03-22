local Util = {}

function Util.Copy(tab)
	local newTab = {}
	
	for k, v in pairs(tab) do
		newTab[k] = v
	end
	
	return newTab
end

function Util.DeepCopy(tab)
	local newTab = {}
	
	for k, v in pairs(tab) do
		if type(v) == "table" then
			newTab[k] = Util.DeepCopy(v)
		else
			newTab[k] = v
		end
	end
	
	return newTab
end

function Util.DeepCompare(val1, val2)
	if type(val1) == "table" and type(val2) == "table" then
		for k, v in pairs(val1) do
			if not Util.DeepCompare(v, val2[k]) then
				return false
			end
		end
		
		return true
	else
		return val1 == val2
	end
end

function Util.OverrideDefaults(defaults, tab)
	local newTab = Util.DeepCopy(defaults)
	
	for k, v in pairs(tab) do
		local existing = defaults[k]
		if existing and type(v) == "table" and type(existing) == "table" then
			newTab[k] = Util.OverrideDefaults(existing, v)
		else
			newTab[k] = v
		end
	end
	
	return newTab
end

-- Serialized values should be in the form {key, type, symbolic_value, [preservation_id]}
-- Most standard roblox data types are supported, so long as they are reversible
-- i.e. parameters in the constructor can be inferred from the object's public properties
function Util.Serialize(key, object)
	local serialType
	local symbolicValue
	
	local rbxType = typeof(object)
	if rbxType == "number" or rbxType == "string" or rbxType == "boolean" or rbxType == "nil" or rbxType == "EnumItem" then
		serialType = "Raw"
		symbolicValue = object
	elseif rbxType == "table" then
		serialType = "Table"
		symbolicValue = {}
		if #object == 0 then
			for k, v in pairs(object) do
				if type(k) ~= "string" then
					error("Serialized nonsequential tables must have string keys (encountered non-string key '" .. key .. "[" .. tostring(k) .. "]' when calling Util.Serialize)")
				end
				symbolicValue[k] = Util.Serialize(k, v)
			end
		else
			local expectedi = 1
			for i, v in pairs(object) do
				if i ~= expectedi then
					error("Serialized array tables must have sequential keys (encountered non-sequential key '" .. key .. "[" .. tostring(i) .. "]' when calling Util.Serialize)")
				end
				expectedi = expectedi + 1
				
				symbolicValue[i] = Util.Serialize(i, v)
			end
		end
	elseif rbxType == "Axes" then
		serialType = rbxType
		symbolicValue = {
			object.X,
			object.Y,
			object.Z,
			object.Top,
			object.Bottom,
			object.Left,
			object.Right,
			object.Back,
			object.Front,
		}
	elseif rbxType == "BrickColor" then
		serialType = rbxType
		symbolicValue = object.Number
	elseif rbxType == "CFrame" then
		serialType = rbxType
		symbolicValue = {object:components()}
	elseif rbxType == "Color3" then
		serialType = rbxType
		symbolicValue = {object.r, object.g, object.b}
	elseif rbxType == "ColorSequence" then
		serialType = rbxType
		symbolicValue = {}
		for i, keypoint in ipairs(object.Keypoints) do
			symbolicValue[#symbolicValue + 1] = Util.Serialize(i, keypoint)
		end
	elseif rbxType == "ColorSequenceKeypoint" then
		serialType = rbxType
		symbolicValue = {
			Util.Serialize(1, object.Time),
			Util.Serialize(2, object.Value),
		}
	elseif rbxType == "Faces" then
		serialType = rbxType
		symbolicValue = {
			object.Top,
			object.Bottom,
			object.Left,
			object.Right,
			object.Back,
			object.Front,
		}
	elseif rbxType == "NumberRange" then
		serialType = rbxType
		symbolicValue = {object.Min, object.Max}
	elseif rbxType == "NumberSequence" then
		serialType = rbxType
		symbolicValue = {}
		for i, keypoint in ipairs(object.Keypoints) do
			symbolicValue[#symbolicValue + 1] = Util.Serialize(i, keypoint)
		end
	elseif rbxType == "NumberSequenceKeypoint" then
		serialType = rbxType
		symbolicValue = {
			Util.Serialize(1, object.Time),
			Util.Serialize(2, object.Value),
			Util.Serialize(3, object.Envelope),
		}
	elseif rbxType == "PathWaypoint" then
		serialType = rbxType
		symbolicValue = {
			object.Position,
			object.Action,
		}
	elseif rbxType == "PhysicalProperties" then
		serialType = rbxType
		symbolicValue = {
			object.Density,
			object.Friction,
			object.Elasticity,
			object.FrictionWeight,
			object.ElasticityWeight,
		}
	elseif rbxType == "Ray" then
		serialType = rbxType
		symbolicValue = {
			object.Origin,
			object.Direction,
		}
	elseif rbxType == "Rect" then
		serialType = rbxType
		symbolicValue = {
			object.Min.X,
			object.Min.Y,
			object.Max.X,
			object.Max.Y,
		}
	elseif rbxType == "Region3" then
		serialType = rbxType
		symbolicValue = {
			Util.Serialize(1, object.CFrame.p - object.Size / 2),
			Util.Serialize(2, object.CFrame.p + object.Size / 2),
		}
	elseif rbxType == "TweenInfo" then
		serialType = rbxType
		symbolicValue = {
			object.Time,
			object.EasingDirection,
			object.EasingStyle,
			object.EasingDirection,
			object.RepeatCount,
			object.Reverses,
			object.DelayTime,
		}
	elseif rbxType == "UDim" then
		serialType = rbxType
		symbolicValue = {
			object.Scale,
			object.Offset,
		}
	elseif rbxType == "UDim2" then
		serialType = rbxType
		symbolicValue = {
			object.X.Scale,
			object.X.Offset,
			object.Y.Scale,
			object.Y.Offset,
		}
	elseif rbxType == "Vector2" then
		serialType = rbxType
		symbolicValue = {
			object.X,
			object.Y,
		}
	elseif rbxType == "Vector2" then
		serialType = rbxType
		symbolicValue = {
			object.X,
			object.Y,
		}
	elseif rbxType == "Vector2" or rbxType == "Vector2int16" then
		serialType = rbxType
		symbolicValue = {
			object.X,
			object.Y,
		}
	elseif rbxType == "Vector3" or rbxType == "Vector3int16" then
		serialType = rbxType
		symbolicValue = {
			object.X,
			object.Y,
			object.Z,
		}
	else
		error("Type '" .. rbxType .. "' is not supported (encountered at key '" .. key .. "' when calling Util.Serialize)")
	end
	return {key, serialType, symbolicValue}
end

-- Serialized values should be in the form {key, type, symbolic_value, [preservation_id]}
function Util.Deserialize(serialized)
	local serialType = serialized[2]
	local symbolicValue = serialized[3]
	
	if serialType == "Raw" then
		return symbolicValue
	elseif serialType == "Table" then
		local tab = {}
		for _, serialValue in pairs(symbolicValue) do
			tab[serialValue[1]] = Util.Deserialize(serialValue)
		end
		return tab
	elseif serialType == "Axes" then
		local axisList = {}
		local i = 1
		local function checkAxis(name)
			if symbolicValue[i] then
				table.insert(axisList, name)
			end
			i = i + 1
		end
		
		checkAxis(Enum.Axis.X)
		checkAxis(Enum.Axis.Y)
		checkAxis(Enum.Axis.Z)
		checkAxis(Enum.NormalId.Top)
		checkAxis(Enum.NormalId.Bottom)
		checkAxis(Enum.NormalId.Left)
		checkAxis(Enum.NormalId.Right)
		checkAxis(Enum.NormalId.Back)
		checkAxis(Enum.NormalId.Front)
		
		return Axes.new(unpack(axisList))
	elseif serialType == "BrickColor" then
		return BrickColor.new(symbolicValue)
	elseif serialType == "CFrame" then
		return CFrame.new(unpack(symbolicValue))
	elseif serialType == "Color3" then
		return Color3.new(unpack(symbolicValue))
	elseif serialType == "ColorSequence" then
		local keypoints = {}
		for _, serialKP in pairs(symbolicValue) do
			keypoints[serialKP[2]] = Util.Deserialize(serialKP)
		end
		
		return ColorSequence.new(keypoints)
	elseif serialType == "ColorSequenceKeypoint" then
		local args = {}
		for _, serialArg in pairs(symbolicValue) do
			args[serialArg[2]] = Util.Deserialize(serialArg)
		end
		
		return ColorSequenceKeypoint.new(unpack(args))
	elseif serialType == "Faces" then
		local faceList = {}
		local i = 1
		local function checkFace(name)
			if symbolicValue[i] then
				table.insert(faceList, name)
			end
			i = i + 1
		end
		
		checkFace(Enum.NormalId.Top)
		checkFace(Enum.NormalId.Bottom)
		checkFace(Enum.NormalId.Left)
		checkFace(Enum.NormalId.Right)
		checkFace(Enum.NormalId.Back)
		checkFace(Enum.NormalId.Front)
		
		return Faces.new(unpack(faceList))
	elseif serialType == "NumberRange" then
		return NumberRange.new(unpack(symbolicValue))
	elseif serialType == "NumberSequence" then
		local keypoints = {}
		for _, serialKP in pairs(symbolicValue) do
			keypoints[serialKP[2]] = Util.Deserialize(serialKP)
		end
		
		return NumberSequence.new(keypoints)
	elseif serialType == "NumberSequenceKeypoint" then
		local args = {}
		for _, serialArg in pairs(symbolicValue) do
			args[serialArg[2]] = Util.Deserialize(serialArg)
		end
		
		return NumberSequenceKeypoint.new(unpack(args))
	elseif serialType == "PathWaypoint" then
		return PathWaypoint.new(unpack(symbolicValue))
	elseif serialType == "PhysicalProperties" then
		return PhysicalProperties.new(unpack(symbolicValue))
	elseif serialType == "Ray" then
		return Ray.new(unpack(symbolicValue))
	elseif serialType == "Rect" then
		return Rect.new(unpack(symbolicValue))
	elseif serialType == "Region3" then
		local args = {}
		for _, serialArg in pairs(symbolicValue) do
			args[serialArg[2]] = Util.Deserialize(serialArg)
		end
		
		return Region3.new(unpack(args))
	elseif serialType == "TweenInfo" then
		return TweenInfo.new(unpack(symbolicValue))
	elseif serialType == "UDim" then
		return UDim.new(unpack(symbolicValue))
	elseif serialType == "UDim2" then
		return UDim2.new(unpack(symbolicValue))
	elseif serialType == "Vector2" then
		return Vector2.new(unpack(symbolicValue))
	elseif serialType == "Vector2int16" then
		return Vector2int16.new(unpack(symbolicValue))
	elseif serialType == "Vector3" then
		return Vector3.new(unpack(symbolicValue))
	elseif serialType == "Vector3int16" then
		return Vector3int16.new(unpack(symbolicValue))
	end
	
	return nil
end

local nextId = 0
Util.NextId = function()
	nextId = nextId + 1
	return nextId
end

function Util.Inspect(tab, maxDepth, currentDepth, key)
	maxDepth = maxDepth or math.huge
	currentDepth = currentDepth or 0
	
	if currentDepth > maxDepth then return end
	local currentIndent = string.rep("    ", currentDepth)
	local nextIndent = string.rep("    ", currentDepth + 1)
	
	print(currentIndent .. (key and (key .. " = ") or "") .. tostring(tab) .. " {")
	
	for k, v in pairs(tab) do
		if type(v) == "table" then
			Util.Inspect(v, maxDepth, currentDepth + 1)
		else
		    local key_str = tostring(k)
		    if type(k) == "number" then
		      key_str = '[' .. key_str .. ']'
			end
			
		    local value_str
			if type(v) == "string" then
				value_str = "'" .. tostring(v) .. "'"
			else
				value_str = tostring(v)
			end
			
			print(nextIndent .. tostring(key_str) .. " = " .. value_str .. ",")
		end
	end
	print(currentIndent .. "}")
end

return Util