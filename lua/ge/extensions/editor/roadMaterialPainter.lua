-- Road Material Painter Extension
-- Written by Stuffi3000
-- bCDDL v1.1

local M = {}
local im = ui_imgui
local ffi = require('ffi')
local toolWindowName = "editor_roadMaterialPainter_window"

local decalRoadTypes = {"DecalRoad"}
local decalRoadIds = {}

-- For window state
if not M.selectedTerrainMaterialIdx then
  M.selectedTerrainMaterialIdx = im.IntPtr(0)
end

local function getSelection(classNames)
  local ids = {}
  if editor.selection and editor.selection.object then
    for _, currId in ipairs(editor.selection.object) do
      local obj = scenetree.findObjectById(currId)
      if obj and (not classNames or arrayFindValueIndex(classNames, obj.className)) then
        table.insert(ids, currId)
      end
    end
  end
  return ids
end

local function onEditorGui()
  if not editor.isWindowVisible(toolWindowName) then return end
  if editor.beginWindow(toolWindowName, "Road Material Painter") then
    im.Text("Tool to paint a terrain material underneath selected DecalRoad(s).")
    im.Spacing()

    -- Select DecalRoad from selection
    local decalRoadListStr = ""
    for i, id in ipairs(decalRoadIds) do
      if editor.uiIconImageButton(editor.icons.check_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0])) then
        editor.selectEditMode(editor.editModes.objectSelect)
        editor.selectObjectById(id)
        editor.fitViewToSelectionSmooth()
      end
      im.SameLine()
      local obj = scenetree.findObjectById(id)
      local decalRoadName = obj and tostring(obj:getName()) or tostring(id)
      decalRoadListStr = decalRoadListStr .. decalRoadName .. " [" .. id .. "]"
      if i < #decalRoadIds then decalRoadListStr = decalRoadListStr .. "\n" end
    end
    im.TextWrapped(decalRoadListStr)
    if im.Button("Get DecalRoad(s) from Selection##terrainMatPainter") then
      decalRoadIds = getSelection(decalRoadTypes)
    end
    im.tooltip("Collect currently selected DecalRoad(s) from the World Editor.")
    if #decalRoadIds > 0 and im.Button("Clear Selected Roads##terrainMatPainter") then
      decalRoadIds = {}
    end
    im.Separator()

    -- List available terrain materials in combobox
    local terrainEditor = extensions.editor_terrainEditor
    local materialNames, materialIndices, materialNamePtrs, proxies = {}, {}, nil, nil
    if terrainEditor and terrainEditor.getPaintMaterialProxies then
      proxies = terrainEditor.getPaintMaterialProxies()
      for i, proxy in ipairs(proxies) do
        table.insert(materialNames, proxy.internalName)
        table.insert(materialIndices, proxy.index or (terrainEditor.getTerrainBlockMaterialIndex and terrainEditor.getTerrainBlockMaterialIndex(proxy.internalName)) or i)
      end
    end
    if #materialNames > 0 then
      materialNamePtrs = im.ArrayCharPtrByTbl(materialNames)
      im.Combo1("Terrain Material", M.selectedTerrainMaterialIdx, materialNamePtrs)
    else
      im.Text("No terrain materials available.")
    end

    -- Edge painting margin
    if not M.edgeMargin then M.edgeMargin = im.FloatPtr(1.0) end
    im.InputFloat("Edge Margin (m)", M.edgeMargin, 0.1)
    im.tooltip("Paints this much extra distance to each side of the road (meters). Increase to cover more terrain.")

    
    -- Paint operation
    if im.Button("Paint Material Under Road##terrainMatPainter") then
      local terrainBlock = terrainEditor.getTerrainBlock and terrainEditor.getTerrainBlock() or nil
      if terrainBlock and #decalRoadIds > 0 and #materialNames > 0 then
        local painter = require("editor/toolUtilities/terrainPainter")
        local matListIdx = M.selectedTerrainMaterialIdx[0] + 1
        local matName = materialNames[matListIdx]
        local paintMaterialIdx = ((materialIndices[matListIdx] or 1) - 1) -- Convert material index from 1-based (UI/proxy) to 0-based (terrain indices)
        local paintMargin = M.edgeMargin[0] or 1.0
        for _, decalRoadId in ipairs(decalRoadIds) do
          local road = scenetree.findObjectById(decalRoadId)
          if road then
            local nodes = editor.getNodes(road)
            if #nodes >= 2 then
              -- Use existing DecalRoad API (engine's own sampling)
              local divPoints, binormals, divWidths = {}, {}, {}
              local edgeCount = road.getEdgeCount and road:getEdgeCount() or 0
              if edgeCount and edgeCount >= 2 and road.getLeftEdgePosition and road.getRightEdgePosition and road.getMiddleEdgePosition then
                for ei = 0, edgeCount - 1 do
                  local l = road:getLeftEdgePosition(ei)
                  local r = road:getRightEdgePosition(ei)
                  local m = road:getMiddleEdgePosition(ei)
                  local dx, dy = (r.x - l.x), (r.y - l.y)
                  local len = math.sqrt(dx * dx + dy * dy)
                  if len < 1e-12 then len = 1 end
                  local bin = { x = dx / len, y = dy / len, z = 0 } -- left->right vector normalized
                  table.insert(divPoints, vec3(m.x, m.y, m.z))
                  table.insert(binormals, bin)
                  table.insert(divWidths, len)
                end
              end
              local group = {
                divPoints = divPoints,
                binormals = binormals,
                divWidths = divWidths,
                paintMaterialIdx = paintMaterialIdx,
                paintMargin = paintMargin,
                nodes = nodes,
                paintedDataVals = {},
                paintedDataX = {},
                paintedDataY = {},
                paintedDataBoxXMin = 0,
                paintedDataBoxXMax = 0,
                paintedDataBoxYMin = 0,
                paintedDataBoxYMax = 0
              }
              painter.paint(group)
              log('I', 'terrainMatPainter', "Painted material '" .. matName .. "' under road id " .. tostring(decalRoadId))
            end
          end
        end
      end
    end
    im.tooltip("Will use the terrain system to paint the selected material under the selected road(s) path (with the selected edge margin).")

    -- Terraforming section
    im.Separator()
    im.HeaderText("Terraforming")
    if not M.terraMargin then M.terraMargin = im.FloatPtr(1.0) end
    im.InputFloat("Terraform Margin (m)", M.terraMargin, 0.1)
    im.tooltip("Extra lateral distance to terraform on each side of the road (meters).")

    if not M.terraDOI then M.terraDOI = im.IntPtr(30) end
    im.InputInt("Domain of Influence (m)", M.terraDOI)
    im.tooltip("Maximum distance from the road that is affected by terraforming. Larger values create broader blends.")

    if im.Button("Terraform Terrain Under Road##terrainMatPainter") then
      local terrainBlock = terrainEditor.getTerrainBlock and terrainEditor.getTerrainBlock() or nil
      if terrainBlock and #decalRoadIds > 0 then
        local terra = require('editor/terraform/terraform')
        local DOI, falloff, roughness, scale = ((M.terraDOI and M.terraDOI[0]) or 30), 2.0, 0.0, 0.5
        local sources = {}
        for _, decalRoadId in ipairs(decalRoadIds) do
          local road = scenetree.findObjectById(decalRoadId)
          if road then
            local nodes = editor.getNodes(road)
            if #nodes >= 2 then
              local divPoints, binormals, divWidths = {}, {}, {}
              local edgeCount = road.getEdgeCount and road:getEdgeCount() or 0
              if edgeCount and edgeCount >= 2 and road.getLeftEdgePosition and road.getRightEdgePosition and road.getMiddleEdgePosition then
                for ei = 0, edgeCount - 1 do
                  local l = road:getLeftEdgePosition(ei)
                  local r = road:getRightEdgePosition(ei)
                  local m = road:getMiddleEdgePosition(ei)
                  local dx, dy = (r.x - l.x), (r.y - l.y)
                  local len = math.sqrt(dx * dx + dy * dy)
                  if len < 1e-12 then len = 1 end
                  local bin = { x = dx / len, y = dy / len, z = 0 }
                  table.insert(divPoints, vec3(m.x, m.y, m.z))
                  table.insert(binormals, bin)
                  table.insert(divWidths, len)
                end
              end
              if #divPoints > 1 then
                local src = {}
                for i = 1, #divPoints do
                  src[i] = { pos = divPoints[i], width = divWidths[i], binormal = vec3(binormals[i].x, binormals[i].y, binormals[i].z or 0) }
                end
                table.insert(sources, src)
              end
            end
          end
        end
        if #sources > 0 then
          local margin = M.terraMargin[0] or 1.0
          terra.terraformToSources(DOI, margin, falloff, roughness, scale, sources)
          log('I', 'terrainMatPainter', "Terraformed terrain under selected road(s) with margin " .. string.format('%.2f', margin))
        end
      end
    end
    im.tooltip("Will terraform the terrain under the selected road(s) with the given margin.")

    im.Spacing()
    im.HeaderText("How to use:")
    im.Text("1. Collect DecalRoads from your world selection.")
    im.Text("2. Select the terrain material you wish to paint.")
    im.Text("3. Click the Paint button.")
    im.Text("4. Done!")
    im.HeaderText("Credits")
    im.Text("Extension written by Stuffi3000, licenced under bCDDL v1.1.")

  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(460, 320))
  editor.addWindowMenuItem("Road Material Painter", onWindowMenuItem)
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui

return M
