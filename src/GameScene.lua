require "Cocos2d"
require "Cocos2dConstants"

local kBlockHorizontalCount = 8   -- 水平方向ブロック数
local kBlockVerticalCount   = 5   -- 垂直方向ブロック数
local kBlockWidth           = 40  -- ブロックの幅
local kBlockHeight          = 15  -- ブロックの高さ
local kTopMargin            = 30  -- 上部マージン
local kBottomMargin         = 30  -- 底部マージン
local kOuterBottomSize      = 50  -- 画面下部の領域のサイズ
local kOuterWallSize        = 100 -- 壁の厚さ
local kBallSpeed            = 700 -- ボールのスピード

-- 物理シミュレーションで使用するカテゴリ
local kCategoryPaddle       = 1    -- 00001
local kCategoryBall         = 2    -- 00010
local kCategoryBlock        = 4    -- 00100
local kCategoryBottom       = 8    -- 01000
local kCategoryWall         = 16   -- 10000

local GamePhase = {ReadyToStart = 1, Playing = 2, GameOver = 3, GameClear = 4}

local GameScene = class("GameScene",function()
    return cc.Scene:createWithPhysics()
end)

function GameScene:ctor()
    self.visibleSize = cc.Director:getInstance():getVisibleSize()
    self.gamePhase  = GamePhase.ReadyToStart
    self.blockCount = 10   -- 残りのブロック数
    self.layer      = nil  -- レイヤー
    self.paddle     = nil  -- パドルのスプライト
    self.ball       = nil  -- ボールのスプライト
    self.label      = nil  -- ラベル
    self.material = cc.PhysicsMaterial(0, 1, 0) -- 密度, 反発, 摩擦
    self.blockTexture = cc.Director:getInstance():getTextureCache():addImage("blocks.png")
end

function GameScene.create()
    local scene = GameScene.new()

    --scene:getPhysicsWorld():setDebugDrawMask(cc.PhysicsWorld.DEBUGDRAW_ALL) -- デバッグ用
    scene:getPhysicsWorld():setGravity(cc.p(0,0))
    
    scene.layer = scene:createLayer()
    scene:addChild(scene.layer)
    
    scene:touchEvent()
    scene:contactTest()
    scene:readyToStart()
    return scene
end

-- レイヤーの作成
function GameScene:createLayer()
    local layer = cc.LayerColor:create(cc.c4b(0, 0, 255, 255)) -- 色は青、不透明

    self.paddle = self:createPaddle()
    self.ball = self:createBall()
    self.label = self:createLabel()

    layer:addChild(self.paddle)
    layer:addChild(self.ball)
    layer:addChild(self.label)

    layer:addChild(self:createOuterWall())
    layer:addChild(self:createBottomWall())

    return layer
end

-- パドルの作成
function GameScene:createPaddle()
    local sprite = cc.Sprite:create("paddle.png")

    local physicsBody = cc.PhysicsBody:createBox(sprite:getContentSize(), self.material)
    physicsBody:setDynamic(false)
    physicsBody:setCategoryBitmask(kCategoryPaddle)

    sprite:setPhysicsBody(physicsBody)

    return sprite
end

-- ボールの作成
function GameScene:createBall()
    local sprite = cc.Sprite:create("ball.png")

    local physicsBody = cc.PhysicsBody:createCircle(sprite:getContentSize().width/2, self.material)
    physicsBody:setRotationEnable(false)
    physicsBody:setCategoryBitmask(kCategoryBall)
    physicsBody:setContactTestBitmask(kCategoryBlock + kCategoryBottom + kCategoryWall)

    sprite:setPhysicsBody(physicsBody)

    return sprite
end

-- ラベルの作成
function GameScene:createLabel()
    local label = cc.Label:createWithSystemFont("", "Arial", 18)
    label:setPosition(self.visibleSize.width/2, self.visibleSize.height/2)

    return label
end

