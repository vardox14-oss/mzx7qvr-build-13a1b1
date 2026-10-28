import SwiftUI

/// Radial spider web drawn in a corner (Halloween), like the website's top-right web.
struct SpiderWeb: View {
    var strands = 7
    var rings = 4
    var body: some View {
        Canvas { ctx, size in
            let origin = CGPoint(x: size.width, y: 0)      // anchored top-right corner
            let radius = max(size.width, size.height)
            let start = Double.pi * 0.5
            let end = Double.pi
            var spokes: [CGPoint] = []
            for i in 0...strands {
                let a = start + (end - start) * Double(i) / Double(strands)
                let p = CGPoint(x: origin.x + cos(a) * radius, y: origin.y + sin(a) * radius)
                spokes.append(p)
                var path = Path(); path.move(to: origin); path.addLine(to: p)
                ctx.stroke(path, with: .color(.white.opacity(0.07)), lineWidth: 1)
            }
            for r in 1...rings {
                let t = Double(r) / Double(rings)
                var path = Path()
                for (i, _) in spokes.enumerated() {
                    let a = start + (end - start) * Double(i) / Double(strands)
                    let p = CGPoint(x: origin.x + cos(a) * radius * t, y: origin.y + sin(a) * radius * t)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                ctx.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Soft eclipse arc glow behind the hero, echoing the website's right panel.
struct EclipseGlow: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(LinearGradient(colors: [Theme.accent.opacity(0.0), Theme.accent2.opacity(0.9), Season.pumpkin.opacity(0.0)],
                                       startPoint: .leading, endPoint: .trailing), lineWidth: 2)
                .blur(radius: 1)
            Circle()
                .fill(RadialGradient(colors: [Theme.accent.opacity(0.25), .clear], center: .center, startRadius: 2, endRadius: 150))
        }
        .allowsHitTesting(false)
    }
}

/// The DarkGPT mark with a ring of orbiting model "chips", like the website hero.
struct OrbitHero: View {
    @State private var spin = false
    private let chips = 9

    var body: some View {
        ZStack {
            EclipseGlow().frame(width: 230, height: 230)

            ForEach(0..<chips, id: \.self) { i in
                let angle = Double(i) / Double(chips) * 2 * .pi
                let r: CGFloat = 100
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.stroke, lineWidth: 1))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().fill(Theme.accent2.opacity(i % 3 == 0 ? 0.8 : 0.0)).frame(width: 6, height: 6))
                    .offset(x: cos(angle) * r, y: sin(angle) * r)
            }
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 60).repeatForever(autoreverses: false), value: spin)

            Image("Logo").resizable().scaledToFit().frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.6), radius: 24)
        }
        .frame(height: 230)
        .onAppear { spin = true }
    }
}
