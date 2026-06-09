//
//  LaunchScreenView.swift
//  Little Miss Peregrine
//
//  Created by Nadia on 08/06/26.
//

import Foundation
import SwiftUI

struct LaunchScreenView: View {
    @State private var iconScale: CGFloat = 0.7
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 10

    var body: some View {
        ZStack {
            Color.sand.ignoresSafeArea()

            VStack(spacing: 18) {
                // App Name
                Text("LITTLE MISS PEREGRINE")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundColor(.inkMid)
                    .tracking(1.5)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
                
                // App Icon
                Image("icon") // replace with your asset name if different
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .inkDark.opacity(0.12), radius: 16, x: 0, y: 6)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                textOpacity = 1
                textOffset = 0
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
