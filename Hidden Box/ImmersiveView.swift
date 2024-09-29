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
    @State private var openParticleEntity = Entity()
    @State private var isBoxOpen = false
    @State private var planeTracking = PlaneTrackingManager()
    @State private var animationCompletionSubcription: AnyCancellable?
    
    init() {
        ToyComponent.registerComponent() //call this once to register the component
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
                }
            }
        }
        .gesture(
            DragGesture()
                .targetedToEntity(where: .has(ToyComponent.self))
                .onChanged({ value in
                    value.entity.position = value.convert(value.location3D, from: .local, to: value.entity.parent!)
                    value.entity.components[PhysicsBodyComponent.self] = .none
                })
                .onEnded({ value in
                    
                    let material = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.0)
                    let pb = PhysicsBodyComponent(material: material)
                    value.entity.components.set(pb)
                    
                    /*
                     The object was not resting on the plane due to some
                     RealityKit physics optimization based on entity hierarchy
                     Changing the parent of the manipulated entity to the root entity
                     where all the planes are make the collisions work
                     otherwise all the objects go through the plane colliders
                     */
                    planeTracking.contentEntity.addChild(value.entity, preservingWorldTransform: true)
                })
        )
        .gesture(
            SpatialTapGesture()
                .targetedToEntity(boxTopCollision)
                .onEnded({ value in
                    self.playOpenBoxAnimation()
                })
        )
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

            boxTopLeft.removeFromParent()
            boxTopRight.removeFromParent()
            boxTopCollision.removeFromParent()
           
            if var particleEmitter = openParticleEntity.components[ParticleEmitterComponent.self] {
                particleEmitter.isEmitting = true
                openParticleEntity.components[ParticleEmitterComponent.self] = particleEmitter
            }
            
            self.animationCompletionSubcription = nil
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
