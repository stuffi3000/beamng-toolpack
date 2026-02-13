-- Written by Stuffi3000
--
-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt


local M = {}
local logTag = 'editor_meshDecalRoadConvert' -- this is used for logging as a tag
local im = ui_imgui -- shortcut for imgui
local toolWindowName = "meshDecalRoadConvert_window"

local meshRoadId, meshRoadErrorTxt, decalRoadId, decalRoadErrorTxt
local meshRoadTypes = {"MeshRoad"} -- sensible road object classes
local decalRoadTypes = {"DecalRoad"} -- sensible road object classes
local savedParams = {}
local deleteOld = im.BoolPtr(false)
local newMeshDepth = im.IntPtr(2)
local copyAllPossible = im.BoolPtr(true)
local copyMaterial = im.BoolPtr(true)
local rebuildCollision = im.BoolPtr(false)
local moveOriginToZero = im.BoolPtr(false)
local meshRoadIds = {}
local decalRoadIds = {}

-- Move a newly created road/mesh origin to world 0 0 0 while keeping all nodes in their original
-- world positions.
--
-- Node positions exposed by getNodePosition()/editor.getNodes are treated as world space by the
-- editor (see roadEditor.lua / meshEditor.lua). That means when we change the object's origin
-- (position field), we must re-apply node positions so their world coordinates remain unchanged.
local function moveOriginToZeroKeepNodes(objectId, desiredNodes)
  if not objectId or not desiredNodes then return end
  local obj = scenetree.findObjectById(objectId)
  if not obj then return end

  -- Set origin to world zero.
  editor.setFieldValue(objectId, "position", "0 0 0")

  -- Re-apply node properties (most importantly world positions).
  for i, node in ipairs(desiredNodes) do
    local nodeId = i - 1
    if node.pos then
      editor.setNodePosition(obj, nodeId, node.pos)
    end
    if node.width then
      editor.setNodeWidth(obj, nodeId, node.width)
    end
    if node.depth and obj.setNodeDepth then
      editor.setNodeDepth(obj, nodeId, node.depth)
    end
    if node.normal and obj.setNodeNormal then
      obj:setNodeNormal(nodeId, node.normal)
    end
  end
  editor.setDirty()
end

local function getRoadBaseName(roadId, suffix, fallbackBase)
  local name = editor.getFieldValue(roadId, "name")
  if not name or name == "" then
    local obj = scenetree.findObjectById(roadId)
    if obj and obj.getName then
      name = tostring(obj:getName())
    end
  end
  if not name or name == "" then
    name = fallbackBase
  end
  if not name:match(suffix .. "$") then
    name = name .. suffix
  end
  return name
end

local function generateUniqueRoadName(baseName, objectIdToIgnore)
  local uniqueName = baseName
  local suffixIndex = 1
  local existing = scenetree.findObject(uniqueName)
  while existing and (not objectIdToIgnore or not existing.getID or existing:getID() ~= objectIdToIgnore) do
    uniqueName = string.format("%s_%d", baseName, suffixIndex)
    suffixIndex = suffixIndex + 1
    existing = scenetree.findObject(uniqueName)
  end
  return uniqueName
end

