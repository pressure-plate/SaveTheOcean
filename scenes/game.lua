
local composer = require( "composer" )

local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

-- set up physics
local physics = require( "physics" )
physics.start()

-- load submarine module
local subMod = require( "scenes.game.submarine" )

-- load background module
local bgMod = require( "scenes.game.background" )

-- load spawner module
local spawnMod = require( "scenes.game.spawner" )

-- load savedata module
local savedata = require( "scenes.libs.savedata" )

-- initialize variables -------------------------------------------------------

local font = composer.getVariable( "defaultFontParams" )

local score = 0
local scoreText

local scoreMultiplier = 1
local scoreMultiplierText

local seaLifeMax = 1500
local seaLife = seaLifeMax
local seaLifeProgressView

local maxGameSpeed = 3

local isGameOver = false

local updateGameSpeedTimer
local clearObjectsTimer
local updateSeaLifeTimer
local updateScoreMultiplierTimer

local musicTrack
local groundObjPickSound
local floatingObjPickSound
local obstacleCollisionSound
local deadSeaSound
local multiplierUpSound

-- display groups
local bgGroup
local mainGroup
local submarineGroup
local uiGroup

-- assets dir
local uiDir = "assets/ui/" -- user interface assets dir


-- ----------------------------------------------------------------------------
-- game functions
-- ----------------------------------------------------------------------------

local function updateGameSpeed()

	local gs = composer.getVariable( "gameSpeed" )

	-- limit game speed to maxGameSpeed
	if ( gs < maxGameSpeed ) then 

		local st = composer.getVariable( "startTime" )
		gs = 1 + ( (os.time() - st) / 100 )
		--gs = 1 + ( (os.time() - st) / 10 ) -- TEST
		--gs = 3 -- TEST
		composer.setVariable( "gameSpeed", gs )
	end

	--print( "gameSpeed: ", gs ) -- TEST
end

local function exitGame()
	
	composer.gotoScene( "scenes.menu", { time=800, effect="crossFade" } )
end

local function gameOver()

	-- CRITICAL CHECK: check if the gameOver function has already been called
	if ( isGameOver == true ) then
		return -- abort gameOver call
	end
	
	-- set gameOver as called
	isGameOver = true

	-- stop the music
	audio.stop( 1 )

	-- stop screen objects movement
	bgMod.setStopScrolling( true )
	physics.pause()
	subMod.cancAllSubTrans()

	-- set fading black screen
	local blackScreen = display.newRect( uiGroup, display.contentCenterX, display.contentCenterY, 3000, 1080 )
	blackScreen.alpha = 0.6
	blackScreen:setFillColor( 0, 0, 0 ) -- black
	
	-- prevent further touch interactions with the game after the game over
	blackScreen:addEventListener( "touch", function (event) return true end )

	-- display game over
	local gameOverText = display.newText( uiGroup, "GAME OVER", display.contentCenterX, display.contentCenterY-200, font.path, 140 )
	gameOverText:setFillColor( font.colorR, font.colorG, font.colorB )

	-- display score
	local scoredText = display.newText( uiGroup, "SCORED: " .. score, display.contentCenterX, display.contentCenterY+100, font.path, 120 )
	scoredText:setFillColor( font.colorR, font.colorG, font.colorB )

	-- save score
	savedata.addNewScore( score )

	-- call exitGame function after a short delay
	timer.performWithDelay( 4000, exitGame )
end

local function onCollision( event )
 
    -- detect "began" phase of collision
    if ( event.phase == "began" ) then
 
        -- rename for simplicity
        local obj1 = event.object1
		local obj2 = event.object2

		-- handle collisions concerning the "submarine" name
		-- no way to determine who is who, so we write both conditions
		if ( obj1.myName == "submarine" or obj2.myName == "submarine" ) then

			-- rename for convenience
			local collidingObj
			if ( obj1.myName == "submarine" ) then
				collidingObj = obj2
			else
				collidingObj = obj1
			end

			-- handle collision with pickable object type -------------------------------
			if ( collidingObj.myType == "pickableObject" ) then
				-- update score and sea life based on name of "collidingObj"
				if ( collidingObj.myName == "groundObject" ) then
					-- play pick sound
					audio.play( groundObjPickSound )

					score = math.floor( score + ( 150 * scoreMultiplier ) )
					seaLife = seaLife + 200

				elseif ( collidingObj.myName == "floatingObject" ) then
					-- play pick sound
					audio.play( floatingObjPickSound )

					score = math.floor( score + ( 50 * scoreMultiplier ) )
					seaLife = seaLife + 50
				end

				-- check bounds of sea life
				if ( seaLife > seaLifeMax ) then
					seaLife = seaLifeMax
				end

				-- update score text
				scoreText.text = "Score: " .. score
				
				-- update sea life bar
				seaLifeProgressView:setProgress( seaLife / seaLifeMax )

				-- remove "collidingObj" reference from "screenObjectsTable"
				local screenObjectsTable = composer.getVariable( "screenObjectsTable" )
				for i = #screenObjectsTable, 1, -1 do
					if ( screenObjectsTable[i] == collidingObj ) then
						table.remove( screenObjectsTable, i )
						break
					end
				end

				-- remove "collidingObj" from display
				display.remove( collidingObj )
			
			-- handle collision with "obstacleObject" type ------------------------------
			elseif ( collidingObj.myType == "obstacleObject" ) then

				-- play obstacleCollisionSound
				audio.play( obstacleCollisionSound )

				gameOver()
			end

		-- handle collisions concerning the "obstacleObject" type
		-- this check is done to avoid losing score on objects that are impossible to pick, deleting them from game
		elseif ( obj1.myType == "obstacleObject" or obj2.myType == "obstacleObject" ) then

			-- rename for convenience
			local collidingObj
			if ( obj1.myType == "obstacleObject" ) then
				collidingObj = obj2
			else
				collidingObj = obj1
			end

			-- remove "pickableObject" type colliding with he "obstacleObject" type
			if ( collidingObj.myType == "pickableObject" ) then

				-- remove "collidingObj" reference from "screenObjectsTable"
				local screenObjectsTable = composer.getVariable( "screenObjectsTable" )
				for i = #screenObjectsTable, 1, -1 do
					if ( screenObjectsTable[i] == collidingObj ) then
						table.remove( screenObjectsTable, i )
						break
					end
				end

				-- remove "collidingObj" from display
				display.remove( collidingObj )
			end
		end
    end
