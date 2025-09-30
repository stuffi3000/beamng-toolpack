-- Road-edge Generator v1.1
-- Written by Stuffi3000
--
-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_roadEdgeGenerator' -- this is used for logging as a tag
local im = ui_imgui -- shortcut for imgui
local ffi = require('ffi')
local toolWindowName = "editor_roadEdgeGenerator_window"

-- For save/load
local FS = FS or require('filesystem')
local settingsPath = "settings/roadedgegenerator_profiles.json"

local function loadProfiles()
  local profiles = {}
  local ok, f = pcall(function() return io.open(settingsPath, "r") end)
  if ok and f then
    local data = f:read("*a")
    f:close()
    local decoded = jsonDecode(data)
    if decoded and type(decoded) == "table" then
      profiles = decoded
    end
  end
  return profiles
end

local function saveProfiles(profiles)
  local ok, f = pcall(function() return io.open(settingsPath, "w") end)
  if ok and f then
    f:write(jsonEncode(profiles))
    f:close()
  end
end

local decalRoadId, decalRoadErrorTxt
local decalRoadTypes = {"DecalRoad"} -- sensible road object classes
local savedParams = {}
local roadEdgeWidth = im.FloatPtr(1.0)
local overlap = im.FloatPtr(0.01)
local textureLength = im.IntPtr(5)
local renderPriority = im.IntPtr(10)
local startFade = im.FloatPtr(0.1)
local endFade = im.FloatPtr(0.1)
local materialName = im.ArrayChar(128)
local invertEdgePlacement = im.BoolPtr(false)
local randomisePosition = im.BoolPtr(false)
local overObjects = im.BoolPtr(false)
local decalRoadIds = {}
local sideSelection = 0

-- Function for calculating the vector between two points in 3D space
local function calculateVector(point1, point2)
  local vector = {x = point2.x - point1.x, y = point2.y - point1.y, z = point2.z - point1.z}
  return vector
end

-- Function for calculating the length of a vector in 3D space
local function vectorLength(vector)
  return math.sqrt(vector.x^2 + vector.y^2 + vector.z^2)
end

-- Function for normalising a vector in 3D space
local function normalizeVector(vector)
  local length = vectorLength(vector)
  return {x = vector.x / length, y = vector.y / length, z = vector.z / length}
end

-- Function for calculating the vector by 90 degrees in 3D space
local function rotateVector(vector)
  if sideSelection == 0 then
    local x = -vector.y
    local y = vector.x
    local z = vector.z
    return {x = x, y = y, z = z}
  end
  if sideSelection == 1 then
    local x = vector.y
    local y = -vector.x
    local z = vector.z
    return {x = x, y = y, z = z}
  end
end

-- Function for calculating a new point at a certain distance from a given point in 3D space
local function calculateNewPoint(point, directionVector, distance)
  local random_var_x = 0
  local random_var_y = 0
  if savedParams.randomisePosition == true then
    random_var_x = math.random(-0.2, 0.2)
    random_var_y = math.random(-0.2, 0.2)
  end
  local x = (point.x + directionVector.x * distance) + random_var_x
  local y = (point.y + directionVector.y * distance) + random_var_y
  local z = point.z + directionVector.z * distance
  return vec3(x, y, z)
end

local function getSelection(classNames)
    local ids = {} -- Store multiple RoadIds in a table
    if editor.selection and editor.selection.object then
      for _, currId in ipairs(editor.selection.object) do
        if not classNames or arrayFindValueIndex(classNames, scenetree.findObjectById(currId).className) then
          table.insert(ids, currId)
        end
      end
    end
    return ids
end

