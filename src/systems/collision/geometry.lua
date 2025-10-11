local Geometry = {}

local function normalize(ax, ay)
  local len = math.sqrt(ax * ax + ay * ay)
  if len == 0 then
    return 0, 0, 0
  end
  return ax / len, ay / len, len
end

local function distSqPointSegment(px, py, x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  if dx == 0 and dy == 0 then
    local qx, qy = px - x1, py - y1
    return qx * qx + qy * qy
  end

  local t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)
  if t < 0 then
    t = 0
  elseif t > 1 then
    t = 1
  end

  local projx = x1 + t * dx
  local projy = y1 + t * dy
  local qx = px - projx
  local qy = py - projy
  return qx * qx + qy * qy
end

function Geometry.segIntersect(x1,y1,x2,y2, x3,y3,x4,y4)
  local function cross(ax,ay,bx,by) return ax*by - ay*bx end
  local rpx, rpy = x2 - x1, y2 - y1
  local spx, spy = x4 - x3, y4 - y3
  local qp_x, qp_y = x3 - x1, y3 - y1
  local rxs = cross(rpx, rpy, spx, spy)
  local qpxr = cross(qp_x, qp_y, rpx, rpy)
  if math.abs(rxs) < 1e-8 and math.abs(qpxr) < 1e-8 then return false end -- colinear
  if math.abs(rxs) < 1e-8 and math.abs(qpxr) >= 1e-8 then return false end -- parallel
  local t = cross(qp_x, qp_y, spx, spy) / rxs
  local u = cross(qp_x, qp_y, rpx, rpy) / rxs
  if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
    return true, x1 + t*rpx, y1 + t*rpy
  end
  return false
end

function Geometry.transformPolygon(ex, ey, angle, verts)
  local ca, sa = math.cos(angle or 0), math.sin(angle or 0)
  local out = {}
  for i = 1, #verts, 2 do
    local lx, ly = verts[i], verts[i+1]
    local wx = ex + ca*lx - sa*ly
    local wy = ey + sa*lx + ca*ly
    table.insert(out, wx)
    table.insert(out, wy)
  end
  return out
end

function Geometry.segPolygonHit(x1,y1,x2,y2, verts)
  if not verts or #verts < 6 then 
    return false 
  end
  local count = #verts
  local numVertices = count / 2
  
  -- Check if either endpoint is inside the polygon (prevents tunneling)
  local startInside = Geometry.pointInPolygon(x1, y1, verts)
  local endInside = Geometry.pointInPolygon(x2, y2, verts)
  
  -- Check for edge intersections
  local bestHit = nil
  local bestDistance = math.huge
  
  for i = 1, numVertices do
    local nextI = i + 1
    if nextI > numVertices then nextI = 1 end
    
    local ix, iy = verts[(i-1)*2 + 1], verts[(i-1)*2 + 2]
    local jx, jy = verts[(nextI-1)*2 + 1], verts[(nextI-1)*2 + 2]
    
    local hit, hx, hy = Geometry.segIntersect(x1,y1,x2,y2, ix,iy,jx,jy)
    if hit then 
      -- Find the closest intersection point to the start of the beam
      local distance = math.sqrt((hx - x1)^2 + (hy - y1)^2)
      if distance < bestDistance then
        bestDistance = distance
        bestHit = {hx, hy}
      end
    end
  end

  if bestHit then
    return true, bestHit[1], bestHit[2]
  end

  -- If no edge intersection was found but the segment starts or ends inside,
  -- fall back to whichever endpoint lies within the polygon. This avoids
  -- missing hits when the entire segment is contained inside the shape.
  if startInside then
    return true, x1, y1
  end
  if endInside then
    return true, x2, y2
  end

  return false
end

function Geometry.pointInPolygon(px, py, verts)
  if not verts or #verts < 6 then return false end
  local inside = false
  local numVertices = #verts / 2
  local j = numVertices

  for i = 1, numVertices do
    local xi, yi = verts[(i-1)*2 + 1], verts[(i-1)*2 + 2]
    local xj, yj = verts[(j-1)*2 + 1], verts[(j-1)*2 + 2]

    if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
      inside = not inside
    end
    j = i
  end
  return inside
end

