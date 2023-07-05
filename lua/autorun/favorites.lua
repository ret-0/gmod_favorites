---- favorites.lua
--- https://github.com/ret-0/gmod_favorites
--- https://steamcommunity.com/sharedfiles/filedetails/?id=2901526545

--- Tier 1: Crashes, Major Performance Problems
--- Tier 2: Non-Fatal Bugs
--- Tier 3: Addon Support
-- TODO: fix pills and weather
-- TODO: workshop dupes
-- TODO: bodygroups
--- Tier 4: Additional Features
-- TODO: modifiable spawnmenu position
-- TODO: right click change category
-- TODO: rename categories
-- TODO: add custom category for spawn weapons that modifies it when edited
-- TODO: subfolders of folders
-- TODO: "New Text Label" button

--- Globals

-- Favorites Favorites(): Constructor for favorites structure.
function Favorites()
	local r = {}
	r.weapons = {}
	r.props = {}
	r.npcs = {}
	r.entities = {}
	r.vehicles = {}
	r.dupes = {}
	r.materials = {}
	return r
end
local g_favorites = Favorites()
local g_tree = nil
local g_file = "favorites/favorites.json"
local g_nodeIndex = 0
local g_ctrl = nil

CreateClientConVar("favorites_save_weapon", "1")
CreateClientConVar("favorites_tutorial", "1")
CreateClientConVar("favorites_key", tostring(KEY_E))
CreateClientConVar("favorites_use_mode", "0")

--- Functions

-- number Find(table t, string item): Returns index of an item in a table or 0 if not found.
function Find(t, item)
	local contains = 0
	for k, w in pairs(t) do
		if w == item or w.ClassName == item or (item.isPill and item.icon == item.icon) then -- Handles a lot of cases.
			contains = k
			break
		end
	end
	return contains
end

-- Toggle(table t, any item): Toggles the existence of an item in a table.
function Toggle(t, item)
	local i = Find(t, item)
	if i != 0 then table.remove(t, i)
	else table.insert(t, item) end
end

-- ToggleWeapon(string weapon): Toggles the existence of a weapon in g_favorites.weapons.
function ToggleWeapon(weapon, printName)
	local i = Find(g_favorites.weapons, weapon)
	if i != 0 then table.remove(g_favorites.weapons, i) else
		local w = weapons.Get(weapon)
		if w != nil then table.insert(g_favorites.weapons, w) else
			-- HL2 Weapon Fix: This is ridiculous and really shouldn't work as well as it does but sure whatever man. :^)
			local fakeWeapon = {}
			fakeWeapon.ClassName = weapon
			fakeWeapon.PrintName = printName
			table.insert(g_favorites.weapons, fakeWeapon)
		end
	end
end

-- https://wiki.facepunch.com/gmod/Default_Lists
-- Entity GetEntityFromList(string listName, string className): Returns entity from Sandbox lists or nil if not found.
function GetEntityFromList(listName, className)
	local entity = nil
	for name, ent in SortedPairsByMemberValue(list.Get(listName), "Name") do
		if ent.Class == className or ent.ClassName == className or name == className then
			entity = ent
			break
		end
	end
	return entity
end

-- table TableRemove(table t, function(t, i, j) fnKeep): Optimized table element removal function.
function TableRemove(t, fnKeep)
	local j, n = 1, #t
	for i = 1, n do
		if (fnKeep(t, i, j)) then
			-- Move i's kept value to j's position, if it's not already there.
			if (i ~= j) then
				t[j] = t[i]
				t[i] = nil
			end
			j = j + 1 -- Increment position of where we'll place the next kept value.
		else
			t[i] = nil
		end
	end
	return t
end

-- SaveEmpty(string f): Writes empty favorites table as JSON to file.
function SaveEmpty(f) file.Write(f, util.TableToJSON(Favorites())) end

-- Save(string f): Writes g_favorites as JSON to file.
function Save(f) file.Write(f, util.TableToJSON(g_favorites)) end

