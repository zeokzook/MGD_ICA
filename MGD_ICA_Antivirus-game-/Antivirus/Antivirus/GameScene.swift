//
//  GameScene.swift
//  Antivirus
//
//  Created by TAN, ADAM (Student) on 06/11/2020.
//  Copyright © 2020 TAN, ADAM (Student). All rights reserved.
//

//HOW EVERYTHING LOOKED LIKE BEFORE CHANGING IDEAS

import CoreMotion
import SpriteKit
import GameplayKit

func +(left: CGPoint, right:CGPoint) -> CGPoint
{
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func -(left: CGPoint, right:CGPoint) -> CGPoint
{
  return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func *(point: CGPoint, scalar: CGFloat) -> CGPoint
{
  return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func /(point: CGPoint, scalar: CGFloat) -> CGPoint
{
  return CGPoint(x: point.x / scalar, y: point.y / scalar)
}

#if !(arch(x86_64) || arch(arm64))
  func sqrt(a: CGFloat) -> CGFloat
  {
    return CGFloat(sqrtf(Float(a)))
  }
#endif

extension CGPoint
{
  func length() -> CGFloat
  {
    return sqrt(x * x + y * y)
  }
  
  func normalized() -> CGPoint
  {
    return self / length()
  }
}

enum DimensionFace: CGFloat
{
    case front = 0
    case back  = -1
    case null  = 10
}

struct WallType : OptionSet
{
    let rawValue: UInt8
    init(rawValue: UInt8) {self.rawValue = rawValue}
    
    static let longThin     = WallType(rawValue: 0b01)
    static let shortWideBot = WallType(rawValue: 0b10)
    static let shortWideTop = WallType(rawValue: 0b11)
}

struct PhysicsCategory : OptionSet
{
    let rawValue: UInt32
    init(rawValue: UInt32) {self.rawValue = rawValue}
    
    static let None            = PhysicsCategory(rawValue: 0b0000)
    static let All             = PhysicsCategory(rawValue: UInt32.max)
    static let Enemy           = PhysicsCategory(rawValue: 0b0001) //1
    static let Projectile      = PhysicsCategory(rawValue: 0b0010) //2
    static let Wall            = PhysicsCategory(rawValue: 0b0100) //4
    static let Player          = PhysicsCategory(rawValue: 0b1000) //8
}

class GameScene: SKScene
{
    let player = SKSpriteNode(imageNamed: "BCell")
    let scoreText = SKLabelNode(fontNamed: "ArialMT")
    
    let bgColor = SKColor(red: 0.23, green: 0.0, blue: 0.0, alpha: 1.0)
    let wallColor = UIColor(red: 0.90, green: 0.0, blue: 0.0, alpha: 1.0)
    
    var motionManager: CMMotionManager!
    var calibrated: Double!
    var doneCalibrate = false
    var moveAmtY: CGFloat = 0
    var initPos: CGPoint = CGPoint.zero
    var initTouch: CGPoint = CGPoint.zero
    var currentDimension: DimensionFace = .front
    var wallTimer = 0
    var time = Date()
    var tutorialDone : Bool = false
    var rotate = false
    var score: Int = 0
    
    let projectileSpeed: Double = 0.5 //smaller number is faster
    let moveAmtthreshold: CGFloat = 100.0
    let playerSpeed: CGFloat = 5
    let shootDelay: TimeInterval = 0.25
    
    var collidedCounter = 0
    
    override func didMove(to view: SKView)
    {
        backgroundColor = bgColor
        
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width/2)
        player.physicsBody!.category = .Player
        player.physicsBody!.collision = .None
        player.Dimension = currentDimension
        
        addChild(player)
        
        scoreText.position = CGPoint(x: size.width/2, y: size.height - 25)
        scoreText.fontSize = 25
        scoreText.fontColor = SKColor.white
        scoreText.text = "Score: \(score)"
        
        addChild(scoreText)
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        
        /*run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run({
                    let i = self.random(min:0.0, max:5.0)
                    
                    self.wallTimer += 1
                    
                    if(self.wallTimer == 10)
                    {
                        self.addWall(dimension: self.currentDimension)
                    }
                    else if(i <= 2.0)
                    {
                        self.addEnemy(dimension: .front)
                    }
                    else if(i >= 3.0)
                    {
                        self.addEnemy(dimension: .back)
                    }
                    
                }),
                SKAction.wait(forDuration: 1.0)
            ])
        ))*/
    }
    
    var sentWave: Bool = false
    
    override func update(_ currentTime: TimeInterval)
    {
        #if targetEnvironment(simulator)
        #else
        playerMovement()
        
        /*if(!tutorialDone)
        {
            tutorial()
        }*/
        
        if !sentWave
        {
            waveType1()
            sentWave = true
        }
        
        updateScore()
        print(player.position)
        
        #endif
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if let touch = touches.first as UITouch?
        {
            initTouch = touch.location(in: self.scene!.view)
            moveAmtY = 0
            initPos = self.position
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if let touch = touches.first as UITouch?
        {
            let movingPoint: CGPoint = touch.location(in: self.scene!.view)
            
            moveAmtY = movingPoint.y - initTouch.y
        }
        
    }

    //Shooting
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if moveAmtY < -moveAmtthreshold
        {
            if(currentDimension != .back)
            {
                print("Moving to back")
                switchDimension(toDimension: .back)
            }
        }
        else if moveAmtY > moveAmtthreshold
        {
            if(currentDimension != .front)
            {
                print("Moving to front")
                switchDimension(toDimension: .front)
            }
        }
        else
        {
            shoot(dimension: currentDimension, after: shootDelay)
        }
    }
    
    var movementDone: Bool = false
    var shootDone: Bool = false
    var changeDimen: Bool = false
    var setCurrPlayerPos: Bool = false
    var currentPlayerPos: CGFloat = 0
    
    func tutorial()
    {
        if(!movementDone)
        {
            if(!setCurrPlayerPos)
            {
                currentPlayerPos = player.position.y
                setCurrPlayerPos = true
            }
            
            print("movement tutorial")
            let moveText = SKLabelNode(fontNamed: "Chalkduster")
            moveText.text = "Tilt up and down to move up"
            moveText.fontSize = 65
            moveText.fontColor = SKColor.white
            moveText.position = CGPoint(x: frame.midX + 100, y: frame.midY)
            
            addChild(moveText)
            
            if(player.position.y >= currentPlayerPos - 150)
            {
                movementDone = true
                print("move up done")
            }
            
        }
    }
    
    func playerMovement()
    {
        if let accelerometerData = motionManager.accelerometerData
        {
            if doneCalibrate != true
            {
                calibrated = accelerometerData.acceleration.x
                doneCalibrate = true
            }
        
            if accelerometerData.acceleration.x > calibrated + 0.035
            {
                player.position.y += playerSpeed
            }
            
            if accelerometerData.acceleration.x < calibrated - 0.02
            {
                player.position.y -= playerSpeed
            }
        }
        
        if player.position.y <= 0 + player.size.height / 2
        {
            player.position.y = 0 + player.size.height / 2
        }
        
        if player.position.y >= size.height - player.size.height / 2
        {
            player.position.y = size.height - player.size.height / 2
        }
    }
    
    func random() -> CGFloat
    {
        return CGFloat(Float(arc4random()) / Float(0xFFFFFFFF))
    }
    
    func random(min: CGFloat, max: CGFloat) -> CGFloat
    {
        return random() * (max - min) + min
    }
    
    func addEnemy(dimension: DimensionFace, y: CGFloat = 0, duration: CGFloat = 0)
    {
        let enemy = SKSpriteNode(imageNamed: "RedVirus")
        
        enemy.name = "editable"
        
        enemy.position = CGPoint(x: size.width + enemy.size.width/2, y: y)
        enemy.Dimension = dimension
        
        addChild(enemy)
        
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: enemy.size.width/2)
        enemy.physicsBody!.isDynamic = true
        enemy.physicsBody!.affectedByGravity = false
        enemy.physicsBody!.category = .Enemy
        enemy.physicsBody!.collision = .None
        enemy.physicsBody!.contact = .Player
        
        if(currentDimension == dimension)
        {
            enemy.alpha = 1.0
        }
        else
        {
            enemy.alpha = 0.5
        }

        let actionMove = SKAction.move(to: CGPoint(x: -enemy.size.width/2, y: y), duration: TimeInterval(duration))
        let removeScore = SKAction.run {
            self.score -= 50
        }
        let actionMoveDone = SKAction.removeFromParent()
        
        enemy.run(SKAction.sequence([actionMove, removeScore, actionMoveDone]))
    }
    
    func addWall(dimension: DimensionFace, wallType: WallType)
    {
        var wallRect: CGRect = CGRect(x:0, y:0, width:0, height:0)
        var y: CGFloat = 0
        if wallType == .longThin
        {
            wallRect = CGRect(x:0, y:0, width: 100, height: size.height)
            y = 0
        }
        else if wallType == .shortWideBot
        {
            wallRect = CGRect(x:0, y:0, width: 1000, height: size.height/2)
            y = size.height/2
        }
        else if wallType == .shortWideTop
        {
            wallRect = CGRect(x:0, y:0, width: 1000, height: size.height/2)
            y = 0
        }
        
        let wall = SKShapeNode(rect: wallRect)
    
        wall.name = "editable"
        wall.position = CGPoint(x: size.width + wallRect.size.width, y: y)
        wall.fillColor = wallColor
        wall.Dimension = dimension
        
        addChild(wall)
        
        wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: wallRect.width, height: wallRect.height), center: CGPoint(x: wallRect.width / 2, y: wallRect.height / 2))
        wall.physicsBody!.affectedByGravity = false
        wall.physicsBody!.category = .Wall
        wall.physicsBody!.collision = .None
        wall.physicsBody!.contact = .Player
        
        if(currentDimension == dimension)
        {
            wall.alpha = 1.0
        }
        else
        {
            wall.alpha = 0.5
        }
        
        let actualDuration = 4.0
        let actionMove = SKAction.move(to: CGPoint(x: -size.width - wallRect.width, y: y), duration: TimeInterval(actualDuration))
        let actionMoveDone = SKAction.removeFromParent()
        let actionResetTimer = SKAction.run
        {
            print(self.wallTimer)
            self.wallTimer = 0
            print(self.wallTimer)
        }
        
        wall.run(SKAction.sequence([actionMove, actionMoveDone, actionResetTimer]))
    }
    
    func shoot(dimension: DimensionFace, after timeInterval: Double)
    {
        guard Date() - timeInterval > time else {
            return
        }

        let projectile = SKSpriteNode(imageNamed: "Antibody")
        
        projectile.position = player.position
        projectile.name = "editable"
        
        projectile.Dimension = dimension
        
        addChild(projectile)
        
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2 - 2)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody!.affectedByGravity = false
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        projectile.physicsBody!.category = .Projectile
        projectile.physicsBody!.collision = .None
        projectile.physicsBody!.contact = .Enemy
        
        let shootAmount = projectile.position.x * 10
        let realDest = CGPoint(x: shootAmount, y:0) + projectile.position
        let actionRotate = SKAction.rotate(byAngle: -(CGFloat.pi)/2, duration: 0)
        let actionMove = SKAction.move(to: realDest, duration: projectileSpeed)
        let actionMoveDone = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([actionRotate, actionMove, actionMoveDone]))
        
        time = Date()
    }
    
    func switchDimension(toDimension: DimensionFace)
    {
        currentDimension = toDimension
        player.Dimension = toDimension
        
        self.enumerateChildNodes(withName: "editable")
        {
            (node, stop)in
            
            if(toDimension == .front)
            {
                if node.Dimension == .front
                {
                    node.alpha = 1.0
                }
                else
                {
                    node.alpha = 0.5
                }
            }
            else if(toDimension == .back)
            {
                if node.Dimension == .front
                {
                    node.alpha = 0.5
                }
                else
                {
                    node.alpha = 1.0
                }
            }
        }
    }
    
    func waveType1()
    {
        run(SKAction.sequence([
            SKAction.run({self.addEnemy(dimension: self.currentDimension, y: self.player.position.y, duration: 2.0)}),
            SKAction.run({self.addEnemy(dimension: self.currentDimension, y: self.player.position.y + 100, duration: 2.0)}),
            SKAction.run({self.addEnemy(dimension: self.currentDimension, y: self.player.position.y + 200, duration: 2.0)}),
            SKAction.wait(forDuration: 2.0),
            SKAction.run({self.addEnemy(dimension: self.currentDimension, y: self.player.position.y, duration: 3.0)}),
            SKAction.wait(forDuration: 3.0),
            SKAction.run({self.addWall(dimension: self.currentDimension, wallType: .shortWideTop)}),
            SKAction.wait(forDuration: 2.0),
            SKAction.run({self.addWall(dimension: self.currentDimension, wallType: .shortWideBot)}),
            SKAction.wait(forDuration: 2.0),
            SKAction.run({self.addWall(dimension: self.currentDimension, wallType: .longThin)}),
            SKAction.wait(forDuration: 2.0),
            SKAction.run({self.sentWave = false})
        ]))
    }
    
    func updateScore()
    {
        scoreText.text = "Score: \(score)"
    }
    
    func PlayerDied()
    {
        print("Oh no you dead!")
        
        let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
        let gameOverScene = GameOverScene(size: self.size, won: false)
        self.view?.presentScene(gameOverScene, transition: reveal)
    }
    
    func collidedEnemyWithPlayer(Enemy: SKSpriteNode, Player: SKSpriteNode)
    {
        collidedCounter += 1
        print("Player Collided #\(collidedCounter)")
        PlayerDied()
    }
    
    func collidedEnemyWithProjectile(Enemy: SKSpriteNode, Projectile: SKSpriteNode)
    {
        Enemy.removeFromParent()
        Projectile.removeFromParent()
        
        score += 100
        
        collidedCounter += 1
        print("Projectile Collided #\(collidedCounter)")
    }
    
}

