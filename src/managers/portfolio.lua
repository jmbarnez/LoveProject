  Portfolio Manager
  Manages the player's assets, funds, and transaction history for the crypto market.
]]

local PortfolioManager = {}
local Util = require("src.core.util")

PortfolioManager.holdings = {} -- { symbol = { quantity = number, avgPrice = number } }
PortfolioManager.funds = 500 -- Starting funds
PortfolioManager.transactionHistory = {}

-- Initializes the portfolio, optionally loading from saved data
function PortfolioManager.init(savedData, options)
  options = options or {}
  local force = options.force == true

  if PortfolioManager._initialized and not force and not savedData then
    return
  end

  if savedData then
    PortfolioManager.holdings = Util.deepCopy(savedData.holdings or {})
    PortfolioManager.funds = savedData.funds or 500
    PortfolioManager.transactionHistory = Util.deepCopy(savedData.transactionHistory or {})
  else
    PortfolioManager.holdings = {}
    PortfolioManager.funds = 500
    PortfolioManager.transactionHistory = {}
  end

  PortfolioManager._initialized = true
end

-- Places a buy order
function PortfolioManager.placeBuyOrder(symbol, quantity, price, isLimitOrder)
  local NodeMarket = require("src.systems.node_market")

  -- For market orders, we need to check funds against estimated price first
  local estimatedCost = quantity * (price or 0)
  if not isLimitOrder then
    local node = NodeMarket.getNodeBySymbol(symbol)
    if not node then return false, "Node not found" end
    estimatedCost = quantity * node.price * 1.01  -- Add buffer for spread
  else
    if not price or price <= 0 then return false, "Invalid price for limit order" end
    estimatedCost = quantity * price
  end

  if PortfolioManager.funds < estimatedCost then
    return false, "Insufficient funds."
  end

  -- Submit order to market and get the executed price
  local success, message, executedPrice = NodeMarket.submitOrder(symbol, "BUY", quantity, price, isLimitOrder)
  if not success then
    return false, message
  end

  -- Use the executed price for actual cost calculation
  local actualPrice = executedPrice or price
  local cost = quantity * actualPrice

  if PortfolioManager.funds >= cost then
    PortfolioManager.funds = PortfolioManager.funds - cost

    -- Update holdings
    if not PortfolioManager.holdings[symbol] then
      PortfolioManager.holdings[symbol] = { quantity = 0, avgPrice = 0 }
    end
    local holding = PortfolioManager.holdings[symbol]
    local oldQuantity = holding.quantity
    local oldValue = holding.avgPrice * oldQuantity
    holding.quantity = holding.quantity + quantity
    holding.avgPrice = (oldValue + (actualPrice * quantity)) / holding.quantity

    -- Record transaction with actual executed price
    local transaction = {
      type = isLimitOrder and "LIMIT_BUY" or "BUY",
      symbol = symbol,
      quantity = quantity,
      price = actualPrice,
      timestamp = os.time()
    }
    table.insert(PortfolioManager.transactionHistory, transaction)

    -- TODO: Dispatch event for UI update
    -- Events.dispatch("portfolio_updated")

    return true, (isLimitOrder and "Limit buy order executed at " or "Buy order executed at ") .. string.format("%.4f", actualPrice)
  else
    return false, "Insufficient funds."
  end
end

-- Places a sell order
function PortfolioManager.placeSellOrder(symbol, quantity, price, isLimitOrder)
  local NodeMarket = require("src.systems.node_market")
  local holding = PortfolioManager.holdings[symbol]

  if not holding or holding.quantity < quantity then
    return false, "Insufficient holdings."
  end

  -- Submit order to market and get the executed price
  local success, message, executedPrice = NodeMarket.submitOrder(symbol, "SELL", quantity, price, isLimitOrder)
  if not success then
    return false, message
  end

  -- Use the executed price for revenue calculation
  local actualPrice = executedPrice or price
  local revenue = quantity * actualPrice

  PortfolioManager.funds = PortfolioManager.funds + revenue

  -- Update holdings
  holding.quantity = holding.quantity - quantity
  if holding.quantity <= 0.0001 then  -- Handle floating point precision
    PortfolioManager.holdings[symbol] = nil
  end

  -- Record transaction with actual executed price
  local transaction = {
    type = isLimitOrder and "LIMIT_SELL" or "SELL",
    symbol = symbol,
    quantity = quantity,
    price = actualPrice,
    timestamp = os.time()
  }
  table.insert(PortfolioManager.transactionHistory, transaction)

  -- TODO: Dispatch event for UI update
  -- Events.dispatch("portfolio_updated")

  return true, (isLimitOrder and "Limit sell order executed at " or "Sell order executed at ") .. string.format("%.4f", actualPrice)