end

local function clearObjects()
 
	-- remove objects which have drifted off screen

	local screenObjectsTable = composer.getVariable( "screenObjectsTable" )
	
	for i = #screenObjectsTable, 1, -1 do
		
		local thisObject = screenObjectsTable[i]
		
		if ( thisObject.x < -800 ) then

            display.remove( thisObject )
            table.remove( screenObjectsTable, i )
        end
    end
end

local function updateSeaLife()
 
	-- update sea life when you miss an item to pick

	local screenObjectsTable = composer.getVariable( "screenObjectsTable" )
	
	for i = #screenObjectsTable, 1, -1 do
		
		local thisObject = screenObjectsTable[i]

		-- the nil check is to avoid race conditions with clearObjects()
		if ( thisObject ~= nil and thisObject.x < 0 ) then
			
			if ( thisObject.myName == "groundObject" or thisObject.myName == "floatingObject" ) then

				-- check if the item is not already counted
				if ( thisObject.mySeaLife ) then
					-- update sea life value based on missed item
					if ( thisObject.myName == "groundObject" ) then
						seaLife = seaLife - 150
					elseif ( thisObject.myName == "floatingObject" ) then
						seaLife = seaLife - 80
					end

					-- set the item as counted
					thisObject.mySeaLife = false
				end

				-- check if game over
				if ( seaLife <= 0 ) then

					if ( isGameOver == false ) then
						-- play deadSeaSound
						audio.play( deadSeaSound )
					end

					gameOver()
					break -- the game is over, no need to finish the for
				end
            end
        end
	end
	
	-- update sea life bar
	seaLifeProgressView:setProgress( seaLife / seaLifeMax )
end

local function newProgressView( percent, xPos, yPos )
	
	local assetWidth = 200
	local assetHeight = 40

	-- create a new display group
	local progressView = display.newGroup()

	-- insert in the uiGroup
	uiGroup:insert( progressView )
	
	-- set image and mask
	progressView.backgound = display.newImageRect( progressView, uiDir .. "pvBackground.png", assetWidth, assetHeight )
    local mask = graphics.newMask( uiDir .. "pvMask.png" )
	progressView:setMask( mask )
	
	-- set a color filled Rect to progressively cover the bar
    progressView.progress = display.newRect( progressView, assetWidth/2, 0, assetWidth, assetHeight )
    progressView.progress:setFillColor( 0, 0.25, 0.5 )
    progressView.progress.anchorX = 1 -- align
    progressView.progress.width = assetWidth - ( percent * assetWidth ) -- set percent
 
	-- add method to set the percent of the bar
	function progressView:setProgress( percent )
		
		-- update without animation
		--self.progress.width = assetWidth - ( percent * assetWidth )

		-- update WITH animation
		transition.cancel( self.progress )
		transition.to( self.progress, { time = 200, width = assetWidth - ( percent * assetWidth ) } )
	end

	-- set position of progressView group
	progressView.x = xPos
	progressView.y = yPos
	
	-- return the obj created
    return progressView
end

local function setScoreMultiplier( newValue )

    if ( scoreMultiplier ~= newValue ) then

        -- update value
        scoreMultiplier = newValue

		-- update visible text
		scoreMultiplierText.text = "X" .. scoreMultiplier

		-- set visible
		scoreMultiplierText.isVisible = true

		-- animate
		local fromX = scoreMultiplierText.x - 500
		local fromY = scoreMultiplierText.y + 400
		local fromScaleX = 3
		local fromScaleY = 3
		transition.from( scoreMultiplierText, { timer = 500, xScale = fromScaleX, yScale = fromScaleY, x = fromX, y = fromY } )
	end
end