local function getSelection(classNames)
  local ids = {} -- Store multiple meshRoadIds in a table
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
  if editor.beginWindow(toolWindowName, "Mesh-Decal Road Convert Window") then
    if meshRoadId and not scenetree.findObjectById(meshRoadId) then
      meshRoadId = nil
    end
    if decalRoadId and not scenetree.findObjectById(decalRoadId) then
      decalRoadId = nil
    end

    im.Columns(1)

    im.InputInt("New MeshRoad Depth", newMeshDepth)
    im.tooltip("The depth to assign to a newly created MeshRoad. Necessary, because a DecalRoad has no depth.\n(Default: 2)")
    im.Checkbox("Delete old road", deleteOld)
    im.tooltip("Once the new MeshRoad or DecalRoad has been created, the old DecalRoad or Meshroad will be deleted.\n(Default: disabled)")
    im.Checkbox("Copy all possible fields", copyAllPossible)
    if im.IsItemHovered() then
      im.BeginTooltip()
      im.TextColored(im.ImVec4(0.0, 1.0, 0.0, 1.0), "[Enabled]")
      im.Text("Copies name, position, rotation, scale, texture lenght and break angle (default).\n\n")
      im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), "[Disabled]")
      im.Text("Copies only name, position, rotation and scale.")
      im.EndTooltip()
    end
    im.Checkbox("Copy material", copyMaterial)
    if im.IsItemHovered() then
      im.BeginTooltip()
      im.TextColored(im.ImVec4(1.0, 1.0, 0.0, 1.0), "[Decal to Mesh]")
      im.Text("Copies material - Pastes into all 3 mesh material slots\n\n")
      im.TextColored(im.ImVec4(1.0, 1.0, 0.0, 1.0), "[Mesh to Decal]")
      im.Text("Copies TopMaterial - Pastes into material slot")
      im.Text("(Default: enabled)")
      im.EndTooltip()
    end
    im.Checkbox("Rebuild Collision", rebuildCollision)
    im.tooltip("Rebuild collision after a new MeshRoad was created or an old one was deleted. Useful if collision is tested without closing the editor.\n(Default: disabled) (can cause lag)")

    im.Checkbox("Move origin to 0,0,0", moveOriginToZero)
    im.tooltip("When enabled, newly created MeshRoads/DecalRoads will have their origin at world position 0 0 0 while keeping all nodes in their original positions.")

    savedParams.newMeshDepth = newMeshDepth[0]
    savedParams.deleteOld = deleteOld[0]
    savedParams.copyAllPossible = copyAllPossible[0]
    savedParams.copyMaterial = copyMaterial[0]
    savedParams.rebuildCollision = rebuildCollision[0]
    savedParams.moveOriginToZero = moveOriginToZero[0]
    im.NextColumn()

    im.Columns(2)
    im.SetColumnWidth(0, 100)
    
    -----------------------
    -- MESH ROAD SELECTION
    -----------------------
    local str = "none"
    im.TextUnformatted("MeshRoad: ")
    editor.uiIconImage(editor.icons.create_road_mesh, im.ImVec2(45 * im.uiscale[0], 45 * im.uiscale[0]))
    im.NextColumn()

    local meshRoadListStr = ""
    for i, id in ipairs(meshRoadIds) do
      if editor.uiIconImageButton(editor.icons.check_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0])) then
        editor.selectEditMode(editor.editModes.objectSelect)
        editor.selectObjectById(id)
        editor.fitViewToSelectionSmooth()
      end
      im.SameLine()
      local meshRoadName = tostring(scenetree.findObjectById(id):getName())
      meshRoadListStr = meshRoadListStr .. meshRoadName .. " [" .. id .. "]"
      if i < #meshRoadIds then
        meshRoadListStr = meshRoadListStr .. "\n"
      end
    end

    im.TextWrapped(meshRoadListStr)
    im.SameLine()
    if im.Button("Get from Selection##mesh") then
      meshRoadIds = getSelection(meshRoadTypes)
      if #meshRoadIds > 0 then
        meshRoadErrorTxt = nil
      else
        meshRoadErrorTxt = "Needs: MeshRoad"
      end
    end
    im.tooltip("Select the MeshRoad you want to convert")
    if #meshRoadIds > 0 then
      if im.Button("Unselect Mesh") then
        meshRoadIds = {}
      end
    end
    if meshRoadErrorTxt then
      im.SameLine()
      im.TextColored(im.ImVec4(1, 1, 0, 1), meshRoadErrorTxt)
    end

    if im.Button("Convert to DecalRoad") then
      for _, meshRoadId in ipairs(meshRoadIds) do
        if meshRoadId then
          local oldMeshRoad = scenetree.findObjectById(meshRoadId)
          local newDecalNodes = editor.getNodes(oldMeshRoad)
          local requestedName = getRoadBaseName(meshRoadId, "_decalRoad", "DecalRoad")

          for _, v in pairs(newDecalNodes) do
            v["depth"] = nil
            v["normal"] = nil
          end

          local newDecalRoadId = editor.createRoad(newDecalNodes, {})
          local position, rotation, scale, material

          if savedParams.copyAllPossible == false then
            position = editor.getFieldValue(meshRoadId, "position")
            rotation = editor.getFieldValue(meshRoadId, "rotation")
            scale = editor.getFieldValue(meshRoadId, "scale")
            if savedParams.moveOriginToZero ~= true then
              editor.setFieldValue(newDecalRoadId, "position", position)
            end
            editor.setFieldValue(newDecalRoadId, "rotation", rotation)
            editor.setFieldValue(newDecalRoadId, "scale", scale)
          end

          -- Optionally move origin to (0,0,0) while keeping nodes in place
          if savedParams.moveOriginToZero == true then
            moveOriginToZeroKeepNodes(newDecalRoadId, newDecalNodes)
          end

          if savedParams.copyMaterial == true then
            material = editor.getFieldValue(meshRoadId, "topMaterial")
            editor.setFieldValue(newDecalRoadId, "Material", material)
          end
          editor.pasteFields(editor.copyFields(meshRoadId), newDecalRoadId)
          editor.setFieldValue(newDecalRoadId, "name", generateUniqueRoadName(requestedName, newDecalRoadId))

          if savedParams.deleteOld == true then
            editor.deleteMesh(meshRoadId)
          end
          if savedParams.rebuildCollision == true then
            be:reloadCollision()
          end
          meshRoadIds = {}
        end
      end
    end
    im.NextColumn()
    im.TextUnformatted(" ")
    im.Separator()

    -----------------------
    -- DECAL ROAD SELECTION
    -----------------------
    str = "none"
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
    im.SameLine()
    if im.Button("Get from Selection##decal") then
      decalRoadIds = getSelection(decalRoadTypes)
      if #decalRoadIds > 0 then
        decalRoadErrorTxt = nil
      else
        decalRoadErrorTxt = "Needs: DecalRoad"
      end
    end
    im.tooltip("Select the DecalRoad you want to convert")
    if #decalRoadIds > 0 then
      if im.Button("Unselect Decal") then
        decalRoadIds = {}
      end
    end
    if decalRoadErrorTxt then
      im.SameLine()
      im.TextColored(im.ImVec4(1, 1, 0, 1), decalRoadErrorTxt)
    end

    if im.Button("Convert to MeshRoad") then
      for _, decalRoadId in ipairs(decalRoadIds) do
        if decalRoadId then
          local oldDecalRoad = scenetree.findObjectById(decalRoadId)
          local newMeshNodes = editor.getNodes(oldDecalRoad)
          local requestedName = getRoadBaseName(decalRoadId, "_meshRoad", "MeshRoad")

          if not newMeshDepth then
            newMeshDepth = 2
          end
          for k, v in pairs(newMeshNodes) do
            v["depth"] = savedParams.newMeshDepth
            v["normal"] = vec3(0,0,1)
            log('I', logTag, 'This node is now: ' .. tostring(v))
          end

          local newMeshRoadId = editor.createMesh("MeshRoad", newMeshNodes, {})
          local position, rotation, scale, material
          if savedParams.copyAllPossible == false then
            position = editor.getFieldValue(decalRoadId, "position")
            rotation = editor.getFieldValue(decalRoadId, "rotation")
            scale = editor.getFieldValue(decalRoadId, "scale")
            if savedParams.moveOriginToZero ~= true then
              editor.setFieldValue(newMeshRoadId, "position", position)
            end
            editor.setFieldValue(newMeshRoadId, "rotation", rotation)
            editor.setFieldValue(newMeshRoadId, "scale", scale)
          end

          -- Optionally move origin to (0,0,0) while keeping nodes in place
          if savedParams.moveOriginToZero == true then
            moveOriginToZeroKeepNodes(newMeshRoadId, newMeshNodes)
          end

          if savedParams.copyMaterial == true then
            material = editor.getFieldValue(decalRoadId, "Material")
            editor.setFieldValue(newMeshRoadId, "topMaterial", material)
          end
          editor.pasteFields(editor.copyFields(decalRoadId), newMeshRoadId)
          editor.setFieldValue(newMeshRoadId, "name", generateUniqueRoadName(requestedName, newMeshRoadId))

          if savedParams.deleteOld == true then
            editor.deleteRoad(decalRoadId)
          end
          if savedParams.rebuildCollision == true then
            be:reloadCollision()
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
    im.Text("2. Select one or multiple roads in World Editor (Mesh or Decal, not both together)")
    im.Text("3. Click on corresponding 'Get from Selection' button")
    im.Text("4. Convert")
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
  editor.registerWindow(toolWindowName, im.ImVec2(800, 300))
  editor.addWindowMenuItem("Mesh Decal Road Convert", onWindowMenuItem)
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui

return M