end

-- Returns the player's holdings for a specific symbol
function PortfolioManager.getHoldings(symbol)
  return PortfolioManager.holdings[symbol]
end

-- Returns all of the player's holdings
function PortfolioManager.getAllHoldings()
    return PortfolioManager.holdings
end

-- Returns the player's available funds
function PortfolioManager.getAvailableFunds()
  return PortfolioManager.funds
end

-- Returns the player's transaction history
function PortfolioManager.getTransactionHistory()
  return PortfolioManager.transactionHistory
end

-- Adds random node connections from a node wallet
function PortfolioManager.useNodeWallet()
  local NodeMarket = require("src.systems.node_market")
  local availableNodes = {"AST", "NOVA", "QRP", "PHN", "VLT", "NEB", "CRN", "LUM"}

  -- Get nodes that the player doesn't already have connections to
  local unconnectedNodes = {}
  for _, symbol in ipairs(availableNodes) do
    if not PortfolioManager.holdings[symbol] or PortfolioManager.holdings[symbol].quantity <= 0 then
      table.insert(unconnectedNodes, symbol)
    end
  end

  if #unconnectedNodes == 0 then
    return false, "Already connected to all available nodes."
  end

  -- Add 1-3 random connections
  local connectionsToAdd = math.random(1, math.min(3, #unconnectedNodes))
  local addedNodes = {}

  for i = 1, connectionsToAdd do
    local randomIndex = math.random(1, #unconnectedNodes)
    local symbol = table.remove(unconnectedNodes, randomIndex)

    -- Get current node price
    local node = NodeMarket.getNodeBySymbol(symbol)
    local price = node and node.price or 10  -- fallback price

    -- Generate a weighted random amount between 0.01 and 0.49
    -- Using a power function to make higher values exponentially rarer
    local rand = math.random() ^ 1.5  -- Adjust exponent to control distribution
    local quantity = 0.01 + (rand * 0.48)  -- Scale to 0.01-0.49 range
    quantity = math.floor(quantity * 100) / 100  -- Round to 2 decimal places

    if not PortfolioManager.holdings[symbol] then
      PortfolioManager.holdings[symbol] = { quantity = 0, avgPrice = 0 }
    end

    local holding = PortfolioManager.holdings[symbol]
    local oldQuantity = holding.quantity
    holding.quantity = holding.quantity + quantity
    holding.avgPrice = ((holding.avgPrice * oldQuantity) + (price * quantity)) / holding.quantity

    table.insert(addedNodes, {symbol = symbol, quantity = quantity})

    -- Record transaction
    table.insert(PortfolioManager.transactionHistory, {
      type = "WALLET",
      symbol = symbol,
      quantity = quantity,
      price = price,
      timestamp = os.time()
    })
  end

  return true, "Node wallet opened! Connected to: " .. table.concat(
    (function()
      local nodeNames = {}
      for _, node in ipairs(addedNodes) do
        table.insert(nodeNames, string.format("%s (%.2f)", node.symbol, node.quantity))
      end
      return nodeNames
    end)(), ", ")
end

-- Returns data to be saved
function PortfolioManager.serialize()
  return {
    holdings = PortfolioManager.holdings,
    funds = PortfolioManager.funds,
    transactionHistory = PortfolioManager.transactionHistory
  }
end

return PortfolioManager