//
//  HandTrackingManager.swift
//  Hidden Box
//
//  Created by Sarang Borude on 9/27/24.
//

// we do not need this class
//
import RealityKit
import SwiftUI

@Observable
class HandTrackingManager {
    var leftIndexFingerTip = Entity()
    var rightIndexFingerTip = Entity()
    var session = SpatialTrackingSession()
    
    
    let configuration = SpatialTrackingSession.Configuration(tracking: [.hand])
    
    
    init() async {
        
        if let unavailableCapabilities = await session.run(configuration) {
            if unavailableCapabilities.missingAuthorizations.contains(.handTracking) {
                print ("Hand tracking is unauthorized")
            }
        }
        

        
        leftIndexFingerTip = await AnchorEntity(.hand(.left, location: .indexFingerTip))
        rightIndexFingerTip = await AnchorEntity(.hand(.right, location: .indexFingerTip))
        
        
        
        
        
    }
}
