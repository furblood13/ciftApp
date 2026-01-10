//
//  LottieView.swift
//  ciftApp
//
//  Created by Generic AI on 06.01.2026.
//

import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    var filename: String
    var loopMode: LottieLoopMode = .loop
    var contentMode: UIView.ContentMode = .scaleAspectFit
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView()
        
        // Explicitly set cache to nil to avoid potential binary mismatch with default arguments
        if let animation = LottieAnimation.named(filename, animationCache: nil) {
            animationView.animation = animation
        } else {
            print("⚠️ [Lottie] Animation '\(filename)' not found")
        }
        
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.play()
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        // Dynamic updates can be handled here if needed
    }
}
