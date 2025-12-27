//
//  ContentView.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/27.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Hello, world!")
                .font(.title2)
                .fontWeight(.regular)

            Spacer()
                .frame(height: 40)

            Text("Developed by mango")
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