extension SKNode
{
    var Dimension: DimensionFace
    {
        get
        {
            if self.zPosition == DimensionFace.front.rawValue
            {
                return DimensionFace.front
            }
            else if self.zPosition == DimensionFace.back.rawValue
            {
                return DimensionFace.back
            }
            else
            {
                return DimensionFace.null
            }
        }
        set(newValue)
        {
            self.zPosition = newValue.rawValue
        }
    }
}

extension SKPhysicsBody
{
    var category: PhysicsCategory
    {
        get
        {
            return PhysicsCategory(rawValue: self.categoryBitMask)
        }
        set(newValue)
        {
            self.categoryBitMask = newValue.rawValue
        }
    }
    
    var collision: PhysicsCategory
    {
        get
        {
            return PhysicsCategory(rawValue: self.collisionBitMask)
        }
        set(newValue)
        {
            self.collisionBitMask = newValue.rawValue
        }
    }
    
    var contact: PhysicsCategory
    {
        get
        {
            return PhysicsCategory(rawValue: self.contactTestBitMask)
        }
        set(newValue)
        {
            self.contactTestBitMask = newValue.rawValue
        }
    }
}

extension GameScene: SKPhysicsContactDelegate
{
    func didBegin(_ contact: SKPhysicsContact)
    {
        if contact.bodyA.node?.Dimension == contact.bodyB.node?.Dimension
        {
            let contactCategory: PhysicsCategory = [contact.bodyA.category, contact.bodyB.category]
            
            if contactCategory.contains([.Player, .Enemy])
            {
                if contact.bodyA.category == .Player
                {
                    if let player = contact.bodyA.node as? SKSpriteNode, let enemy = contact.bodyB.node as? SKSpriteNode
                    {
                        collidedEnemyWithPlayer(Enemy: enemy, Player: player)
                    }
                }
                else
                {
                    if let enemy = contact.bodyA.node as? SKSpriteNode, let player = contact.bodyB.node as? SKSpriteNode
                    {
                        collidedEnemyWithPlayer(Enemy: enemy, Player: player)
                    }
                }
            }
            
            if contactCategory.contains([.Projectile, .Enemy])
            {
                if contact.bodyA.category == .Projectile
                {
                    if let projectile = contact.bodyA.node as? SKSpriteNode, let enemy = contact.bodyB.node as? SKSpriteNode
                    {
                        collidedEnemyWithProjectile(Enemy: enemy, Projectile: projectile)
                    }
                }
                else
                {
                    if let enemy = contact.bodyA.node as? SKSpriteNode, let projectile = contact.bodyB.node as? SKSpriteNode
                    {
                        collidedEnemyWithProjectile(Enemy: enemy, Projectile: projectile)
                    }
                }
            }
            
            
            if contactCategory.contains([.Wall, .Player])
            {
                PlayerDied()
            }
        }
        
    }
}
