/*
 Copyright 2016-present The Material Motion Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import UIKit
import MaterialMotion

public protocol Interaction2 {
  func enable()
  func disable()
}

public protocol SpringInteraction: Interaction2 {
  associatedtype T

  var initialVelocity: T? { get set }
  var destination: T? { get set }

  func start()
  func stop()
}

/**
 A spring pulls a value from an initial position to a destination using a physical simulation of a
 dampened oscillator.

 A spring can be associated with many properties. Each property receives its own distinct simulator
 that reads the property as the initial value and pulls the value towards the destination.
 Configuration values are shared across all running instances.

 **Constraints**

 T-value constraints may be applied to this interaction.
 */
public final class Spring2<T>: SpringInteraction, Stateful where T: Subtractable {
  /**
   Creates a spring with a given threshold and system.

   - parameter threshold: The threshold of movement defining the completion of the spring simulation. This parameter is not used by the Core Animation system and can be left as a default value.
   - parameter system: The system that should be used to drive this spring.
   */
  public init(for path: CoreAnimationKeyPath<T>) {
    self.path = path
  }

  public let path: CoreAnimationKeyPath<T>

  public func enable() {
    guard !enabled else { return }

    enabled = true

    checkAndEmit()
  }
  public func disable() {
    guard enabled else { return }

    enabled = false

    activeKeys.allObjects.forEach { path.removeAnimation(forKey: $0 as String) }
    activeKeys.removeAllObjects()
  }
  private var enabled = false

  public func stop() {
    guard !stopped else { return }

    stopped = true

    activeKeys.allObjects.forEach { path.removeAnimation(forKey: $0 as String) }
    activeKeys.removeAllObjects()
  }
  public func start() {
    guard stopped else { return }
    stopped = false
    checkAndEmit()
  }
  private var stopped = false

  private func checkAndEmit() {
    guard enabled && !stopped else { return }
    guard let destination = destination else { return }

    let key = NSUUID().uuidString

    let animation = CASpringAnimation()

    animation.damping = friction
    animation.stiffness = tension
    animation.mass = mass

    animation.fromValue = path.property.value
    animation.toValue = destination

    if suggestedDuration != 0 {
      animation.duration = TimeInterval(suggestedDuration)
    } else {
      animation.duration = animation.settlingDuration
    }

    path.property.value = destination

    let activeKeys = self.activeKeys
    let hashKey = key as NSString
    activeKeys.add(hashKey)
    _state.value = .active

    let state = _state
    path.add(animation, forKey: key, initialVelocity: initialVelocity) {
      activeKeys.remove(hashKey)
      if activeKeys.count == 0 {
        state.value = .atRest
      }
    }
  }
  var activeKeys = NSHashTable<NSString>()

  public var state: MotionObservable<MotionState> {
    return _state.asStream()
  }
  private let _state = createProperty(withInitialValue: MotionState.atRest)

  /**
   The initial velocity of the spring.

   Applied to the physical simulation only when it starts.
   */
  public var initialVelocity: T?

  /**
   The destination value of the spring represented as a property.

   Changing this property will immediately affect the spring simulation.
   */
  public var destination: T? {
    didSet {
      checkAndEmit()
    }
  }

  /**
   Tension defines how quickly the spring's value moves towards its destination.

   Higher tension means higher initial velocity and more overshoot.
   */
  public var tension = defaultSpringTension

  /**
   Tension defines how quickly the spring's velocity slows down.

   Higher friction means quicker deceleration and less overshoot.
   */
  public var friction = defaultSpringFriction

  /**
   The mass affects the value's acceleration.

   Higher mass means slower acceleration and deceleration.
   */
  public var mass = defaultSpringMass

  /**
   The suggested duration of the spring represented as a property.

   This property may not be supported by all animation systems.

   A value of 0 means this property will be ignored.
   */
  public var suggestedDuration: CGFloat = 0
}

class SpringExampleViewController: ExampleViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    let square = center(createExampleView(), within: view)
    view.addSubview(square)

    let tap = UITapGestureRecognizer()
    view.addGestureRecognizer(tap)

    let spring = Spring2(for: Reactive(square.layer).positionKeyPath)
    spring.friction /= 2
    spring.enable()

    Reactive(tap).didRecognize.subscribeToValue { [weak self] _ in
      guard let strongSelf = self else { return }
      spring.destination = CGPoint(x: CGFloat(arc4random_uniform(UInt32(strongSelf.view.bounds.width))),
                                   y: CGFloat(arc4random_uniform(UInt32(strongSelf.view.bounds.height))))
    }
  }

  override func exampleInformation() -> ExampleInfo {
    return .init(title: type(of: self).catalogBreadcrumbs().last!,
                 instructions: "Tap anywhere to move the view.")
  }
}