-- 画面の外周に壁を作る
function GameScene:createOuterWall()
    local node = cc.Node:create()
    node:setAnchorPoint(0.5, 0.5) -- アンカーポイントを設定しないとwarningが出る
    node:setPosition(self.visibleSize.width/2, self.visibleSize.height/2)

    -- 画面の外周に４つのボックスを作る
    local box1 = cc.PhysicsShapeBox:create(cc.size(self.visibleSize.width + kOuterWallSize*2, kOuterWallSize), self.material, cc.p(0, self.visibleSize.height/2 + kOuterWallSize/2))
    local box2 = cc.PhysicsShapeBox:create(cc.size(self.visibleSize.width + kOuterWallSize*2, kOuterWallSize), self.material, cc.p(0, -self.visibleSize.height/2 - kOuterWallSize/2 - kOuterBottomSize))
    local box3 = cc.PhysicsShapeBox:create(cc.size(kOuterWallSize, self.visibleSize.height + kOuterBottomSize), self.material, cc.p(-self.visibleSize.width/2 -  kOuterWallSize/2, -kOuterBottomSize/2))
    local box4 = cc.PhysicsShapeBox:create(cc.size(kOuterWallSize, self.visibleSize.height + kOuterBottomSize), self.material, cc.p(self.visibleSize.width/2 + kOuterWallSize/2, -kOuterBottomSize/2))
    local body = cc.PhysicsBody:create()
    body:addShape(box1)
    body:addShape(box2)
    body:addShape(box3)
    body:addShape(box4)
    body:setDynamic(false)
    body:setCategoryBitmask(kCategoryWall)
    body:setContactTestBitmask(kCategoryBall)
    
    -- ノードに上で作った物体を設定
    node:setPhysicsBody(body) 
    
    return node
end

-- 底面にミス判定用の線を作る
function GameScene:createBottomWall()
    local node = cc.Node:create()
    node:setAnchorPoint(0.5, 0.5)
    node:setPosition(0, 0)

    local body = cc.PhysicsBody:create()
    local segment = cc.PhysicsShapeEdgeSegment:create(cc.p(0, -kOuterBottomSize+1), cc.p(self.visibleSize.width, -kOuterBottomSize+1), self.material)
    body:addShape(segment)
    body:setDynamic(false)
    body:setCategoryBitmask(kCategoryBottom)
    body:setContactTestBitmask(kCategoryBall)

    -- ノードに物体を設定
    node:setPhysicsBody(body) 

    return node
end

-- ブロックレイヤーの作成
function GameScene:createBlockLayer()
    local layer = cc.Layer:create()
    layer:setName("blockLayer")

    self.blockCount = 0
   
    for i = 0, kBlockVerticalCount-1 do
        for j = 0, kBlockHorizontalCount-1 do
            local block = cc.Sprite:createWithTexture(self.blockTexture, cc.rect(0, i*kBlockHeight, kBlockWidth, kBlockHeight))
            block:setPosition(j * kBlockWidth + block:getContentSize().width/2, self.visibleSize.height - kTopMargin - i * kBlockHeight - block:getContentSize().height/2)
            layer:addChild(block)
            
            local physicsBody = cc.PhysicsBody:createBox(block:getContentSize(), self.material)
            physicsBody:setDynamic(false)
            physicsBody:setCategoryBitmask(kCategoryBlock)
            physicsBody:setContactTestBitmask(kCategoryBall)
            
            block:setPhysicsBody(physicsBody)
            
            self.blockCount = self.blockCount + 1
        end
    end

    return layer
end

-- ブロックレイヤーの削除
function GameScene:removeBlockLayer()
    local oldLayer = self.layer:getChildByName("blockLayer")
    if oldLayer ~= nil then 
        oldLayer:removeFromParent()
    end
end

