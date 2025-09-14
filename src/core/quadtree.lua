local Quadtree = {}
Quadtree.__index = Quadtree

function Quadtree.new(bounds, capacity)
    local self = setmetatable({}, Quadtree)
    self.bounds = bounds
    self.capacity = capacity or 4
    self.objects = {}
    self.divided = false
    return self
end

function Quadtree:subdivide()
    local x = self.bounds.x
    local y = self.bounds.y
    local w = self.bounds.width / 2
    local h = self.bounds.height / 2

    local ne = { x = x + w, y = y, width = w, height = h }
    local nw = { x = x, y = y, width = w, height = h }
    local se = { x = x + w, y = y + h, width = w, height = h }
    local sw = { x = x, y = y + h, width = w, height = h }

    self.northeast = Quadtree.new(ne, self.capacity)
    self.northwest = Quadtree.new(nw, self.capacity)
    self.southeast = Quadtree.new(se, self.capacity)
    self.southwest = Quadtree.new(sw, self.capacity)

    self.divided = true
end

-- Returns true if the given rect intersects this node's bounds
local function rectIntersects(a, b)
    return not (a.x > b.x + b.width or a.x + a.width < b.x or a.y > b.y + b.height or a.y + a.height < b.y)
end

-- Returns true if the given rect is fully contained within this node's bounds
local function rectFullyContains(container, r)
    return r.x >= container.x and r.y >= container.y and (r.x + r.width) <= (container.x + container.width) and (r.y + r.height) <= (container.y + container.height)
end

function Quadtree:insert(object)
    -- Skip if object doesn't intersect this node at all
    if not rectIntersects(object, self.bounds) then return false end

    -- If we have children, try to push fully-contained objects down
    if self.divided then
        if rectFullyContains(self.northeast.bounds, object) then return self.northeast:insert(object) end
        if rectFullyContains(self.northwest.bounds, object) then return self.northwest:insert(object) end
        if rectFullyContains(self.southeast.bounds, object) then return self.southeast:insert(object) end
        if rectFullyContains(self.southwest.bounds, object) then return self.southwest:insert(object) end
    end

    -- Store in this node if under capacity or object spans multiple children
    if #self.objects < self.capacity or self.divided then
        table.insert(self.objects, object)
        return true
    end

    -- Otherwise subdivide and retry children
    if not self.divided then self:subdivide() end
    if rectFullyContains(self.northeast.bounds, object) then return self.northeast:insert(object) end
    if rectFullyContains(self.northwest.bounds, object) then return self.northwest:insert(object) end
    if rectFullyContains(self.southeast.bounds, object) then return self.southeast:insert(object) end
    if rectFullyContains(self.southwest.bounds, object) then return self.southwest:insert(object) end

    -- Still spans multiple children: keep it here
    table.insert(self.objects, object)
    return true
end

function Quadtree:intersects(range)
    return rectIntersects(range, self.bounds)
end

function Quadtree:query(range, found)
    found = found or {}

    if not self:intersects(range) then
        return found
    end

    for i = 1, #self.objects do
        if self.objects[i].x < range.x + range.width and
           self.objects[i].x + self.objects[i].width > range.x and
           self.objects[i].y < range.y + range.height and
           self.objects[i].y + self.objects[i].height > range.y then
            table.insert(found, self.objects[i])
        end
    end

    if self.divided then
        self.northwest:query(range, found)
        self.northeast:query(range, found)
        self.southwest:query(range, found)
        self.southeast:query(range, found)
    end

    return found
end

function Quadtree:clear()
    self.objects = {}
    self.divided = false
    self.northeast = nil
    self.northwest = nil
    self.southeast = nil
    self.southwest = nil
end

return Quadtree
