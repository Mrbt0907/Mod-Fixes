if SERVER then return end
LuaUserData.RegisterType("Microsoft.Xna.Framework.Color")
LuaUserData.RegisterType("Barotrauma.Items.Components.ConnectionPanel")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.ServerMsgLString"], "cachedValue")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.ServerMsgLString"], "serverMessage")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Items.Components.Connection"], "DrawWires")

local function t_clear(t) for k in pairs(t) do t[k] = nil end return t end
local function GetComponent(item, name) name = name:sub(29) 
  for _, component in ipairs(item.Components) do
	if component.Name == name then return component end
  end
end

local savedDisplayNames = {}
local Patches = {}
local savedHighLightedWires = {}

Hook.Patch("BetterConnectionPanel.Before", "Barotrauma.Items.Components.Connection", "DrawWires", function(instance, ptable)
	local panel = ptable["panel"]
	if panel == nil then return end
	for c in panel.Connections do
		if not c then return end
		for wire in c.wires do
			local recipient = wire.OtherConnection(c)
			local id = recipient.DisplayName.serverMessage..recipient.item.ID
			if recipient and savedDisplayNames[id] == nil then
				recipient.DisplayName.cachedValue = recipient.item.ID .. ") (" .. recipient.DisplayName.cachedValue
				savedDisplayNames[id] = true
			end
		end
		if string.match(c.DisplayName.cachedValue, "^%d+%)%s*%(") then 
			savedDisplayNames[c.DisplayName.serverMessage..c.item.ID] = nil
			c.DisplayName.cachedValue = string.gsub(c.DisplayName.cachedValue, "^%d+%)%s*%(", "")
		end
	end
end, Hook.HookMethodType.Before)

Hook.Add("roundEnd", "clearSavedDisplayNames", function()
	t_clear(savedDisplayNames)
	t_clear(Patches)
	t_clear(savedHighLightedWires)
end)

Hook.Add("item.created", "patchPanelsUi", function(item)
	local panel = GetComponent(item, "Barotrauma.Items.Components.ConnectionPanel")
	if panel == nil then return end
	
	Patches[panel.item.ID] = false
	
	----------------new "Name (ID)" Bar above panels
	local text = item.Name .. " (" .. tostring(item.ID) .. ")"
	if not panel.GuiFrame then return end
	local NameText = GUI.TextBlock(GUI.RectTransform(Point(200, 30), panel.GuiFrame.RectTransform), text, Color(0,0,0,0))
	local measure = NameText.TextSize
	NameText.RectTransform.AbsoluteOffset = Point(0, -28)
	local NameFrame = GUI.Frame(GUI.RectTransform(Point(measure.X + 25, 30), NameText.RectTransform), "DialogBox")
	local NameText2 = GUI.TextBlock(GUI.RectTransform(Vector2(1,1), NameText.RectTransform), text)
	
	----------------KeepWireHighlight Button
	local buttonHeight = GUI.GUIStyle.ItemFrameMargin.Y * 0.4
	local buttonRect = GUI.RectTransform(Point(buttonHeight), panel.GuiFrame.RectTransform, GUI.Anchor.TopLeft)
	buttonRect.AbsoluteOffset = Point(buttonHeight * 1.25, buttonHeight * 0.225)
	buttonRect.MinSize = Point(buttonHeight)
	local KeepWireHighlightButton = GUI.Button(buttonRect, GUI.Alignment.Center, "GUIButtonSettings")
	KeepWireHighlightButton.ToolTip = "Toggle KeepWireHighlight\nIf on, will keep wire highlight even when" ..
									  " not selecting the connection panel."
	KeepWireHighlightButton.HoverColor = Color(237,167,5,255)
	KeepWireHighlightButton.OnClicked = function()
		if Patches[panel.item.ID] then 
			Patches[panel.item.ID] = false
			KeepWireHighlightButton.Color = Color(204,204,204,255)
		else 
			Patches[panel.item.ID] = true 
			KeepWireHighlightButton.Color = Color(237,167,5,255)
		end
	end
end)

Hook.Patch("SaveWireHighlight","Barotrauma.Items.Components.ConnectionPanel", "UpdateHUD", function(instance, ptable)
	if not Patches[instance.item.ID] then 
		if savedHighLightedWires[instance.item.ID] ~= nil then
			savedHighLightedWires[instance.item.ID] = nil
		end
		return 
	end
	if instance.HighlightedWire ~= nil then
		savedHighLightedWires[instance.item.ID] = instance.HighlightedWire
	end
end,Hook.HookMethodType.After)

Hook.Add("think", "ShowTheHighLights", function()
	for _, wire in pairs(savedHighLightedWires) do
		wire.Item.IsHighlighted = true
		if wire.Connections[2] and wire.Connections[2].Item then 
			wire.Connections[2].Item.IsHighlighted = true 
		end
		if wire.Connections[1] and wire.Connections[1].Item then 
			wire.Connections[1].Item.IsHighlighted = true 
		end
	end
end)