-- SaveRefresh(): Writes g_favorites as JSON to g_file and refreshs the current category.
function SaveRefresh()
	Save(g_file)
	g_tree:Root():GetChildNode(g_nodeIndex):InternalDoClick()
end

-- Load(string f): Loads JSON from file to g_favorites. Creates new empty file if not there.
function Load(f)
	g_favorites = Favorites()
	local json = file.Read(f)
	if json != nil then
		local loaded = util.JSONToTable(json)
		for k, v in pairs(loaded) do g_favorites[k] = v end
	else SaveEmpty(f) end
end

-- Header(Panel self, string text): Appends a Spawn Menu header to the current spawnlist.
function Header(self, text)
	local header = self:Add("ContentHeader")
	header:SetText(text)
	self.PropPanel:Add(header)
end

-- Text(Panel self, string text): Appends text to the current spawnlist.
function Text(self, text)
	local panel = self:Add("DLabel")
	panel.OwnLine = true
	panel:SetTextColor(Color(255, 255, 255))
	panel:SetFont("ChatFont")
	panel:SetText(text)
	panel:SizeToContents()
	panel:SetAutoStretchVertical(true)
	self.PropPanel:Add(panel)
end

-- PillFromPanel(table t): Construct a pill from a panel.
function PillFromPanel(t)
	local pill = {}
	pill.isPill = true
	pill.name = t.m_MaterialName:gsub("pills/", ""):gsub(".png", "") -- This seems to be the easiest way to extract the spawnname.
	pill.printName = t.m_NiceName
	pill.icon = t.m_MaterialName
	return pill
end

--- Main

if file.Exists("favorites", "DATA") == false then file.CreateDir("favorites") end -- Create favorites folder if not there.
if file.Exists("favorites.json", "DATA") then -- Move old favorites.json to favorites/.
	local content = file.Read("favorites.json")
	file.Write("favorites/favorites.json", content)
	file.Delete("favorites.json")
end
Load(g_file) -- Load favorites/favorites.json.

if CLIENT then -- This is madness.
	local originalStopDragging = dragndrop.StopDragging
	dragndrop.StopDragging = function()
		local srctable = dragndrop.GetDroppable()
        	if !srctable or !srctable[1] then return originalStopDragging() end 
        	local src = srctable[1]
		local dst = vgui.GetHoveredPanel()
		if dst == nil then return end
		local panelName = dst:GetName()

		if (panelName == "ContentIcon" or panelName == "SpawnIcon") and dst.f_table != nil and dst.f_table == src.f_table then
			local n = dst.f_index
			if n < 1 then n = 1 end
			TableRemove(dst.f_table, function(t, i, j)
				if i == src.f_index then return false end
				return true
			end)
			table.insert(dst.f_table, n, src.f_item)
			SaveRefresh()
		end

		return originalStopDragging()
	end
end

