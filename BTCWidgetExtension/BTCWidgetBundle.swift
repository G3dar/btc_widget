import WidgetKit
import SwiftUI

@main
struct BTCWidgetBundle: WidgetBundle {
    var body: some Widget {
        BTCLockScreenWidget()
        BTCHomeScreenWidget()
    }
}
