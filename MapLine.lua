local f = CreateFrame('frame', nil, WorldMapPlayerLower)
f:SetAllPoints()

-- This is all for drawing a line on the map in zones that we're not currently in
-- We could just draw our line outside of the scrollframe and rotate it, and to be honest that may even be a better approach

local function GetMapSize() -- Return dimensions and offset of current map
	local currentMapID = WorldMapFrame:GetMapID()
	if not currentMapID then return end
	
	local mapID, topleft = C_Map.GetWorldPosFromMapPos(currentMapID, {x = 0, y = 0})
	local mapID, bottomright = C_Map.GetWorldPosFromMapPos(currentMapID, {x = 1, y = 1})
	if not mapID then return end
	
	local left, top = topleft.y, topleft.x
	local right, bottom = bottomright.y, bottomright.x
	local width, height = left - right, top - bottom
	return left, top, right, bottom, width, height, mapID
end

local function GetIntersect(px, py, a, sx, sy, ex, ey)
	a = (a + PI / 2) % (PI * 2)
	local dx, dy = -math.cos(a), math.sin(a)
	local d = dx * (sy - ey) + dy * (ex - sx)
	if d ~= 0 and dx ~= 0 then
		local s = (dx * (sy - py) - dy * (sx - px)) / d
		if s >= 0 and s <= 1 then
			local r = (sx + (ex - sx) * s - px) / dx
			if r >= 0 then
				return sx + (ex - sx) * s, sy + (ey - sy) * s, r, s
			end
		end
	end
end

local WorldMapButton = WorldMapFrame:GetCanvas()
local LineFrame = CreateFrame('frame', nil, WorldMapButton)
LineFrame:SetAllPoints()
LineFrame:SetFrameLevel(15000)

-- These frames are essentially just placeholders to anchor our line to
local StartPoint = CreateFrame('frame', nil, LineFrame) StartPoint:SetSize(1, 1)
local EndPoint = CreateFrame('frame', nil, LineFrame) EndPoint:SetSize(1, 1)



local Line = LineFrame:CreateLine(nil, 'OVERLAY')
Line:Hide()
Line:SetTexture('interface/buttons/white8x8')
if Line.SetGradientAlpha then
	-- Pre-10.0 method
	Line:SetGradientAlpha('HORIZONTAL', 0, 0, 0, 0.5, 1, 0, 0, 0.8)
elseif CreateColor then
	-- Post-10.0 method
	Line:SetGradient('HORIZONTAL', CreateColor(0, 0, 0, 0.5), CreateColor(1, 0, 0, 0.8))
else
	-- Fallback to just setting a solid color
	Line:SetVertexColor(0.5, 0, 0, 0.8)
end
Line:SetThickness(2)
Line:SetStartPoint('CENTER', StartPoint, 0, 0)
Line:SetEndPoint('CENTER', EndPoint, 0, 0)

