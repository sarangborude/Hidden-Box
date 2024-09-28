//
//  ImmersiveView.swift
//  Hidden Box
//
//  Created by Sarang Borude on 8/7/24.
//

import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct ImmersiveView: View {
    
    @State private var boxTopLeft = Entity()
    @State private var boxTopRight = Entity()
    @State private var boxTopCollision = Entity()
    //@State private var leftFingerSphere = Entity()
    //@State private var rightFingerSphere = Entity()
    @State private var isBoxOpen = false
    
    @State private var planeTracking = PlaneTrackingManager()
    
    @State private var openParticleEntity = Entity()
    
    @State private var animationCompletionSubcription: AnyCancellable?
    //@State private var collisionSubscription: EventSubscription?
    //@State private var fingerCollisionSubscription: EventSubscription?
    //@State private var fingercollisionCancellable: Cancellable?
    
    @State private var subs: [EventSubscription] = []
    
    @State private var handTrackingManager: HandTrackingManager?
    
    init() {
        ToyComponent.registerComponent()// call this once to register the component
    }
    
    var body: some View {
        RealityView { content in
            
            let anchor = AnchorEntity(.plane(.horizontal, classification: .table, minimumBounds: [0.5,0.5]))
            content.add(anchor)
            
            content.add(planeTracking.setupContentEntity())
            
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
                
                immersiveContentEntity.position = [0, -0.25, 0]
                anchor.addChild(immersiveContentEntity)
                
                if let boxTopLeft = immersiveContentEntity.findEntity(named: "OcclusionTop_Left"),
                   let boxTopRight = immersiveContentEntity.findEntity(named: "OcclusionTop_Right"),
                   let boxTopCollision = immersiveContentEntity.findEntity(named: "Top_Collision"),
                   let openParticleEntity = immersiveContentEntity.findEntity(named: "OpenParticleEmitter") {
                    self.boxTopLeft = boxTopLeft
                    self.boxTopRight = boxTopRight
                    self.boxTopCollision = boxTopCollision
                    self.openParticleEntity = openParticleEntity
//                    self.leftFingerSphere = leftFingerSphere
//                    self.rightFingerSphere = rightFingerSphere
//                    
//                    collisionSubscription = content.subscribe(to: CollisionEvents.Began.self, on: self.boxTopCollision, { collisionEvent in
//                        print("something collided with the box top")
//                        //self.playOpenBoxAnimation()
//                        //collisionSubscription = nil
//                    })
                    

                }
            }
            
//            handTrackingManager = await HandTrackingManager()
//            if let handTrackingManager  = handTrackingManager {
//                content.add(handTrackingManager.leftIndexFingerTip)
//                content.add(handTrackingManager.rightIndexFingerTip)
//                
//            
//                
//                //handTrackingManager.leftIndexFingerTip.addChild(leftFingerSphere)
//                handTrackingManager.rightIndexFingerTip.addChild(rightFingerSphere)
//            }
        }
        .gesture(
            DragGesture()
                .targetedToEntity(where: .has(ToyComponent.self))
                .onChanged({ value in
                    value.entity.position = value.convert(value.location3D, from: .local, to: value.entity.parent!)
//                    
//                    if var pb = value.entity.components[PhysicsBodyComponent.self] {
//                        pb.mode = .kinematic
//                        value.entity.components[PhysicsBodyComponent.self] = pb
//                    }
                    value.entity.components[PhysicsBodyComponent.self] = .none
                })
                .onEnded({ value in
                    
//value.entity.components.set(CollisionComponent(shapes: [.generateBox(size: [0.1, 0.1, 0.1])], isStatic: false))
                    let material = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.0)
                    let pb = PhysicsBodyComponent(material: material)
                    value.entity.components.set(pb)
                    //let originalParent = value.entity.parent!
                    //let parent = planeTracking.addCube(tapLocation: value.entity.position(relativeTo: nil))
                    let pos = value.entity.position(relativeTo: nil)
                    planeTracking.contentEntity.addChild(value.entity)
                    value.entity.setPosition(pos, relativeTo: nil)
            
                    
                })
        )
        .gesture(
            SpatialTapGesture()
                .targetedToEntity(boxTopCollision)
                .onEnded({ value in
                    self.playOpenBoxAnimation()
                })
        )
//        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
//            print("SpatialTap")
//            let location3D = value.convert(value.location3D, from: .local, to: .scene)
//            planeTracking.addCube(tapLocation: location3D)
//        })
        .task {
            await planeTracking.monitorSessionEvents()
        }
        .task {
            await planeTracking.runARKitSession()
        }
        .task {
            await planeTracking.processPlaneDetectionUpdates()
        }
    }
    
    func playOpenBoxAnimation() {
        guard !isBoxOpen else { return }
        isBoxOpen.toggle()
        
        var leftTransform = boxTopLeft.transform
        var rightTransform = boxTopRight.transform
        
        leftTransform.translation += [-0.25,0,0]
        rightTransform.translation += [0.25,0,0]
        
        boxTopLeft.move(to: leftTransform, relativeTo: boxTopLeft.parent, duration: 3, timingFunction: .easeInOut)
        boxTopRight.move(to: rightTransform, relativeTo: boxTopRight.parent, duration: 3, timingFunction: .easeInOut)
        
        
        // Play animation after the box opens.
        animationCompletionSubcription = boxTopLeft.scene?.publisher(for: AnimationEvents.PlaybackCompleted.self, on: boxTopLeft).sink { _ in
            print("Now we play the box open animation")
            boxTopLeft.removeFromParent()
            boxTopRight.removeFromParent()
            boxTopCollision.removeFromParent()
            DispatchQueue.main.async {
                if var particleEmitter = openParticleEntity.components[ParticleEmitterComponent.self] {
                    particleEmitter.isEmitting = true
                    print("playing open animation")
                    openParticleEntity.components[ParticleEmitterComponent.self] = particleEmitter
                }
            }
         
            self.animationCompletionSubcription = nil
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}