function Geometry.polygonVsPolygon(verts1, verts2)
  -- Check if any edge of polygon1 intersects polygon2
  local numVertices1 = #verts1 / 2
  for i = 1, numVertices1 do
    local nextI = i + 1
    if nextI > numVertices1 then nextI = 1 end
    local x1, y1 = verts1[(i-1)*2 + 1], verts1[(i-1)*2 + 2]
    local x2, y2 = verts1[(nextI-1)*2 + 1], verts1[(nextI-1)*2 + 2]

    if Geometry.segPolygonHit(x1, y1, x2, y2, verts2) then
      return true
    end
  end

  -- Check if polygon1 is inside polygon2 or vice versa
  if numVertices1 >= 1 and Geometry.pointInPolygon(verts1[1], verts1[2], verts2) then
    return true
  end

  local numVertices2 = #verts2 / 2
  if numVertices2 >= 1 and Geometry.pointInPolygon(verts2[1], verts2[2], verts1) then
    return true
  end

  return false
end

function Geometry.polygonVsCircle(verts, cx, cy, radius)
  if not verts or #verts < 6 then return false end
  local radiusSq = radius * radius
  local numVertices = #verts / 2

  for i = 1, numVertices do
    local nextI = i + 1
    if nextI > numVertices then nextI = 1 end
    local x1 = verts[(i-1) * 2 + 1]
    local y1 = verts[(i-1) * 2 + 2]
    local x2 = verts[(nextI-1) * 2 + 1]
    local y2 = verts[(nextI-1) * 2 + 2]

    if distSqPointSegment(cx, cy, x1, y1, x2, y2) <= radiusSq then
      return true
    end
  end

  if Geometry.pointInPolygon(cx, cy, verts) then
    return true
  end

  return false
end

function Geometry.calculateShieldHitPoint(x1, y1, x2, y2, ex, ey, shieldRadius)
    -- Robust segment-circle intersection that always returns the correct entry/exit point
    local dx = x2 - x1
    local dy = y2 - y1
    local fx = x1 - ex
    local fy = y1 - ey

    local a = dx * dx + dy * dy
    local b = 2 * (fx * dx + fy * dy)
    local c = (fx * fx + fy * fy) - shieldRadius * shieldRadius

    local discriminant = b * b - 4 * a * c
    if discriminant < 0 or a == 0 then
        return false
    end

    local s = math.sqrt(discriminant)
    local t1 = (-b - s) / (2 * a)
    local t2 = (-b + s) / (2 * a)

    -- Sort so t1 <= t2
    if t1 > t2 then t1, t2 = t2, t1 end

    local insideStart = (fx * fx + fy * fy) < (shieldRadius * shieldRadius)
    local function pointAt(t)
        return x1 + t * dx, y1 + t * dy
    end

    -- Select correct intersection depending on where the segment starts
    if insideStart then
        -- Starting inside the shield: use the exit point (largest valid t in [0,1])
        if t2 >= 0 and t2 <= 1 then
            local hx, hy = pointAt(t2)
            return true, hx, hy
        else
            return false
        end
    else
        -- Starting outside: use the entry point (smallest valid t in [0,1])
        if t1 >= 0 and t1 <= 1 then
            local hx, hy = pointAt(t1)
            return true, hx, hy
        elseif t2 >= 0 and t2 <= 1 then
            local hx, hy = pointAt(t2)
            return true, hx, hy
        else
            return false
        end
    end
end

local function polygonCentroid(verts)
  if not verts or #verts < 6 then
    if not verts or #verts < 2 then
      return 0, 0
    end
    local sumX, sumY = 0, 0
    local count = #verts / 2
    for i = 1, #verts, 2 do
      sumX = sumX + (verts[i] or 0)
      sumY = sumY + (verts[i + 1] or 0)
    end
    return sumX / count, sumY / count
  end

  local area = 0
  local cx, cy = 0, 0
  local count = #verts
  for i = 1, count, 2 do
    local j = i + 2
    if j > count then j = 1 end
    local x0, y0 = verts[i], verts[i + 1]
    local x1, y1 = verts[j], verts[j + 1]
    local cross = x0 * y1 - x1 * y0
    area = area + cross
    cx = cx + (x0 + x1) * cross
    cy = cy + (y0 + y1) * cross
  end

  area = area * 0.5
  if area == 0 then
    return verts[1] or 0, verts[2] or 0
  end

  cx = cx / (6 * area)
  cy = cy / (6 * area)
  return cx, cy
end

