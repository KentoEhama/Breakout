
require "Cocos2d"

-- cclog グローバル関数にしました
cclog = function(...)
    print(string.format(...))
end

-- for CCLuaEngine traceback
function __G__TRACKBACK__(msg)
    cclog("----------------------------------------")
    cclog("LUA ERROR: " .. tostring(msg) .. "\n")
    cclog(debug.traceback())
    cclog("----------------------------------------")
    return msg
end

local function main()
    collectgarbage("collect")
    -- avoid memory leak
    collectgarbage("setpause", 100)
    collectgarbage("setstepmul", 5000)
    
    cc.FileUtils:getInstance():addSearchPath("src")
    cc.FileUtils:getInstance():addSearchPath("res")
    cc.Director:getInstance():getOpenGLView():setDesignResolutionSize(320, 480, cc.ResolutionPolicy.SHOW_ALL) -- (480, 320, 0)から修正
    cc.Director:getInstance():setContentScaleFactor(2.0) -- 表示比率
    cc.Director:getInstance():setDisplayStats(true) -- FPSの表示・非表示
    
    --create scene 
    cclog("===シーンの作成を開始します=== %s", os.date("%Y/%m/%d %H:%M:%S"))
    local scene = require("GameScene")
    local gameScene = scene.create()
    --gameScene:playBgMusic()
    
    if cc.Director:getInstance():getRunningScene() then
        cc.Director:getInstance():replaceScene(gameScene)
    else
        cc.Director:getInstance():runWithScene(gameScene)
    end

end


local status, msg = xpcall(main, __G__TRACKBACK__)
if not status then
    error(msg)
end
