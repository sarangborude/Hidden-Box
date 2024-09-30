//
//  PlaneTrackingManager.swift
//  Hidden Box
//
//  Created by Sarang Borude on 9/27/24.
//

import ARKit
import RealityKit
import SwiftUI
import RealityKitContent


@Observable
@MainActor
class PlaneTrackingManager {
    let session = ARKitSession()
    let planeTracking = PlaneDetectionProvider()
    
    var contentEntity = Entity()
    private var planeEntities = [UUID: Entity]()
    
    var dataProvidersAreSupported: Bool {
        PlaneDetectionProvider.isSupported
    }
    
    var isReadyToRun: Bool {
        planeTracking.state == .initialized
    }
    
    func setupContentEntity() -> Entity {
        contentEntity
    }
    
    /// Responds to events like authorization revocation.
    func monitorSessionEvents() async {
        for await event in session.events {
            switch event {
            case .authorizationChanged(type: _, status: let status):
                print("Authorization changed to: \(status)")
                
                if status == .denied {
                    print("ARKit authorization is denied by the user")
                }
            case .dataProviderStateChanged(dataProviders: let providers, newState: let state, error: let error):
                print("Data provider changed: \(providers), \(state)")
                if let error {
                    print("Data provider reached an error state: \(error)")
                }
            @unknown default:
                fatalError("Unhandled new event type \(event)")
            }
        }
    }
    
    func runARKitSession() async {
        do {
            try await session.run([planeTracking])
        }
        catch {
            print("error starting arkit session: \(error.localizedDescription)")
        }
    }
    
    func processPlaneDetectionUpdates() async {
        for await anchorUpdate in planeTracking.anchorUpdates {

            let anchor = anchorUpdate.anchor

            if anchorUpdate.event == .removed {
                if let entity = planeEntities.removeValue(forKey: anchor.id) {
                    entity.removeFromParent()
                }
                return
            }

            let entity = Entity()
            entity.name = "Plane \(anchor.id)"
            entity.setTransformMatrix(anchor.originFromAnchorTransform, relativeTo: nil)
            
            // Generate a mesh for the plane (for debugging).
            var meshResource: MeshResource? = nil
            do {
                let contents = MeshResource.Contents(planeGeometry: anchor.geometry)
                meshResource = try MeshResource.generate(from: contents)
            } catch {
                print("Failed to create a mesh resource for a plane anchor: \(error).")
                return
            }
            
            var material = UnlitMaterial(color: .red)
            material.blending = .transparent(opacity: .init(floatLiteral: 0))
            
            if let meshResource {
                // Make this plane occlude virtual objects behind it.
                entity.components.set(ModelComponent(mesh: meshResource, materials: [material]))
            }
            
            // Generate a collision shape for the plane (for object placement and physics).
            var shape: ShapeResource? = nil
            do {
                let vertices = anchor.geometry.meshVertices.asSIMD3(ofType: Float.self)
                shape = try await ShapeResource.generateStaticMesh(positions: vertices,
                                                                   faceIndices: anchor.geometry.meshFaces.asUInt16Array())
            } catch {
                print("Failed to create a static mesh for a plane anchor: \(error).")
                return
            }
            
            if let shape {
                entity.components.set(CollisionComponent(shapes: [shape], isStatic: true))
                let physics = PhysicsBodyComponent(mode: .static)
                entity.components.set(physics)
            }
            
            let existingEntity = planeEntities[anchor.id]
            planeEntities[anchor.id] = entity
            
            contentEntity.addChild(entity)
            existingEntity?.removeFromParent()
        }
    }
}


extension MeshResource.Contents {
    init(planeGeometry: PlaneAnchor.Geometry) {
        self.init()
        self.instances = [MeshResource.Instance(id: "main", model: "model")]
        var part = MeshResource.Part(id: "part", materialIndex: 0)
        part.positions = MeshBuffers.Positions(planeGeometry.meshVertices.asSIMD3(ofType: Float.self))
        part.triangleIndices = MeshBuffer(planeGeometry.meshFaces.asUInt32Array())
        self.models = [MeshResource.Model(id: "model", parts: [part])]
    }
}

extension GeometrySource {
    func asArray<T>(ofType: T.Type) -> [T] {
        assert(MemoryLayout<T>.stride == stride, "Invalid stride \(MemoryLayout<T>.stride); expected \(stride)")
        return (0..<count).map {
            buffer.contents().advanced(by: offset + stride * Int($0)).assumingMemoryBound(to: T.self).pointee
        }
    }
    
    func asSIMD3<T>(ofType: T.Type) -> [SIMD3<T>] {
        asArray(ofType: (T, T, T).self).map { .init($0.0, $0.1, $0.2) }
    }
    
    subscript(_ index: Int32) -> (Float, Float, Float) {
        precondition(format == .float3, "This subscript operator can only be used on GeometrySource instances with format .float3")
        return buffer.contents().advanced(by: offset + (stride * Int(index))).assumingMemoryBound(to: (Float, Float, Float).self).pointee
    }
}

extension GeometryElement {
    subscript(_ index: Int) -> [Int32] {
        precondition(bytesPerIndex == MemoryLayout<Int32>.size,
                     """
This subscript operator can only be used on GeometryElement instances with bytesPerIndex == \(MemoryLayout<Int32>.size).
This GeometryElement has bytesPerIndex == \(bytesPerIndex)
"""
        )
        var data = [Int32]()
        data.reserveCapacity(primitive.indexCount)
        for indexOffset in 0 ..< primitive.indexCount {
            data.append(buffer
                .contents()
                .advanced(by: (Int(index) * primitive.indexCount + indexOffset) * MemoryLayout<Int32>.size)
                .assumingMemoryBound(to: Int32.self).pointee)
        }
        return data
    }
    
    func asInt32Array() -> [Int32] {
        var data = [Int32]()
        let totalNumberOfInt32 = count * primitive.indexCount
        data.reserveCapacity(totalNumberOfInt32)
        for indexOffset in 0 ..< totalNumberOfInt32 {
            data.append(buffer.contents().advanced(by: indexOffset * MemoryLayout<Int32>.size).assumingMemoryBound(to: Int32.self).pointee)
        }
        return data
    }
    
    func asUInt16Array() -> [UInt16] {
        asInt32Array().map { UInt16($0) }
    }
    
    public func asUInt32Array() -> [UInt32] {
        asInt32Array().map { UInt32($0) }
    }
}
