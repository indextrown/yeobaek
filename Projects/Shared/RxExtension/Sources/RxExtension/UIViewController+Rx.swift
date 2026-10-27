import ThirdParty
import UIKit

public extension Reactive where Base: UIViewController {
    /// 화면 표시가 끝난 시점을 전달하는 UI 생명주기 이벤트입니다.
    var viewDidAppear: ControlEvent<Void> {
        let events = methodInvoked(
            #selector(UIViewController.viewDidAppear(_:))
        )
        .mapToVoid()

        return ControlEvent(events: events)
    }

    /// 화면이 사라진 시점을 전달하는 UI 생명주기 이벤트입니다.
    var viewDidDisappear: ControlEvent<Void> {
        let events = methodInvoked(
            #selector(UIViewController.viewDidDisappear(_:))
        )
        .mapToVoid()

        return ControlEvent(events: events)
    }
}