hook.Add("PopulateFavorites", "AddFavoritesContent", function(panelContent, tree, node)
	g_tree = tree -- We save the tree so the favoriting routines can call InternalDoClick() refreshing the page.

	local files, directories = file.Find("favorites/*", "DATA")
	for i, v in ipairs(files) do -- Delete favorites.json wherever it is in the list.
		if v == "favorites.json" then table.remove(files, i) end
	end
	table.insert(files, 1, "favorites.json") -- Prepend favorites.json to the beginning so it is the first category.

	for i, filename in ipairs(files) do
		local name = string.StripExtension(filename:gsub("#%l", string.upper):gsub("#", "")) -- Fix casing and remove extension.
		if filename == "favorites.json" then name = "#gmod_favorites.favorites" end
		local node = tree:AddNode(name, "icon16/folder.png")

		node.DoPopulate = function(self)
			-- Set what category we are on.
			g_file = "favorites/" .. filename
			g_nodeIndex = i - 1 -- Zero-based indices.
			Load(g_file)

			-- Initialize container.
			self.PropPanel = vgui.Create("ContentContainer", panelContent)
			self.PropPanel:SetVisible(false)
			self.PropPanel:SetTriggerSpawnlistChange(false)

			-- This is scuffed lol.
			local moveIndicatorBG = vgui.Create("DPanel", self.PropPanel)
			moveIndicatorBG:SetSize(0, 0)
			moveIndicatorBG:SetPos(0, 0)
			moveIndicatorBG:SetVisible(false)
			function moveIndicatorBG:Paint(w, h)
				draw.RoundedBox(10, 0, 0, w, h, Color(255, 255, 255, 255))
			end
			local moveIndicator = vgui.Create("DPanel", self.PropPanel)
			moveIndicator:SetSize(0, 0)
			moveIndicator:SetPos(0, 0)
			moveIndicator:SetVisible(false)
			function moveIndicator:Paint(w, h)
				moveIndicatorBG:CopyBounds(moveIndicator)
				local x, y = moveIndicatorBG:GetPos()
				local w, h = moveIndicatorBG:GetSize()
				moveIndicatorBG:SetPos(x - 1, y - 1)
				moveIndicatorBG:SetSize(w + 2, h + 2)
				draw.RoundedBox(8, 0, 0, w, h, Color(255, 120, 255, 255))
			end
			local originalPaint = self.PropPanel.Paint
			self.PropPanel.Paint = function(w, h) -- Called every frame.
				local hovered = vgui.GetHoveredPanel()
				if hovered == nil then return end
				local panelName = hovered:GetName()

				if dragndrop.IsDragging() and (panelName == "ContentIcon" or panelName == "SpawnIcon") then
					moveIndicator:SetVisible(true)
					moveIndicatorBG:SetVisible(true)
					moveIndicator:CopyBounds(hovered)
					moveIndicator:SetWidth(2.35)
					local x, y = moveIndicator:GetPos()
					moveIndicator:SetPos(x - 1, y)
				else
					moveIndicator:SetVisible(false)
					moveIndicatorBG:SetVisible(false)
				end

				originalPaint(w, h)
			end

			local saveCurrentWeapon = GetConVar("favorites_save_weapon"):GetBool()
			if saveCurrentWeapon then
				Header(self, "#spawnmenu.category.weapons")
				local currentWeapon = spawnmenu.CreateContentIcon("weapon", self.PropPanel, {
					nicename	= "#gmod_favorites.save_weapon",
					spawnname	= "__dummy",
					material	= "gmod/save.png",
					admin		  = false
				})
				currentWeapon.DoClick = function() -- Evil hack >:^).
					surface.PlaySound("ui/buttonclick.wav")
					local w = LocalPlayer():GetActiveWeapon()
					local weapon = w:GetClass()
					ToggleWeapon(w:GetClass(), w:GetPrintName())
					Save(g_file)
					g_tree:Root():GetChildNode(i - 1):InternalDoClick()
				end
			end

			local empty = true
			if table.IsEmpty(g_favorites.weapons) == false then
				empty = false
				if saveCurrentWeapon == false then Header(self, "#spawnmenu.category.weapons") end

				local save = false
				TableRemove(g_favorites.weapons, function(t, i, j) -- TODO: more explicit
					if t[i].ClassName == nil then -- Delete if invalid.
						print("Removing invalid weapon:")
						PrintTable(t[i])
						save = true
						return false
					end
					return true
				end)
				if save then Save(g_file) end

				for i, weapon in pairs(g_favorites.weapons) do
					local p = spawnmenu.CreateContentIcon("weapon", self.PropPanel, {
						nicename  = weapon.PrintName or weapon.ClassName,
						spawnname = weapon.ClassName,
						material  = weapon.IconOverride or "entities/" .. weapon.ClassName .. ".png",
						admin     = weapon.AdminOnly
					})
					p.f_table = g_favorites.weapons
					p.f_index = i
					p.f_item  = weapon
				end
			end

			if table.IsEmpty(g_favorites.props) == false then
				empty = false
				Header(self, "#gmod_favorites.props")
				-- Removing invalid props is both hard to do, and won't really break anything; just show an error model.
				for i, prop in pairs(g_favorites.props) do
					local mdl = prop
					local skinID = nil
					if string.match(prop, ":") then
						local s1, _ = prop:gsub(":.*", "")
						local s2, _ = prop:gsub(".*:", "")
						mdl = s1
						skinID = tonumber(s2)
					end
					local p = spawnmenu.CreateContentIcon("model", self.PropPanel, {model = mdl, skin = skinID})
					p.DoClick = function(s) -- Another workaround.
						surface.PlaySound("ui/buttonclickrelease.wav")
						LocalPlayer():ConCommand("gm_spawn " .. s:GetModelName() .. ' ' .. tostring(s:GetSkinID() or 0), s:GetBodyGroup() or "")
					end
					p.f_table = g_favorites.props
					p.f_index = i
					p.f_item  = prop
				end
			end

			if table.IsEmpty(g_favorites.npcs) == false then
				empty = false
				Header(self, "#spawnmenu.category.npcs")

				local save = false
				TableRemove(g_favorites.npcs, function(t, i, j)
					if GetEntityFromList("NPC", t[i]) == nil then -- Delete if invalid.
						print("Removing invalid NPC: " .. t[i] .. "!")
						save = true
						return false
					end
					return true
				end)
				if save then Save(g_file) end

				for i, npc in pairs(g_favorites.npcs) do
					local entity = GetEntityFromList("NPC", npc)
					local nameOverride = nil -- Fixes for weird name overlaps.
					if npc == "npc_combine_s" then nameOverride = "Combine Soldier" -- Would be "Combine Elite".
					elseif npc == "npc_vortigaunt" then nameOverride = "Vortigaunt" end -- Would be "Uriah".

					local p = spawnmenu.CreateContentIcon("npc", self.PropPanel, {
						nicename  = nameOverride or entity.Name or npc,
						spawnname = npc,
						material  = entity.IconOverride or "entities/" .. npc .. ".png",
						weapon    = entity.Weapons,
						admin     = entity.AdminOnly
					})
					p.DoClick = function() -- Workaround for the new update breaking something. Very cool. Thank you based Garry.
						if !entity.Weapons then entity.Weapons = {} end
						local weapon = table.Random(entity.Weapons) or ""
						local gmod_npcweapon = GetConVar("gmod_npcweapon"):GetString()
						if (gmod_npcweapon != "") then weapon = gmod_npcweapon end
						-- Fix: Use LocalPlayer():ConCommand() instead of RunConsoleCommand().
						-- Your guess is as good as mine on why this works.
						LocalPlayer():ConCommand('gmod_spawnnpc ' .. npc .. ' ' .. weapon)
						surface.PlaySound("ui/buttonclickrelease.wav")
					end
					p.f_table = g_favorites.npcs
					p.f_index = i
					p.f_item  = npc
				end
			end

			if table.IsEmpty(g_favorites.vehicles) == false then
				empty = false
				Header(self, "#spawnmenu.category.vehicles")

				local save = false
				TableRemove(g_favorites.vehicles, function(t, i, j)
					if GetEntityFromList("Vehicles", t[i]) == nil and GetEntityFromList("simfphys_vehicles", t[i]) == nil then -- Delete if invalid.
						print("Removing invalid vehicle: " .. t[i] .. "!")
						save = true
						return false
					end
					return true
				end)
				if save then Save(g_file) end

				for i, vehicle in pairs(g_favorites.vehicles) do
					local simfphys = GetEntityFromList("simfphys_vehicles", vehicle)
					local entity = GetEntityFromList("Vehicles", vehicle) or simfphys
					local icon = spawnmenu.CreateContentIcon("vehicle", self.PropPanel, {
						nicename  = entity.Name or vehicle,
						spawnname = vehicle,
						material  = entity.IconOverride or "entities/" .. vehicle .. ".png",
						admin     = entity.AdminOnly
					})
					icon.f_table = g_favorites.vehicles
					icon.f_index = i
					icon.f_item  = vehicle
					if simfphys != nil then
						icon.DoClick = function()
							surface.PlaySound("ui/buttonclickrelease.wav") -- Fake spawn sound.
							RunConsoleCommand("simfphys_spawnvehicle", vehicle)
						end
					end
				end
			end

			if table.IsEmpty(g_favorites.entities) == false then
				empty = false
				Header(self, "#spawnmenu.category.entities")

				local save = false
				TableRemove(g_favorites.entities, function(t, i, j)
					if t[i].isPill then return true end -- TODO: We'll cross that bridge when we get to it.
					if -- Jesus fucking christ.
					GetEntityFromList("SpawnableEntities", t[i]) == nil and
					GetEntityFromList("gDisasters_Equipment", t[i]) == nil and
					GetEntityFromList("gDisasters_Weapons", t[i]) == nil and
					GetEntityFromList("gDisasters_Weather", t[i]) == nil and
					GetEntityFromList("gDisasters_Buildings", t[i]) == nil and
					GetEntityFromList("gDisasters_Disasters", t[i]) == nil
					then -- Delete if invalid.
						print("Removing invalid entity: " .. t[i] .. "!")
						save = true
						return false
					end
					return true
				end)
				if save then Save(g_file) end

				for i, e in pairs(g_favorites.entities) do
					if e.isPill then
						local icon = spawnmenu.CreateContentIcon("entity", self.PropPanel, {
							nicename  = e.printName or e.name,
							spawnname = e.name,
							material  = e.icon,
							admin     = false -- Fuck you I don't care.
						})
						icon.DoClick = function()
							surface.PlaySound("ui/buttonclickrelease.wav")
							RunConsoleCommand("pk_pill_apply", e.name)
						end
						-- Used to identify pills in untoggling.
						icon.isPill = true
						icon.m_MaterialName = e.icon
						icon.m_NiceName = e.printName
						icon.f_table = g_favorites.entities
						icon.f_index = i
						icon.f_item  = e
					else
						local entity = GetEntityFromList("SpawnableEntities", e) or
							GetEntityFromList("gDisasters_Equipment", e) or -- "WOULDN'T IT BE FUNNY IF WE HAD 5 SEPERATE LISTS FOR FUCKING ENTITIES :)))"
							GetEntityFromList("gDisasters_Weapons", e)   or
							GetEntityFromList("gDisasters_Weather", e)   or
							GetEntityFromList("gDisasters_Buildings", e) or
							GetEntityFromList("gDisasters_Disasters", e)
						local p = spawnmenu.CreateContentIcon(entity.ScriptedEntityType or "entity", self.PropPanel, {
							nicename  = entity.Name or entity.PrintName or e,
							spawnname = e,
							material  = entity.IconOverride or "entities/" .. e .. ".png",
							admin     = entity.AdminOnly
						})
						p.f_table = g_favorites.entities
						p.f_index = i
						p.f_item  = e
					end
				end
			end

			if table.IsEmpty(g_favorites.dupes) == false then
				empty = false
				Header(self, "#spawnmenu.category.dupes")
				-- Same deal with dupes, they don't really cause any problems if broken.
				for i, dupe in pairs(g_favorites.dupes) do
					local p = spawnmenu.CreateContentIcon("weapon", self.PropPanel, {
						nicename  = dupe,
						spawnname = "__dupe",
						material  = "dupes/" .. dupe .. ".jpg",
						admin     = false
					})
					p.DoClick = function()
						surface.PlaySound("ui/buttonclickrelease.wav")
						RunConsoleCommand("dupe_arm", "dupes/" .. dupe .. ".dupe")
					end
					p.f_table = g_favorites.dupes
					p.f_index = i
					p.f_item  = dupe
				end
			end

			if table.IsEmpty(g_favorites.materials) == false then
				empty = false
				Header(self, "#gmod_favorites.materials")
				for i, material in pairs(g_favorites.materials) do
					local p = spawnmenu.CreateContentIcon("weapon", self.PropPanel, {
						nicename  = material,
						spawnname = material,
						material  = material,
						admin     = false
					})
					p.m_Type = "material"
					-- I truly cannot find where any of this is implemented so let's just emulate the functionality ourselves lol.
					local LoadMaterial = function()
						surface.PlaySound("ui/buttonclickrelease.wav")
						LocalPlayer():ConCommand("material_override " .. material)
						LocalPlayer():ConCommand("gmod_toolmode material")
						LocalPlayer():ConCommand("use gmod_tool")
					end
					p.OpenMenu = function(self)
						local menu = DermaMenu()
						menu:AddOption("#spawnmenu.menu.copy", function() SetClipboardText(self:GetSpawnName()) end):SetIcon("icon16/page_copy.png")
						menu:AddOption("#gmod_favorites.use_material", function() LoadMaterial() end):SetIcon("icon16/pencil.png")
						menu:Open()
					end
					p.DoClick = function() LoadMaterial() end
					p.f_table = g_favorites.materials
					p.f_index = i
					p.f_item  = material
				end
			end

			if empty then
				local tutorial = GetConVar("favorites_tutorial"):GetBool()
				if tutorial then
					Text(self,
						"\n" ..
						language.GetPhrase("gmod_favorites.tutorial1") .. "\n\n" ..
						language.GetPhrase("gmod_favorites.tutorial2") .. "\n" ..
						language.GetPhrase("gmod_favorites.tutorial3") .. "\n" ..
						language.GetPhrase("gmod_favorites.tutorial4") .. "\n" ..
						language.GetPhrase("gmod_favorites.tutorial5") .. "\n" ..
						language.GetPhrase("gmod_favorites.tutorial6") .. "\n" ..
						language.GetPhrase("gmod_favorites.tutorial7") .. "\n" ..
						language.GetPhrase("gmod_favorites.tutorial8") .. "\n" ..
						language.GetPhrase("gmod_favorites.tutorial9")
					)
				else Text(self, "\n" .. language.GetPhrase("#gmod_favorites.tutorial1")) end
			end
		end

		node.DoClick = function(self)
			self:DoPopulate()
			panelContent:SwitchPanel(self.PropPanel)
		end

		tree:Root():GetChildNode(0):InternalDoClick()
	end
