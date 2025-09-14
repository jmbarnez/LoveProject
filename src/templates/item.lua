local Item = {}
Item.__index = Item

function Item.new(props)
  local self = setmetatable({}, Item)
  -- Primary fields
  self.id = props.id
  self.name = props.name or props.id
  self.type = props.type or "generic"
  self.stack = props.stack or 1
  self.value = props.value or 0
  self.price = props.price -- Shop price
  self.description = props.description or ""
  self.effect = props.effect -- optional
  -- Extended fields (optional, carried for UI/gameplay)
  self.rarity = props.rarity or "Common"
  self.tier = props.tier or 1
  self.mass = props.mass or 0
  self.volume = props.volume or 0
  self.market = props.market
  self.tags = props.tags
  self.flavor = props.flavor
  self.icon = props.icon
  self.use = props.use
  -- Keep original for future needs
  self.def = props
  return self
end

function Item.fromDef(def)
  return Item.new(def)
end

return Item
