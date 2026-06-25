import SwiftUI

struct NodeListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if appState.routes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Nodes")
                            .font(.title2).bold()
                        Text("Connect to a disaster-radio node to see nearby nodes.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(appState.routes) { route in
                        HStack {
                            Image(systemName: "dot.radiowaves.right")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.mac)
                                    .font(.system(.body, design: .monospaced))
                                HStack(spacing: 12) {
                                    Label("\(route.hops) hop\(route.hops == 1 ? "" : "s")",
                                          systemImage: "arrow.triangle.branch")
                                    Label("metric \(route.metric)",
                                          systemImage: "chart.bar")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(appState.routes.count) Nearby Node\(appState.routes.count == 1 ? "" : "s")")
        }
    }
}