local function projectPolygon(axisX, axisY, verts)
  local minProj = math.huge
  local maxProj = -math.huge
  for i = 1, #verts, 2 do
    local proj = (verts[i] or 0) * axisX + (verts[i + 1] or 0) * axisY
    if proj < minProj then minProj = proj end
    if proj > maxProj then maxProj = proj end
  end
  return minProj, maxProj
end

local function projectCircle(axisX, axisY, cx, cy, radius)
  local center = cx * axisX + cy * axisY
  return center - radius, center + radius
end

local function appendPolygonAxes(axes, verts)
  if not verts or #verts < 6 then
    return
  end

  local count = #verts
  for i = 1, count, 2 do
    local j = i + 2
    if j > count then j = 1 end
    local x1, y1 = verts[i], verts[i + 1]
    local x2, y2 = verts[j], verts[j + 1]
    local edgeX, edgeY = x2 - x1, y2 - y1
    local axisX, axisY = normalize(-edgeY, edgeX)
    if axisX ~= 0 or axisY ~= 0 then
      table.insert(axes, { axisX, axisY })
    end
  end
end

local function selectDirection(axisX, axisY, centerA, centerB)
  if (axisX == 0 and axisY == 0) then
    return axisX, axisY
  end

  if centerB > centerA then
    return axisX, axisY
  else
    return -axisX, -axisY
  end
end

function Geometry.polygonCircleMTV(verts, cx, cy, radius)
  if not verts or #verts < 6 then
    return false
  end

  local axes = {}
  appendPolygonAxes(axes, verts)

  -- Axis from closest vertex to circle center helps handle containment cases
  local closestDx, closestDy
  local closestDistSq = math.huge
  for i = 1, #verts, 2 do
    local vx, vy = verts[i], verts[i + 1]
    local dx = cx - vx
    local dy = cy - vy
    local distSq = dx * dx + dy * dy
    if distSq < closestDistSq and distSq > 0 then
      closestDistSq = distSq
      closestDx, closestDy = dx, dy
    end
  end
  if closestDx and closestDy then
    local axisX, axisY = normalize(closestDx, closestDy)
    if axisX ~= 0 or axisY ~= 0 then
      table.insert(axes, { axisX, axisY })
    end
  end

  local minOverlap = math.huge
  local bestAxisX, bestAxisY = 0, 0
  local polyCentroidX, polyCentroidY = polygonCentroid(verts)

  for _, axis in ipairs(axes) do
    local axisX, axisY = axis[1], axis[2]
    local minA, maxA = projectPolygon(axisX, axisY, verts)
    local minB, maxB = projectCircle(axisX, axisY, cx, cy, radius)
    local overlap = math.min(maxA, maxB) - math.max(minA, minB)
    if overlap <= 0 then
      return false
    end
    if overlap < minOverlap then
      minOverlap = overlap
      local centerA = polyCentroidX * axisX + polyCentroidY * axisY
      local centerB = cx * axisX + cy * axisY
      bestAxisX, bestAxisY = selectDirection(axisX, axisY, centerA, centerB)
    end
  end

  return true, minOverlap, bestAxisX, bestAxisY
end

function Geometry.polygonPolygonMTV(vertsA, vertsB)
  if not vertsA or not vertsB or #vertsA < 6 or #vertsB < 6 then
    return false
  end

  local axes = {}
  appendPolygonAxes(axes, vertsA)
  appendPolygonAxes(axes, vertsB)

  if #axes == 0 then
    return false
  end

  local centroidAX, centroidAY = polygonCentroid(vertsA)
  local centroidBX, centroidBY = polygonCentroid(vertsB)

  local minOverlap = math.huge
  local bestAxisX, bestAxisY = 0, 0

  for _, axis in ipairs(axes) do
    local axisX, axisY = axis[1], axis[2]
    local minA, maxA = projectPolygon(axisX, axisY, vertsA)
    local minB, maxB = projectPolygon(axisX, axisY, vertsB)
    local overlap = math.min(maxA, maxB) - math.max(minA, minB)
    if overlap <= 0 then
      return false
    end
    if overlap < minOverlap then
      minOverlap = overlap
      local centerA = centroidAX * axisX + centroidAY * axisY
      local centerB = centroidBX * axisX + centroidBY * axisY
      bestAxisX, bestAxisY = selectDirection(axisX, axisY, centerA, centerB)
    end
  end

  return true, minOverlap, bestAxisX, bestAxisY
end

return Geometry
