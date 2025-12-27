//
//  TestView.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/28.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color(red: 0.7, green: 0.85, blue: 1.0)
                .ignoresSafeArea()

            Text("这里是分支宇宙的测试页")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.black)
        }
    }
}

#Preview {
    TestView()
}