end)

-- Bottom Drawer Panel
local drawer = {}
if Derma_Hook != nil then Derma_Hook(drawer, "Paint", "Paint", "Tree") end -- Initialize panel.
drawer.m_bBackground = true -- Hack for above.
function drawer:AddCheckbox(text, cvar)
	local DermaCheckbox = self:Add("DCheckBoxLabel", self)
	DermaCheckbox:Dock(TOP)
	DermaCheckbox:SetText(text)
	DermaCheckbox:SetDark(true)
	DermaCheckbox:SetConVar(cvar)
	DermaCheckbox:SizeToContents()
	DermaCheckbox:DockMargin(0, 5, 0, 0)
	return DermaCheckbox
end
local g_skipChange = true
function drawer:Init()
	self:SetOpenSize(225)
	self:DockPadding(15, 10, 15, 10)

	local text = vgui.Create("DTextEntry", self)
	text:Dock(TOP)
	text:DockMargin(0, 5, 0, 0)
	text:SetPlaceholderText("#gmod_favorites.name")

	local add = vgui.Create("DButton", self)
	add:Dock(TOP)
	add:DockMargin(0, 5, 0, 0)
	add:SetDark(true)
	add:SetText("#gmod_favorites.add_category")
	add.DoClick = function()
		local name = text:GetValue()
		-- Disallowed Windows and Unix characters.
		name = name:gsub("/", ""):gsub("\\", ""):gsub("<", ""):gsub(">", ""):gsub(":", ""):gsub("\"", ""):gsub("|", ""):gsub("?", ""):gsub("*", "")
		-- Fake capital characters cause gmod is stupid.
		name = name:gsub("#", "")
		name = name:gsub("%u", "#%1")

		local filename = "favorites/" .. name .. ".json"
		if name != "" and file.Exists(filename, "DATA") == false then
			SaveEmpty(filename)
			RunConsoleCommand("spawnmenu_reload")
			print("Created " .. filename .. ".")
		end
		text:SetValue("")
	end

	local del = vgui.Create("DButton", self)
	del:Dock(TOP)
	del:DockMargin(0, 5, 0, 0)
	del:SetDark(true)
	del:SetText("#gmod_favorites.delete_category")
	del.DoClick = function()
		if g_file == "favorites/favorites.json" then return end
		file.Delete(g_file)
		RunConsoleCommand("spawnmenu_reload")
		print("Deleted " .. g_file .. "!")
	end

	local clear = vgui.Create("DButton", self)
	clear:Dock(TOP)
	clear:DockMargin(0, 5, 0, 0)
	clear:SetDark(true)
	clear:SetText("#gmod_favorites.clear_category")
	clear.DoClick = function()
		file.Delete(g_file)
		SaveEmpty(g_file)
		RunConsoleCommand("spawnmenu_reload")
		print("Cleared " .. g_file .. "!")
	end

	local bLabel = vgui.Create("DLabel", self)
	bLabel:Dock(TOP)
	bLabel:DockMargin(0, 0, 0, 0)
	bLabel:SetSize(25, 25)
	bLabel:SetTextColor(Color(0, 0, 0))
	bLabel:SetText("#gmod_favorites.bind")
	local binder = vgui.Create("DBinder", self)
	binder:Dock(TOP)
	binder:DockMargin(0, 0, 0, 0)
	binder:SetSize(20, 20)
	binder:SetValue(GetConVar("favorites_key"):GetInt())
	function binder:OnChange(key) RunConsoleCommand("favorites_key", tostring(key)) end
	local useMode = GetConVar("favorites_use_mode"):GetBool()
	if useMode then binder:SetEnabled(false) end
	local useModeCheckBox = self:AddCheckbox("#gmod_favorites.use_mode", "favorites_use_mode")
	useModeCheckBox.OnChange = function(bVal)
		if g_skipChange then -- Very dumb.
			g_skipChange = false
			return
		end
		if bVal != useMode then
			g_skipChange = true
			RunConsoleCommand("spawnmenu_reload")
		end
	end

	self:AddCheckbox("#gmod_favorites.show_save_weapon", "favorites_save_weapon")
	self:AddCheckbox("#gmod_favorites.show_tutorial", "favorites_tutorial")

	self:Open()
