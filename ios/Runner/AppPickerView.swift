import Foundation
import SwiftUI

#if !targetEnvironment(simulator)
  import FamilyControls

  @available(iOS 16.0, *)
  class AppSelectionModel: ObservableObject {
    @Published var selection = FamilyActivitySelection()
  }

  @available(iOS 16.0, *)
  struct AppPickerView: View {
    @ObservedObject var model: AppSelectionModel
    @State private var isPresented = true
    let onDismiss: () -> Void

    var body: some View {
      Color.clear
        .familyActivityPicker(
          isPresented: $isPresented,
          selection: $model.selection
        )
        .onChange(of: isPresented) { presented in
          if !presented {
            onDismiss()
          }
        }
    }
  }

#else
  // ── SIMULATOR STUBS ──────────────────────────────────────────────
  // FamilyActivitySelection and familyActivityPicker don't exist on simulator.
  // These stubs let the rest of the app compile and show placeholder UI.

  class AppSelectionModel: ObservableObject {
    // Empty — no FamilyActivitySelection on simulator
  }

  struct AppPickerView: View {
    var model: AppSelectionModel
    var onDismiss: () -> Void

    var body: some View {
      VStack(spacing: 20) {
        Image(systemName: "apps.iphone")
          .font(.system(size: 56))
          .foregroundColor(.secondary)
        Text("App Picker")
          .font(.title2).bold()
        Text("App selection requires a real device.\nAll other UI is fully functional.")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
        Button("Done") { onDismiss() }
          .buttonStyle(.borderedProminent)
      }
      .padding(40)
    }
  }
#endif
