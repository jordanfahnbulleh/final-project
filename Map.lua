--[[
    Contains tile data and necessary code for rendering a tile map to the
    screen.
]]

require 'Util'

Map = Class{}

TILE_BRICK = 1
TILE_EMPTY = -1

-- cloud tiles
CLOUD_LEFT = 6
CLOUD_RIGHT = 7

-- bush tiles
BUSH_LEFT = 2
BUSH_RIGHT = 3

-- mushroom tiles
MUSHROOM_TOP = 10
MUSHROOM_BOTTOM = 11

-- jump block
JUMP_BLOCK = 5
JUMP_BLOCK_HIT = 9

-- New tiles for the flag
TILE_FLAG_BASE = 16
TILE_FLAG_POLE = 8


-- a speed to multiply delta time to scroll map; smooth value
local SCROLL_SPEED = 62

-- constructor for our map object
function Map:init()
    
    self.spritesheet = love.graphics.newImage('graphics/spritesheet.png')


    self.sprites = generateQuads(self.spritesheet, 16, 16)

    self.music = love.audio.newSource('sounds/music.wav', 'static')

    self.tileWidth = 16
    self.tileHeight = 16
    self.mapWidth = 150

    self.mapHeight = 30

    self.tiles = {}

    -- applies positive Y influence on anything affected
    self.gravity = 15

    -- associate player with map
    self.player = Player(self)

    -- camera offsets
    self.camX = 0
    self.camY = -3

    -- Player's starting position
    self.playerStartX = self.tileWidth * 10
    self.playerStartY = self.tileHeight * (self.mapHeight / 2 - 1) - 20

