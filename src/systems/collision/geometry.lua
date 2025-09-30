local Geometry = {}

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
    print("segPolygonHit: Invalid vertices, count=" .. tostring(verts and #verts or 0))
    return false 
  end
  local count = #verts
  local numVertices = count / 2
  
  -- Only print debug info for the first few calls to avoid spam
  if not Geometry._debugCount then Geometry._debugCount = 0 end
  Geometry._debugCount = Geometry._debugCount + 1
  if Geometry._debugCount <= 3 then
    print("segPolygonHit: Checking beam (" .. x1 .. "," .. y1 .. ") to (" .. x2 .. "," .. y2 .. ") against polygon with " .. numVertices .. " vertices")
  end
  
  for i = 1, numVertices do
    local nextI = i + 1
    if nextI > numVertices then nextI = 1 end
    
    local ix, iy = verts[(i-1)*2 + 1], verts[(i-1)*2 + 2]
    local jx, jy = verts[(nextI-1)*2 + 1], verts[(nextI-1)*2 + 2]
    if Geometry._debugCount <= 3 then
      print("  Edge " .. i .. ": (" .. ix .. "," .. iy .. ") to (" .. jx .. "," .. jy .. ")")
    end
    local hit, hx, hy = Geometry.segIntersect(x1,y1,x2,y2, ix,iy,jx,jy)
    if hit then 
      if Geometry._debugCount <= 3 then
        print("  HIT! At (" .. hx .. "," .. hy .. ")")
      end
      return true, hx, hy 
    end
  end
  if Geometry._debugCount <= 3 then
    print("  No hit found")
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

return Geometry
