import RealityKit

// Ensure you register this component in your app’s delegate using:
// ToyComponent.registerComponent()
public struct ToyComponent: Component, Codable {
    // This is an example of adding a variable to the component.
    var count: Int = 0

    public init() {
    }
}