-- Add the flag animation at the top of the pole
   -- Initialize flag animation variables
    self.flagAnimationTimer = 0 -- Timer for cycling through frames
    self.flagFrame = 13 -- Initial flag animation frame (ID 13, the first frame)
    self.flagX = self.mapWidth - 1.7  -- X position for the flag (left of the pole)
    self.flagY = self.mapHeight / 2 - 12.4 -- Y position for the flag (top of the pole)


    -- cache width and height of map in pixels
    self.mapWidthPixels = self.mapWidth * self.tileWidth
    self.mapHeightPixels = self.mapHeight * self.tileHeight

    -- first, fill map with empty tiles
    for y = 1, self.mapHeight do

        for x = 1, self.mapWidth do
            
            -- support for multiple sheets per tile; storing tiles as tables 
            self:setTile(x, y, TILE_EMPTY)
        end
    end

    -- begin generating the terrain using vertical scan lines
    local x = 1
    while x < self.mapWidth do
    
        -- 2% chance to generate a cloud
        -- make sure we're 2 tiles from edge at least
        if x < self.mapWidth - 2 then
            if math.random(20) == 1 then
                
                -- choose a random vertical spot above where blocks/pipes generate
                local cloudStart = math.random(self.mapHeight / 2 - 6)

                self:setTile(x, cloudStart, CLOUD_LEFT)
                self:setTile(x + 1, cloudStart, CLOUD_RIGHT)
            end
        end

        -- 5% chance to generate a mushroom
        if math.random(20) == 1 then
            -- left side of pipe
            self:setTile(x, self.mapHeight / 2 - 2, MUSHROOM_TOP)
            self:setTile(x, self.mapHeight / 2 - 1, MUSHROOM_BOTTOM)

            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- next vertical scan line
            x = x + 1

        -- 10% chance to generate bush, being sure to generate away from edge
        elseif math.random(10) == 1 and x < self.mapWidth - 3 then
            local bushLevel = self.mapHeight / 2 - 1

            -- place bush component and then column of bricks
            self:setTile(x, bushLevel, BUSH_LEFT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

            self:setTile(x, bushLevel, BUSH_RIGHT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

        -- 10% chance to not generate anything, creating a gap
        elseif math.random(10) ~= 1 then
            
            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- chance to create a block for Mario to hit
            if math.random(15) == 1 then
                self:setTile(x, self.mapHeight / 2 - 4, JUMP_BLOCK)
            end

            -- next vertical scan line
            x = x + 1
        else
            -- increment X so we skip two scanlines, creating a 2-tile gap
            x = x + 2

        end
    end

    
    

    -- Add a pyramid
    local pyramidBaseX = self.mapWidth - 4
    local pyramidHeight = 8
    
    
    for i = 0, pyramidHeight - 1 do
        for j = 0, pyramidHeight - i - 1 do             -- Draw bricks from right to left
            self:setTile(pyramidBaseX - j, self.mapHeight / 2 - i - 1, TILE_BRICK)
        end
    end

    --Add the flag at the end of the map
    local flagX = self.mapWidth - 1
    self:setTile(flagX, self.mapHeight / 2 - 1, TILE_FLAG_BASE)
  

    for y = self.mapHeight / 2 - 11, self.mapHeight / 2 - 2   do
        self:setTile(flagX, y, TILE_FLAG_POLE)
    end
    
    --start the background music
    self.music:setLooping(true) 
    self.music:play()
end


-- return whether a given tile is collidable
function Map:collides(tile)
    -- define our collidable tiles
    local collidables = {
        TILE_BRICK, JUMP_BLOCK, JUMP_BLOCK_HIT,
        MUSHROOM_TOP, MUSHROOM_BOTTOM
    }

    -- iterate and return true if our tile type matches
    for _, v in ipairs(collidables) do
        if tile.id == v then
            return true
        end
    end

    return false
end

-- function to update camera offset with delta time
function Map:update(dt)
    self.player:update(dt)

    if self.player.y > self.mapHeight * self.tileHeight then
        self:resetLevel() -- Call the reset function
    end

    -- Update flag animation
    self.flagAnimationTimer = self.flagAnimationTimer + dt
    if self.flagAnimationTimer >= 0.2 then
        self.flagFrame = 13 + (self.flagFrame - 13 + 1) % 3 -- Cycle through 13, 14, 15
        self.flagAnimationTimer = 0
    end

    -- Check for victory
    if self:isCollidingWithFlag() then
        gameState = 'victory'
        Timer.after(2, loadNewLevel)
    end

    -- Update camera
    self.camX = math.max(0, math.min(self.player.x - VIRTUAL_WIDTH / 2,
        self.mapWidthPixels - VIRTUAL_WIDTH))


    -- Camera logic
    self.camX = math.max(0, math.min(self.player.x - VIRTUAL_WIDTH / 2,
        self.mapWidthPixels - VIRTUAL_WIDTH))
        -- Add in Map:update()

end

    

function Map:isCollidingWithFlag()
    -- Access the player's position using self.player
    -- Player bounds
    local playerLeft = self.player.x
    local playerRight = self.player.x + self.player.width
    local playerTop = self.player.y
    local playerBottom = self.player.y + self.player.height

    -- Flag bounds
    local flagLeft = (self.flagX - 1) * self.tileWidth
    local flagRight = self.flagX * self.tileWidth
    local flagTop = (self.flagY) * self.tileHeight
    local flagBottom = (self.mapHeight / 2 - 1) * self.tileHeight

    -- Check if player overlaps with the flag's bounding box
    return playerRight > flagLeft and playerLeft < flagRight and
           playerBottom > flagTop and playerTop < flagBottom
end



-- gets the tile type at a given pixel coordinate
function Map:tileAt(x, y)
    return {
        x = math.floor(x / self.tileWidth) + 1,
        y = math.floor(y / self.tileHeight) + 1,
        id = self:getTile(math.floor(x / self.tileWidth) + 1, math.floor(y / self.tileHeight) + 1)
    }
end

-- returns an integer value for the tile at a given x-y coordinate
function Map:getTile(x, y)
    return self.tiles[(y - 1) * self.mapWidth + x]
end

-- sets a tile at a given x-y coordinate to an integer value
function Map:setTile(x, y, id)
    self.tiles[(y - 1) * self.mapWidth + x] = id
end


-- renders our map to the screen, to be called by main's render
function Map:render()
    -- Render flagpole tiles first
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            local tile = self:getTile(x, y)
            if tile == TILE_FLAG_BASE or tile == TILE_FLAG_POLE then
                love.graphics.draw(self.spritesheet, self.sprites[tile],
                    (x - 1) * self.tileWidth, (y - 1) * self.tileHeight)
            end
        end
    end

    -- Render the animated flag at the top of the pole
    love.graphics.draw(self.spritesheet, self.sprites[self.flagFrame],
        self.flagX * self.tileWidth, self.flagY * self.tileHeight)

    -- Render other tiles
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            local tile = self:getTile(x, y)
            if tile ~= TILE_EMPTY and tile ~= TILE_FLAG_BASE and tile ~= TILE_FLAG_POLE then
                love.graphics.draw(self.spritesheet, self.sprites[tile],
                    (x - 1) * self.tileWidth, (y - 1) * self.tileHeight)
            end
        end
    end

    -- Render the player last
    self.player:render()
end

function Map:resetLevel()
    -- Reset the player's position
    self.player.x = self.playerStartX
    self.player.y = self.playerStartY

end
