import AppKit

final class MenuBarIconGenerator {
    
    static func generateIcon(
        text: String,
        font: NSFont = .monospacedSystemFont(ofSize: 9, weight: .semibold),
        spacing: CGFloat = 0,
        kern: CGFloat = 0
    ) -> NSImage {
        
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = spacing
        style.lineSpacing = spacing
        style.alignment = .right
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: style,
            .kern: kern
        ]
        
        let textSize = text.size(withAttributes: attributes)
        // Add some padding
        let width = max(66, textSize.width + 10) 
        let height: CGFloat = 22
        
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let textRect = NSRect(
                x: (rect.width - textSize.width) / 2, // Center horizontally
                y: (rect.height - textSize.height) / 2, // Center vertically
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
            return true
        }
        
        image.isTemplate = true
        return image
    }
}
