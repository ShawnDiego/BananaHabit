import SwiftUI

struct ItemIconView: View {
    let icon: String
    var size: CGFloat = 24
    var color: Color = .blue
    
    private var isEmoji: Bool {
        // 检查是否是 emoji（通过检查第一个字符是否是 emoji）
        if let firstScalar = icon.unicodeScalars.first {
            return firstScalar.properties.isEmoji
        }
        return false
    }
    
    var body: some View {
        Group {
            if isEmoji {
                Text(icon)
                    .font(.system(size: size))
            } else {
                Image(systemName: icon)
                    .font(.system(size: size))
                    .foregroundColor(color)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ItemIconView(icon: "😊", size: 30)
        ItemIconView(icon: "star.fill", size: 30)
    }
} 