end
function drawer:PerformLayout() end
if vgui != nil then vgui.Register("FavoriteOptions", drawer, "DDrawer") end

-- Add our Spawn Menu tab.
if spawnmenu != nil then
	spawnmenu.AddCreationTab("#gmod_favorites.favorites", function()
		g_ctrl = vgui.Create("SpawnmenuContentPanel")
		g_ctrl:CallPopulateHook("PopulateFavorites")
		local sidebar = g_ctrl.ContentNavBar
		sidebar.Options = vgui.Create("FavoriteOptions", sidebar)
		return g_ctrl
	end, "icon16/heart.png", -100)
end

--- Hooks

-- Keep track of the menu state.
local g_menuOpen = false
hook.Add("OnSpawnMenuOpen", "MenuOpen", function() g_menuOpen = true end)
hook.Add("OnSpawnMenuClose", "MenuClose", function() g_menuOpen = false end)

-- This is where we actually favorite things.
-- Every tick we check if the menu is open and if the favorite key is pressed.
-- If these are both true: we grab what the currently hovered VGUI panel is.
-- From there we parse the panel for what type of item it contains, and that
-- items information (unique to each type).
-- I dislike this solution but I see no alternative for the time being.
local g_firstPressed = false
hook.Add("Think", "Favorite", function() -- I wanted to avoid this hook, but it's the only way binds work in singleplayer.
	if g_menuOpen == false then return end

	local cache
	if GetConVar("favorites_use_mode"):GetBool() then cache = LocalPlayer():KeyDown(IN_USE)
	else cache = input.IsButtonDown(GetConVar("favorites_key"):GetInt()) end

	if cache and g_firstPressed then
		local hovered = vgui.GetHoveredPanel()
		if hovered == nil then return end -- No panel hovered.
		-- PrintTable(hovered:GetTable())

		local panelName = hovered:GetName()
		if panelName == "ContentIcon" or panelName == "UCWepSel" then -- Urban Decay is stupid.
			surface.PlaySound("ui/buttonclick.wav")
			local t = hovered:GetTable()

			-- >$CURRENT_YEAR
			-- >no switch statements
			if t.m_Type == "weapon" then
				if t.m_SpawnName == "__dupe" then -- Handle removing dupes.
					table.remove(g_favorites.dupes, Find(g_favorites.dupes, t.m_NiceName))
					SaveRefresh()
					return
				elseif t.m_SpawnName == "__dummy" then return end -- Ignore dummy icons.
				ToggleWeapon(t.m_SpawnName, t.strTooltipText)
				SaveRefresh()
			elseif t.m_Type == "npc" then
				Toggle(g_favorites.npcs, t.m_SpawnName)
				SaveRefresh()
			elseif t.m_Type == "vehicle" or t.m_Type == "simfphys_vehicles" then
				Toggle(g_favorites.vehicles, t:GetSpawnName())
				SaveRefresh()
			elseif t.m_Type == "entity" then
				if t.isPill then Toggle(g_favorites.entities, PillFromPanel(t))
				else Toggle(g_favorites.entities, t.m_SpawnName) end
				SaveRefresh()
			elseif t.m_Type == "pill" then
				Toggle(g_favorites.entities, PillFromPanel(t)) -- Yeah it's kinda an entity, sure whatever.
				SaveRefresh()
			elseif t.m_Type == "material" then
				Toggle(g_favorites.materials, hovered.m_SpawnName)
				SaveRefresh()
			end
		elseif hovered:GetName() == "SpawnIcon" then
			surface.PlaySound("ui/buttonclick.wav")
			local name = hovered:GetModelName()
			if hovered.m_iSkin != 0 then name = name .. ":" .. tostring(hovered.m_iSkin) end -- Append skin ID if any.
			Toggle(g_favorites.props, name)
			SaveRefresh()
		elseif hovered.ClassName == "DHTML" then
			--- This code is utterly fucking cursed.
			--- There should really be a better way to do this than remotely injecting JS to parse the page.
			--- Also, the only way the get the hovered element is by hooking onmousemove. Thanks JS.
			hovered:AddFunction("favorites", "steal", function(r)
				surface.PlaySound("ui/buttonclick.wav")
				Toggle(g_favorites.dupes, r)
				SaveRefresh()
			end)
			hovered:RunJavascript("window.onmousemove = function(e) { favorites.steal(e.target.parentNode.querySelector('name').querySelector('label').innerHTML); window.onmousemove = null; };")
			-- Force a mousemove event. Should be virtually unnoticable to the user.
			local x, y = input.GetCursorPos()
			input.SetCursorPos(x, y + 1)
			input.SetCursorPos(x, y)
		end
	end
	g_firstPressed = not cache
end)

if spawnmenu != nil then RunConsoleCommand("spawnmenu_reload") end -- Reload the Spawn Menu so our changes take effect.