-- ゲーム開始準備
function GameScene:readyToStart()
    self.gamePhase = GamePhase.ReadyToStart
    self:removeBlockLayer()
    self.layer:addChild(self:createBlockLayer())
    self.label:setString("Tap to Start")
    self.label:setVisible(true)
    self.paddle:setPosition(self.visibleSize.width / 2, kBottomMargin)
    self.ball:setPosition(self.visibleSize.width / 2, kBottomMargin + self.paddle:getContentSize().height/2 + self.ball:getContentSize().height/2) 
end

-- ゲーム開始
function GameScene:gameStart()
    self.gamePhase = GamePhase.Playing
    self.label:setVisible(false)
    local velocity = cc.pMul(cc.pNormalize(cc.p(1, 1)), kBallSpeed)
    self.ball:getPhysicsBody():setVelocity(velocity)
end

-- ゲームオーバー
function GameScene:gameOver()
    self.gamePhase = GamePhase.GameOver
    self.label:setString("Game Over")
    self.label:setVisible(true)
    self.ball:getPhysicsBody():setVelocity(cc.p(0,0))
end

-- ゲームクリアー
function GameScene:gameClear()
    self.gamePhase = GamePhase.GameClear
    self.label:setString("Congratulations !!")
    self.label:setVisible(true)
    self.ball:getPhysicsBody():setVelocity(cc.p(0,0))
end

-- タッチイベント処理
function GameScene:touchEvent()
    local previousLocation = nil
    -- タッチ開始
    local function onTouchBegan(touch, event)
        previousLocation = touch:getLocation()

        if self.gamePhase == GamePhase.ReadyToStart then
            self:gameStart()
            return false
        elseif self.gamePhase == GamePhase.GameOver or self.gamePhase == GamePhase.GameClear then
            self:readyToStart()
            return false
        end

        return true
    end

    -- タッチ移動
    local function onTouchMoved(touch, event)
        if self.gamePhase == GamePhase.Playing then
            local location = touch:getLocation()
            self.paddle:setPosition(self.paddle:getPositionX() + location.x - previousLocation.x, self.paddle:getPositionY())
            previousLocation = location
        end
    end
      
    local listener = cc.EventListenerTouchOneByOne:create()
    listener:registerScriptHandler(onTouchBegan, cc.Handler.EVENT_TOUCH_BEGAN )
    listener:registerScriptHandler(onTouchMoved, cc.Handler.EVENT_TOUCH_MOVED )
    local eventDispatcher = self:getEventDispatcher():addEventListenerWithSceneGraphPriority(listener, self)
end

-- 衝突時に呼ばれるイベント処理
function GameScene:contactTest()

    local function onContactPostSolve(contact)
        local a = contact:getShapeA():getBody()
        local b = contact:getShapeB():getBody()
        if a:getCategoryBitmask() > b:getCategoryBitmask() then a, b = b, a end
        
        -- ボールとブロックが衝突した時
        if b:getCategoryBitmask() == kCategoryBlock then
            b:getNode():removeFromParent()
            self.blockCount = self.blockCount - 1
            if self.blockCount == 0 then
                self:gameClear()
            end
        -- ボールと底面が衝突した時
        elseif b:getCategoryBitmask() == kCategoryBottom then
            self:gameOver()
        end
        
        -- ボール速度の減衰防止
        if a:getCategoryBitmask() == kCategoryBall and self.gamePhase == GamePhase.Playing then
            local velocity = a:getVelocity()
            if kBallSpeed * kBallSpeed > cc.pLengthSQ(velocity) then
                velocity = cc.pNormalize(velocity)
                velocity = cc.p(velocity.x * kBallSpeed, velocity.y * kBallSpeed)
                a:setVelocity(velocity)
            end
        end
        
        return true
    end

    -- 衝突時に指定した関数を呼び出すようにする
    local contactListener = cc.EventListenerPhysicsContact:create()
    contactListener:registerScriptHandler(onContactPostSolve, cc.Handler.EVENT_PHYSICS_CONTACT_POSTSOLVE)
    local eventDispatcher = self:getEventDispatcher():addEventListenerWithSceneGraphPriority(contactListener, self)
end

return GameScene