local function updateScoreMultiplier()

	-- play multiplierUpSound
	audio.play( multiplierUpSound )

    setScoreMultiplier( scoreMultiplier + 0.25 )
end


-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

	local sceneGroup = self.view
	-- Code here runs when the scene is first created but has not yet appeared on screen

	physics.pause()  -- Temporarily pause the physics engine (we don't want the game to really start yet)


	-- set composer game vars
	composer.setVariable( "startTime", os.time() ) -- save game start time
	composer.setVariable( "gameSpeed", 1 ) -- set initial game speed
	composer.setVariable( "screenObjectsTable", {} ) -- keep a table of screen objects to clear during game and other purposes


	-- Set up display groups
	-- NOTE: here we use the Group vars initialized earlier
    bgGroup = display.newGroup()  -- display group for background
    sceneGroup:insert( bgGroup )  -- insert into the scene's view group
 
    mainGroup = display.newGroup()  -- display group for the game objects
	sceneGroup:insert( mainGroup )  -- insert into the scene's view group

	submarineGroup = display.newGroup()  -- display group for the submarine object
	sceneGroup:insert( submarineGroup )  -- insert into the scene's view group
 
    uiGroup = display.newGroup()    -- display group for UI
	sceneGroup:insert( uiGroup )    -- insert into the scene's view group

	-- load audio (sounds and streams)
	local audioDir = composer.getVariable( "audioDir" )
	musicTrack = audio.loadStream( audioDir .. "F777-TheSevenSeas.mp3" )
	groundObjPickSound = audio.loadSound( audioDir .. "sfx/pickGroundObj.wav" )
	floatingObjPickSound = audio.loadSound( audioDir .. "sfx/pickFloatingObj.wav" )
	obstacleCollisionSound = audio.loadSound( audioDir .. "sfx/explosion.wav" )
	deadSeaSound = audio.loadSound( audioDir .. "sfx/deadSea.wav" )
	multiplierUpSound = audio.loadSound( audioDir .. "sfx/multiplierUp.wav" )

	-- set event listener to update game speed
	updateGameSpeedTimer = timer.performWithDelay( 1000, updateGameSpeed, 0 )

	-- create background
	bgMod.create( bgGroup )	

	-- create submarine
	subMod.create( submarineGroup, mainGroup )

	-- create spawner
	spawnMod.create( mainGroup )

	-- global collision listener
	Runtime:addEventListener( "collision", onCollision )

	-- display score
	scoreText = display.newText( uiGroup, "SCORE: " .. score, display.contentWidth-50, 40, font.path, 70 )
	scoreText.anchorX = 1 -- align
	scoreText:setFillColor( font.colorR, font.colorG, font.colorB )

	-- display score multiplier
	scoreMultiplierText = display.newText( uiGroup, "X" .. scoreMultiplier, display.contentWidth-50, 100, font.path, 80 )
	scoreMultiplierText.anchorX = 1 -- align
	scoreMultiplierText.isVisible = false
	scoreMultiplierText:setFillColor( 1, 0, 0 )

	-- display sea life bar (progress view)
	seaLifeProgressView = newProgressView( 1, display.contentCenterX, 40 )
	
	-- set timer to trigger the update sea life at regular intervals
	updateSeaLifeTimer = timer.performWithDelay( 1000, updateSeaLife, 0 )

	-- set timer to trigger the clear objects function at regular intervals
	clearObjectsTimer = timer.performWithDelay( 2100, clearObjects, 0 )
end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)

		-- set timer to update the score multiplier (+0.25 every 30secs)
		updateScoreMultiplierTimer = timer.performWithDelay( 30000, updateScoreMultiplier, 0)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen

		-- re-start physics engine ( previously stopped in create() )
		physics.start()

		-- set the objects spawner
		spawnMod.showDid()

		-- start playing the music (in loop)
        audio.play( musicTrack, { channel=1, loops=-1 } )
	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen

		-- remove Runtime listeners
		Runtime:removeEventListener( "collision", onCollision )

		-- cancel timers
		timer.cancel( updateGameSpeedTimer )
		timer.cancel( clearObjectsTimer )
		timer.cancel( updateSeaLifeTimer )
		timer.cancel( updateScoreMultiplierTimer )

		-- clear loaded modules
		bgMod.hideDid()
		subMod.hideDid()
		spawnMod.hideDid()

		-- stop all audio playing
		audio.stop()

		-- remove the scene from cache 
		-- NOTE: this function entirely removes the scene and all the objects and variables inside,
		--			in particular it takes care of display.remove() all display objects inside sceneGroup hierarchy
		--			but NOTE that it doesn't remove things like timers or listeners attached to the "Runtime" object (so we took care of them manually)
		composer.removeScene( "scenes.game" )
	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view

	-- dispose loaded audio
	audio.dispose( musicTrack )
	audio.dispose( groundObjPickSound )
	audio.dispose( floatingObjPickSound )
	audio.dispose( obstacleCollisionSound )
	audio.dispose( deadSeaSound )
	audio.dispose( multiplierUpSound )
end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene
