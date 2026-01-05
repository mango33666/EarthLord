import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    /// 共享的定位管理器（注入到所有子视图）
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(2)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .tag(3)
        }
        .environmentObject(locationManager)  // ⚠️ 关键：注入到所有子视图
        .tint(ApocalypseTheme.primary)
    }
}

#Preview {
    MainTabView()
}