local WorldMapUpdated, PlayerFacing = false, 0
LineFrame:SetScript('OnUpdate', function(self, elapsed)
	local angle = GetPlayerFacing()
	if not angle and Line:IsShown() then
		Line:Hide()
	elseif WorldMapUpdated or GetUnitSpeed('player') > 0 or angle ~= PlayerFacing then
		WorldMapUpdated = false
		PlayerFacing = angle
		Line:Hide()
		
		
		if UnitOnTaxi('player') then -- hide line while in flight
			return
		end
		
		local mx, my = 0, 0
		
		-- if not onMap and continentID == 9 then return end -- don't draw line to other argus maps
		local bestMap = C_Map.GetBestMapForUnit("player");
		local playerMapPos = C_Map.GetPlayerMapPosition(bestMap,"player")
			
			
		if (playerMapPos == nil) then
			return
		end
			
		local pMapID,loc = C_Map.GetWorldPosFromMapPos(bestMap,{x=playerMapPos.x,y=playerMapPos.y})
		--blizz, wtf.
		local px = loc.y;
		local py = loc.x;
		if not px then return end -- we somehow do not have coordinates
		--local left, top, right, bottom, width, height, mapMapID = GetMapSize()
		local left, top, right, bottom, width, height, mapMapID = GetMapSize()
		if not width or width == 0 then return end -- map has no size?
		
		
		local sameInstanceish = pMapID == mapMapID
		local onMap = false
		if sameInstanceish and (px <= left and px >= right and py <= top and py >= bottom) then
			mx, my = (left - px) / width, (top - py) / height
			onMap = true
		end
		
		
		if mapMapID == pMapID or onMap or sameInstanceish then -- same instance
			-- this could probably be simplified, but there's probably no point
			-- top left to top right
			local topX, topY, topRi, topSi = GetIntersect(px, py, angle, left, top, right, top)
			-- bottom left to bottom right
			local bottomX, bottomY, bottomRi, bottomSi = GetIntersect(px, py, angle, left, bottom, right, bottom)
			-- top left to bottom left
			local leftX, leftY, leftRi, leftSi = GetIntersect(px, py, angle, left, top, left, bottom)
			-- top right to bottom right
			local rightX, rightY, rightRi, rightSi = GetIntersect(px, py, angle, right, top, right, bottom)
			
			local mx1, my1, mr1, ms1
			local mx2, my2, mr2, ms2
			local m1Side, m2Side -- top, bottom, left, right
			
			if topX then
				mx1, my1, mr1, ms1 = topX, topY, topRi, topSi
				m1Side = 'top'
			end
			if bottomX then
				if not mx1 then
					mx1, my1, mr1, ms1 = bottomX, bottomY, bottomRi, bottomSi
					m1Side = 'bottom'
				else
					mx2, my2, mr2, ms2 = bottomX, bottomY, bottomRi, bottomSi
					m2Side = 'bottom'
				end
			end
			if leftX then
				if not mx1 then
					mx1, my1, mr1, ms1 = leftX, leftY, leftRi, leftSi
					m1Side = 'left'
				else
					mx2, my2, mr2, ms2 = leftX, leftY, leftRi, leftSi
					m2Side = 'left'
				end
			end
			if rightX then
				if not mx1 then
					mx1, my1, mr1, ms1 = rightX, rightY, rightRi, rightSi
					m1Side = 'right'
				else
					mx2, my2, mr2, ms2 = rightX, rightY, rightRi, rightSi
					m2Side = 'right'
				end
			end
			
			local mWidth, mHeight = WorldMapFrame:GetCanvas():GetSize()
			if m1Side and m2Side then -- we have 2 points
				StartPoint:ClearAllPoints()
				EndPoint:ClearAllPoints()
				if mr1 < mr2 then -- m1 is closer, so use that as starting point
					if m1Side == 'top' then
						StartPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', mWidth * ms1, 0)
					elseif m1Side == 'bottom' then
						StartPoint:SetPoint('CENTER', WorldMapButton, 'BOTTOMLEFT', mWidth * ms1, 0)
					elseif m1Side == 'left' then
						StartPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', 0, -mHeight * ms1)
					elseif m1Side == 'right' then
						StartPoint:SetPoint('CENTER', WorldMapButton, 'TOPRIGHT', 0, -mHeight * ms1)
					end

					if m2Side == 'top' then
						EndPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', mWidth * ms2, 0)
					elseif m2Side == 'bottom' then
						EndPoint:SetPoint('CENTER', WorldMapButton, 'BOTTOMLEFT', mWidth * ms2, 0)
					elseif m2Side == 'left' then
						EndPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', 0, -mHeight * ms2)
					elseif m2Side == 'right' then
						EndPoint:SetPoint('CENTER', WorldMapButton, 'TOPRIGHT', 0, -mHeight * ms2)
					end
				else -- m2 is closer
					if m2Side == 'top' then
						StartPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', mWidth * ms2, 0)
					elseif m2Side == 'bottom' then
						StartPoint:SetPoint('CENTER', WorldMapButton, 'BOTTOMLEFT', mWidth * ms2, 0)
					elseif m2Side == 'left' then
						StartPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', 0, -mHeight * ms2)
					elseif m2Side == 'right' then
						StartPoint:SetPoint('CENTER', WorldMapButton, 'TOPRIGHT', 0, -mHeight * ms2)
					end
					
					if m1Side == 'top' then
						EndPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', mWidth * ms1, 0)
					elseif m1Side == 'bottom' then
						EndPoint:SetPoint('CENTER', WorldMapButton, 'BOTTOMLEFT', mWidth * ms1, 0)
					elseif m1Side == 'left' then
						EndPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', 0, -mHeight * ms1)
					elseif m1Side == 'right' then
						EndPoint:SetPoint('CENTER', WorldMapButton, 'TOPRIGHT', 0, -mHeight * ms1)
					end
				end
				Line:Show()
			elseif m1Side and onMap then
				StartPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', mWidth * mx, -mHeight * my)
				if m1Side == 'top' then
					EndPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', mWidth * ms1, 0)
				elseif m1Side == 'bottom' then
					EndPoint:SetPoint('CENTER', WorldMapButton, 'BOTTOMLEFT', mWidth * ms1, 0)
				elseif m1Side == 'left' then
					EndPoint:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', 0, -mHeight * ms1)
				elseif m1Side == 'right' then
					EndPoint:SetPoint('CENTER', WorldMapButton, 'TOPRIGHT', 0, -mHeight * ms1)
				end
				Line:Show()
			end
		end
	end
end)

hooksecurefunc(WorldMapFrame, 'OnMapChanged', function()
	WorldMapUpdated = true
end)

hooksecurefunc(WorldMapFrame, 'OnCanvasScaleChanged', function(self)
	local scale = self:GetCanvas():GetScale()
	Line:SetThickness(2 / scale)
end)
