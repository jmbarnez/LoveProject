local Geometry = {}

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
  if not verts or #verts < 6 then return false end
  local count = #verts
  for i = 1, count-1, 2 do
    local j = i + 2
    if j > count then j = 1 end
    local ix, iy = verts[i], verts[i+1]
    local jx, jy = verts[j], verts[j+1]
    local hit, hx, hy = Geometry.segIntersect(x1,y1,x2,y2, ix,iy,jx,jy)
    if hit then return true, hx, hy end
  end
  return false
end

function Geometry.pointInPolygon(px, py, verts)
  if not verts or #verts < 6 then return false end
  local inside = false
  local count = #verts
  local j = count - 1

  for i = 1, count-1, 2 do
    local xi, yi = verts[i], verts[i+1]
    local xj, yj = verts[j], verts[j+1]

    if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
      inside = not inside
    end
    j = i
  end
  return inside
end

function Geometry.polygonVsPolygon(verts1, verts2)
  -- Check if any edge of polygon1 intersects polygon2
  local count1 = #verts1
  for i = 1, count1-1, 2 do
    local j = i + 2
    if j > count1 then j = 1 end
    local x1, y1 = verts1[i], verts1[i+1]
    local x2, y2 = verts1[j], verts1[j+1]

    if Geometry.segPolygonHit(x1, y1, x2, y2, verts2) then
      return true
    end
  end

  -- Check if polygon1 is inside polygon2 or vice versa
  if count1 >= 2 and Geometry.pointInPolygon(verts1[1], verts1[2], verts2) then
    return true
  end

  local count2 = #verts2
  if count2 >= 2 and Geometry.pointInPolygon(verts2[1], verts2[2], verts1) then
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