---- favorties.lua - Clientside entry script.
--- https://github.com/ret-0/gmod_favorites

--- Tier 1: Crashes, Major Performance Problems
--- Tier 2: Non-Fatal Bugs
-- TODO: skinned items
--- Tier 3: Addon Support
-- TODO: fix pills and weather
-- TODO: lfs support (???)
-- TODO: workshop dupes
--- Tier 4: Additional Features
-- TODO: modifiable spawnmenu position
-- TODO: subfolders of folders
-- TODO: rename categories
-- TODO: add custom category for hotbar that modifies it when edited
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
			print(weapon .. " " .. printName)
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
	local json = file.Read(f)
	if json != nil then g_favorites = util.JSONToTable(json)
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

hook.Add("PopulateFavorites", "AddFavoritesContent", function(panelContent, tree, node)
	g_tree = tree -- We save the tree so the favoriting routines can call InternalDoClick() refreshing the page.

	local files, directories = file.Find("favorites/*", "DATA")
	for i, v in ipairs(files) do -- Delete favorites.json wherever it is in the list.
		if v == "favorites.json" then table.remove(files, i) end
	end
	table.insert(files, 1, "favorites.json") -- Prepend favorites.json to the beginning so it is the first category.

	for i, filename in ipairs(files) do
		local name = string.StripExtension(filename:gsub("#%l", string.upper):gsub("#", "")) -- Fix casing and remove extension.
		if filename == "favorites.json" then name = "Favorites" end
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

			local saveCurrentWeapon = GetConVar("favorites_save_weapon"):GetBool()
			if saveCurrentWeapon then
				Header(self, "Weapons")
				local currentWeapon = spawnmenu.CreateContentIcon("weapon", self.PropPanel, {
					nicename	= "Save Current Weapon",
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
				if saveCurrentWeapon == false then Header(self, "Weapons") end

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

				for k, weapon in pairs(g_favorites.weapons) do
					local p = spawnmenu.CreateContentIcon("weapon", self.PropPanel, {
						nicename  = weapon.PrintName or weapon.ClassName,
						spawnname = weapon.ClassName,
						material  = weapon.IconOverride or "entities/" .. weapon.ClassName .. ".png",
						admin     = weapon.AdminOnly
					})
					p.DragHoverClick = function(hoverTime)
						local icon = dragndrop.GetDroppable()[1]
						local t = icon:GetTable()
						if icon:GetName() == "ContentIcon" and t.m_Type == "weapon" then
							-- TODO: re-arrangement
						end
					end
				end
			end

			if table.IsEmpty(g_favorites.props) == false then
				empty = false
				Header(self, "Props")
				-- Removing invalid props is both hard to do, and won't really break anything; just show an error model.
				for k, prop in pairs(g_favorites.props) do
					spawnmenu.CreateContentIcon("model", self.PropPanel, {model = prop})
				end
			end

			if table.IsEmpty(g_favorites.npcs) == false then
				empty = false
				Header(self, "NPCs")

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

				for k, npc in pairs(g_favorites.npcs) do
					local entity = GetEntityFromList("NPC", npc)
					local nameOverride = nil -- Fixes for weird name overlaps.
					if npc == "npc_combine_s" then nameOverride = "Combine Soldier" -- Would be "Combine Elite".
					elseif npc == "npc_vortigaunt" then nameOverride = "Vortigaunt" end -- Would be "Uriah".

					spawnmenu.CreateContentIcon("npc", self.PropPanel, {
						nicename  = nameOverride or entity.Name or npc,
						spawnname = npc,
						material  = entity.IconOverride or "entities/" .. npc .. ".png",
						weapon    = entity.Weapons,
						admin     = entity.AdminOnly
					})
				end
			end

			if table.IsEmpty(g_favorites.vehicles) == false then
				empty = false
				Header(self, "Vehicles")

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

				for k, vehicle in pairs(g_favorites.vehicles) do
					local simfphys = GetEntityFromList("simfphys_vehicles", vehicle)
					local entity = GetEntityFromList("Vehicles", vehicle) or simfphys
					local icon = spawnmenu.CreateContentIcon("vehicle", self.PropPanel, {
						nicename  = entity.Name or vehicle,
						spawnname = vehicle,
						material  = entity.IconOverride or "entities/" .. vehicle .. ".png",
						admin     = entity.AdminOnly
					})
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
				Header(self, "Entities")

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

				for k, e in pairs(g_favorites.entities) do
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
					else
						local entity = GetEntityFromList("SpawnableEntities", e) or
							GetEntityFromList("gDisasters_Equipment", e) or -- "WOULDN'T IT BE FUNNY IF WE HAD 5 SEPERATE LISTS FOR FUCKING ENTITIES :)))"
							GetEntityFromList("gDisasters_Weapons", e)   or
							GetEntityFromList("gDisasters_Weather", e)   or
							GetEntityFromList("gDisasters_Buildings", e) or
							GetEntityFromList("gDisasters_Disasters", e)
						spawnmenu.CreateContentIcon(entity.ScriptedEntityType or "entity", self.PropPanel, {
							nicename  = entity.Name or entity.PrintName or e,
							spawnname = e,
							material  = entity.IconOverride or "entities/" .. e .. ".png",
							admin     = entity.AdminOnly
						})
					end
				end
			end

			if table.IsEmpty(g_favorites.dupes) == false then
				empty = false
				Header(self, "Dupes")
				-- Same deal with dupes, they don't really cause any problems if broken.
				for k, dupe in pairs(g_favorites.dupes) do
					local currentWeapon = spawnmenu.CreateContentIcon("weapon", self.PropPanel, {
						nicename  = dupe,
						spawnname = "__dupe",
						material  = "dupes/" .. dupe .. ".jpg",
						admin     = false
					})
					currentWeapon.DoClick = function()
						surface.PlaySound("ui/buttonclickrelease.wav")
						RunConsoleCommand("dupe_arm", "dupes/" .. dupe .. ".dupe")
					end
				end
			end

			if empty then
				local tutorial = GetConVar("favorites_tutorial"):GetBool()
				if tutorial then
					Text(self,
						"\n" ..
						"You currently don't have anything favorited.\n\n" ..
						"You can favorite an item by pressing E on it in the Spawn Menu.\n" ..
						"You can unfavorite a favorited item the same way.\n" ..
						"Favorited items will be saved to the currently selected category. (The folder on the left.)\n" ..
						"You may create a category by pressing the \"Add Category\" button in the bottom left.\n" ..
						"Clicking \"Save Current Weapon\" will allow you to save a weapon with all of it's ArcCW attachments.\n" ..
						"Your favorites are saved on disk in \"[Garry's Mod Directory]/garrysmod/data/favorites/\".\n" ..
						"If you have any suggestions or errors to report, please comment!\n" ..
						"That's about it, have fun! :^)"
					)
				else Text(self, "You currently don't have anything favorited.") end
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
	self:SetOpenSize(200)
	self:DockPadding(15, 10, 15, 10)

	local text = vgui.Create("DTextEntry", self)
	text:Dock(TOP)
	text:DockMargin(0, 5, 0, 0)
	text:SetPlaceholderText("Name")

	local add = vgui.Create("DButton", self)
	add:Dock(TOP)
	add:DockMargin(0, 5, 0, 0)
	add:SetDark(true)
	add:SetText("Add Category")
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
	del:SetText("Delete Current Category")
	del.DoClick = function()
		if g_file == "favorites/favorites.json" then return end
		file.Delete(g_file)
		RunConsoleCommand("spawnmenu_reload")
		print("Deleted " .. g_file .. "!")
	end

	local bLabel = vgui.Create("DLabel", self)
	bLabel:Dock(TOP)
	bLabel:DockMargin(0, 0, 0, 0)
	bLabel:SetSize(25, 25)
	bLabel:SetTextColor(Color(0, 0, 0))
	bLabel:SetText("Favorite Key Bind:")
	local binder = vgui.Create("DBinder", self)
	binder:Dock(TOP)
	binder:DockMargin(0, 0, 0, 0)
	binder:SetSize(20, 20)
	binder:SetValue(GetConVar("favorites_key"):GetInt())
	function binder:OnChange(key) RunConsoleCommand("favorites_key", tostring(key)) end
	local useMode = GetConVar("favorites_use_mode"):GetBool()
	if useMode then binder:SetEnabled(false) end
	local useModeCheckBox = self:AddCheckbox("+use Mode", "favorites_use_mode")
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

	self:AddCheckbox("Show \"Save Current Weapon\"?", "favorites_save_weapon")
	self:AddCheckbox("Show tutorial?", "favorites_tutorial")

	self:Open()
end
function drawer:PerformLayout() end
if vgui != nil then vgui.Register("FavoriteOptions", drawer, "DDrawer") end

-- Add our Spawn Menu tab.
if spawnmenu != nil then
	spawnmenu.AddCreationTab("Favorites", function()
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
			end
		elseif hovered:GetName() == "SpawnIcon" then
			surface.PlaySound("ui/buttonclick.wav")
			Toggle(g_favorites.props, hovered:GetModelName())
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