local function onEditorGui()
  if not editor.isWindowVisible(toolWindowName) then return end
    -----------------------
    -- WINDOW START
    -----------------------
  if editor.beginWindow(toolWindowName, "Road-edge Generator Window") then
    if decalRoadId and not scenetree.findObjectById(decalRoadId) then
      decalRoadId = nil
    end

    im.Text("Extension for the World Editor to automatically generate road-edges.")
    im.Text("")

    -- Profile management UI
    im.Text("Profile:")
    if not savedParams.profiles then
      savedParams.profiles = loadProfiles()
      savedParams.currentProfile = nil
    end
    local profileNames = {}
    for k, _ in pairs(savedParams.profiles) do table.insert(profileNames, k) end
    table.sort(profileNames)
    local currentProfileStr = savedParams.currentProfile or "<none>"
    local preview_value = currentProfileStr
    if im.BeginCombo("Profiles", preview_value, 0) then
      -- List profiles
      for i, name in ipairs(profileNames) do
        local selected = (currentProfileStr == name)
        if im.Selectable1(name, selected) then
          savedParams.currentProfile = name
          -- Load profile params
          for k,v in pairs(savedParams.profiles[name]) do
            savedParams[k] = v
          end
          -- Update ImGui pointers with loaded values
          roadEdgeWidth[0]      = savedParams.roadEdgeWidth or 1.0
          overlap[0]            = savedParams.overlap or 0.01
          startFade[0]          = savedParams.startFade or 0.1
          endFade[0]            = savedParams.endFade or 0.1
          textureLength[0]      = savedParams.textureLength or 5
          renderPriority[0]     = savedParams.renderPriority or 10
          invertEdgePlacement[0]= savedParams.invertEdgePlacement or false
          overObjects[0]        = savedParams.overObjects or false
          randomisePosition[0]  = savedParams.randomisePosition or false
          ffi.copy(materialName, savedParams.materialName or "")
        end
      end
      im.Separator()
      -- Save current as new profile option
      if im.Selectable1("Save current as new profile", false) then
        local newName = os.date(savedParams.materialName .. "_%d%m%Y_%H%M%S")
        savedParams.profiles[newName] = {
          roadEdgeWidth = savedParams.roadEdgeWidth,
          overlap = savedParams.overlap,
          startFade = savedParams.startFade,
          endFade = savedParams.endFade,
          materialName = savedParams.materialName,
          textureLength = savedParams.textureLength,
          renderPriority = savedParams.renderPriority,
          invertEdgePlacement = savedParams.invertEdgePlacement,
          overObjects = savedParams.overObjects,
          randomisePosition = savedParams.randomisePosition
        }
        saveProfiles(savedParams.profiles)
        savedParams.currentProfile = newName
      end
      im.EndCombo()
    end
    if im.IsItemHovered() then
      im.BeginTooltip()
      im.Text("Select a profile to load, or save the current parameters as a new profile.")
      im.EndTooltip()
    end
    
    im.Text("Parameters:")
  
    im.Columns(1)
  
    im.InputFloat("Road-edge width", roadEdgeWidth, 1.0)
    im.tooltip("The width to assign to a newly generated road-edge.\n\n(Default: 1)")
    im.InputFloat("Overlap/Offset width", overlap, 0.01, savedParams.roadEdgeWidth)
    if im.IsItemHovered() then
      im.BeginTooltip()
      im.TextColored(im.ImVec4(0.0, 1.0, 0.0, 1.0), "[Positive Value]")
      im.Text("A positive value creates an overlap between the DecalRoad and the road-edge.\n")
      im.TextColored(im.ImVec4(1.0, 1.0, 0.0, 1.0), "[Negative Value]")
      im.Text("A negative value creates an offset between the DecalRoad and the road-edge.\n\n(Default: 0.01)")
      im.EndTooltip()
    end
    im.InputText("Material Name", materialName)
    local input = ffi.string(materialName)
    im.tooltip("The name of the material to be assigned to the road-edge.\n\n(Default: NoMaterial)")
    im.InputInt("Texture Length", textureLength)
    im.tooltip("Texture Length of the road-edge.\n\n(Default: 5)")
    im.InputInt("Render Priority", renderPriority)
    im.tooltip("Render Priority of the road-edge.\n\n(Default: 10)")
    im.InputFloat("Start Fade", startFade, 0.1)
    im.tooltip("Start Fade of the road-edge.\n\n(Default: 0.1)")
    im.InputFloat("End Fade", endFade, 0.1)
    im.tooltip("End Fade of the road-edge.\n\n(Default: 0.1)")
    im.Text("Side on which the edge-road should be placed: ")
    if im.IsItemHovered() then
      im.BeginTooltip()
      im.TextColored(im.ImVec4(1.0, 1.0, 0.0, 1.0), "[LEFT]")
      im.Text("The road-edge will be placed on the left side of the DecalRoad, starting at the first node of said road.\n")
      im.TextColored(im.ImVec4(1.0, 1.0, 0.0, 1.0), "[RIGHT]")
      im.Text("The road-edge will be placed on the right side of the DecalRoad, starting at the first node of said road.\n\n(Default: Left)")
      im.EndTooltip()
    end
    if im.Selectable1("Left", sideSelection == 0) then
      sideSelection = 0
    end
    if im.Selectable1("Right", sideSelection == 1) then
      sideSelection = 1
    end
    im.Checkbox("Invert edge placement", invertEdgePlacement)
    if im.IsItemHovered() then
      im.BeginTooltip()
      im.TextColored(im.ImVec4(0.0, 1.0, 0.0, 1.0), "[ENABLED]")
      im.Text("The road-edge node-placing logic will be inverted: the first node is placed at the end of the DecalRoad and the last node at the start of the DecalRoad.\n")
      im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), "[DISABLED]")
      im.Text("The road-edge node-placing logic follows the DecalRoad.\n")
      im.TextColored(im.ImVec4(1.0, 1.0, 0.0, 1.0), "[EXPLANATION]")
      im.Text("In some instances, it's possible that a road-edge material only allows an edge to be placed on one side of the road, and not on the other.\nExample: 'dirt_road_edge_grassy_d' can only be placed on the left when you're hovering above a road.\n\nIF YOUR MATERIAL IS ONE-EDGE-SIDE ONLY: Make sure to select the side that corresponds to your material above before inverting!\n\n(Default: Off)")
      im.EndTooltip()
    end
    im.Checkbox("Over Objects", overObjects)
    im.tooltip("Turns on the OverObjects setting.")
    im.Checkbox("Randomise node placement", randomisePosition)
    im.tooltip("Adds a random number between -0.2 and +0.2 to the X and Y positions of all generated nodes.\n\n(Default: Disabled)")

    savedParams.roadEdgeWidth = roadEdgeWidth[0]
    savedParams.overlap = overlap[0]
    savedParams.startFade = startFade[0]
    savedParams.endFade = endFade[0]
    savedParams.materialName = input
    savedParams.textureLength = textureLength[0]
    savedParams.renderPriority = renderPriority[0]
    savedParams.invertEdgePlacement = invertEdgePlacement[0]
    savedParams.overObjects = overObjects[0]
    savedParams.randomisePosition = randomisePosition[0]

    im.Text(" ")
    im.NextColumn()

    -----------------------
    -- DECAL ROAD SELECTION
    -----------------------

    local str = "none"
    im.TextUnformatted("DecalRoad: ")
    editor.uiIconImage(editor.icons.create_road_decal, im.ImVec2(45 * im.uiscale[0], 45 * im.uiscale[0]))
    im.NextColumn()

    local decalRoadListStr = ""
    for i, id in ipairs(decalRoadIds) do
      if editor.uiIconImageButton(editor.icons.check_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0])) then
        editor.selectEditMode(editor.editModes.objectSelect)
        editor.selectObjectById(id)
        editor.fitViewToSelectionSmooth()
      end
      im.SameLine()
      local decalRoadName = tostring(scenetree.findObjectById(id):getName())
      decalRoadListStr = decalRoadListStr .. decalRoadName .. " [" .. id .. "]"
      if i < #decalRoadIds then
        decalRoadListStr = decalRoadListStr .. "\n"
      end
    end

    im.TextWrapped(decalRoadListStr)
    --im.SameLine()
    if im.Button("Get from Selection##decal") then
      decalRoadIds = getSelection(decalRoadTypes)
      if #decalRoadIds > 0 then
        decalRoadErrorTxt = nil
      else
        decalRoadErrorTxt = "Needs: DecalRoad"
      end
    end
    im.tooltip("Select the DecalRoad you want to generate and edge for")
    if #decalRoadIds > 0 then
      if im.Button("Unselect Decal") then
        decalRoadIds = {}
      end
    end
    if decalRoadErrorTxt then
      im.SameLine()
      im.TextColored(im.ImVec4(1, 1, 0, 1), decalRoadErrorTxt)
    end  

    if im.Button("Generate Road-edge") then
        for _, decalRoadId in ipairs(decalRoadIds) do
            if decalRoadId then
              local oldDecalRoad = scenetree.findObjectById(decalRoadId)
              local newEdgeNodes = editor.getNodes(oldDecalRoad)
              if not roadEdgeWidth then
                roadEdgeWidth = 1
              end
              local numNodes = #newEdgeNodes
              if savedParams.invertEdgePlacement == true then
                for i = 1, math.floor(numNodes / 2) do
                  newEdgeNodes[i], newEdgeNodes[numNodes - i + 1] = newEdgeNodes[numNodes - i + 1], newEdgeNodes[i]
                end
              end
              for i = 1, #newEdgeNodes do
                local decalRoadWidth = newEdgeNodes[i].width
                local vector
                if i < #newEdgeNodes then
                    vector = calculateVector(newEdgeNodes[i].pos, newEdgeNodes[i+1].pos)
                    log('I', logTag, 'Normal point, not the last one')
                else
                    vector = calculateVector(newEdgeNodes[i-1].pos, newEdgeNodes[i].pos)
                    log('I', logTag, 'the IF fires!')
                end
                local length = vectorLength(vector)
                local normalizedVector = normalizeVector(vector)
                local perpendicularVector = rotateVector(normalizedVector)
                local edgeNodeDistance = (decalRoadWidth/2 + savedParams.roadEdgeWidth/2) - savedParams.overlap
                --log('I', logTag, 'savedParams.roadEdgeWidth: ' .. tostring(savedParams.roadEdgeWidth))
                --log('I', logTag, 'edgeNodeDistance: ' .. tostring(edgeNodeDistance))
                local newPos = calculateNewPoint(newEdgeNodes[i].pos, perpendicularVector, edgeNodeDistance)
                newEdgeNodes[i].pos = newPos
                newEdgeNodes[i].width = tonumber(savedParams.roadEdgeWidth)
            end
              local newDecalRoadId = editor.createRoad(newEdgeNodes, {})
              editor.setFieldValue(newDecalRoadId, "Material", savedParams.materialName)
              --log('I', logTag, 'materialName: ' .. savedParams.materialName)
              editor.setFieldValue(newDecalRoadId, "textureLength", savedParams.textureLength)
              editor.setFieldValue(newDecalRoadId, "renderPriority", savedParams.renderPriority)
              editor.setFieldValue(newDecalRoadId, "startEndFade", tostring(savedParams.startFade .. " " .. savedParams.endFade))
              if savedParams.overObjects == true then
                editor.setFieldValue(newDecalRoadId, "overObjects", 1)
              end
              decalRoadIds = {}
            end
        end
    end
    im.NextColumn()
    im.TextUnformatted(" ")
    im.Separator()

    -----------
    -- NOTES
    -----------

    im.Columns(1)
    im.HeaderText("How to use")
    im.Text("1. Select parameters")
    im.Text("2. Select one or multiple DecalRoads in World Editor")
    im.Text("3. Click on the 'Get from Selection' button")
    im.Text("4. Generate road-edge")
    im.Text("5. Profit!")
    im.HeaderText("Credits")
    im.Text("Extension written by Stuffi3000, licenced under bCDDL v1.1.")
  end
  editor.endWindow()
end


local function onWindowMenuItem()
    editor.showWindow(toolWindowName)
end
  
local function onEditorInitialized()
    -- Load profiles when editor initializes
    savedParams.profiles = loadProfiles()
    if not savedParams.profiles then savedParams.profiles = {} end
    editor.registerWindow(toolWindowName, im.ImVec2(800, 300))
    editor.addWindowMenuItem("Road-edge Generator", onWindowMenuItem)
end
  
M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
  
return M