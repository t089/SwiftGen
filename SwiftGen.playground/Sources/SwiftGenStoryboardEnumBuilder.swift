import Foundation
//@import SwiftIdentifier
//@import SwiftGenIndentation

public final class SwiftGenStoryboardEnumBuilder {
    private typealias Scene = (storyboardID: String, customClass: String?)
    private typealias Segue = (segueID: String, customClass: String?)
    private var storyboardsScenes = [String : [Scene]]()
    private var storyboardsSegues = [String: [Segue]]()

    
    public init() {}
    
    public func addStoryboardAtPath(path: String) {
        let parser = NSXMLParser(contentsOfURL: NSURL.fileURLWithPath(path))
        
        class ParserDelegate : NSObject, NSXMLParserDelegate {
            var scenes = [Scene]()
            var segues = [Segue]()
            var inScene = false
            var readyForFirstObject = false
            var readyForConnections = false
            
            @objc func parser(parser: NSXMLParser, didStartElement elementName: String,
              namespaceURI: String?, qualifiedName qName: String?,
              attributes attributeDict: [String : String])
            {
              
              switch elementName {
              case "scene":
                inScene = true
              case "objects" where inScene:
                readyForFirstObject = true
              case _ where readyForFirstObject:
                if let storyboardID = attributeDict["storyboardIdentifier"] {
                  let customClass = attributeDict["customClass"]
                  scenes.append(Scene(storyboardID, customClass))
                }
                readyForFirstObject = false
              case "connections":
                readyForConnections = true
              case "segue" where readyForConnections:
                if let segueID = attributeDict["identifier"] {
                  let customClass = attributeDict["customClass"]
                  segues.append(Segue(segueID, customClass))
                }
              default:
                break
              }
            }
      
            @objc func parser(parser: NSXMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?)
            {
                switch elementName {
                case "scene":
                    inScene = false
                case "objects" where inScene:
                    readyForFirstObject = false
                case "connections":
                    readyForConnections = false
                default:
                    break;
                }
            }
        }
        
        let delegate = ParserDelegate()
        parser?.delegate = delegate
        parser?.parse()
        
        let storyboardName = path.lastPathComponent.stringByDeletingPathExtension
        storyboardsScenes[storyboardName] = delegate.scenes
        storyboardsSegues[storyboardName] = delegate.segues
    }
    
    public func parseDirectory(path: String) {
        if let dirEnum = NSFileManager.defaultManager().enumeratorAtPath(path) {
            while let subPath = dirEnum.nextObject() as? String {
                if subPath.pathExtension == "storyboard" {
                    self.addStoryboardAtPath(path.stringByAppendingPathComponent(subPath))
                }
            }
        }
    }
    
    public func build(scenesEnumName scenesEnumName: String = "Scene", seguesEnumName: String = "Segue", indentation indent : SwiftGenIndentation = .Spaces(4)) -> String {
        var text = "// Generated using SwiftGen, by O.Halligon — https://github.com/AliSoftware/SwiftGen\n\n"
        let t = indent.string
        text += commonCode(indentationString: t)

        text += "extension UIStoryboard {\n"
      
        /// Scenes
        text += "\(t)enum \(scenesEnumName.asSwiftIdentifier()) {\n"
        for (name, scenes) in storyboardsScenes {
            let enumName = name.asSwiftIdentifier(forbiddenChars: "_")
            text += "\(t)\(t)enum \(enumName) : String, StoryboardScene {\n"
            text += "\(t)\(t)\(t)static let storyboardName = \"\(name)\"\n"
            
            for scene in scenes {
                let caseName = scene.storyboardID.asSwiftIdentifier(forbiddenChars: "_")
                let lcCaseName = lowercaseFirst(caseName)
                let vcClass = scene.customClass ?? "UIViewController"
                let cast = scene.customClass == nil ? "" : " as! \(vcClass)"
                text += "\n"
                text += "\(t)\(t)\(t)case \(caseName) = \"\(scene.storyboardID)\"\n"
                text += "\(t)\(t)\(t)static var \(lcCaseName)ViewController : \(vcClass) {\n"
                text += "\(t)\(t)\(t)\(t)return \(enumName).\(caseName).viewController()\(cast)\n"
                text += "\(t)\(t)\(t)}\n"
            }
            
            text += "\(t)\(t)}\n"
        }
        text += "\(t)}\n"
      
        /// Segues
        if (storyboardsSegues.count > 0) {
          text += "\n"
          
          text += "\(t)enum \(seguesEnumName.asSwiftIdentifier()) {\n"
        
          for (name, segues) in storyboardsSegues
            where segues.count > 0 {
              
            let enumName = name.asSwiftIdentifier(forbiddenChars: "_")
            text += "\(t)\(t)enum \(enumName) : String {\n"
            
            for segue in segues {
              let caseName = segue.segueID.asSwiftIdentifier(forbiddenChars: "_")
              text += "\(t)\(t)\(t)case \(caseName) = \"\(segue.segueID)\"\n"
            }
            
            text += "\(t)\(t)}\n"
          }
        
          text += "\(t)}\n"
        }
      
        text += "}\n\n"
      
        return text
    }
  
  
    // MARK: - Private Helpers
    
    private func commonCode(indentationString t : String) -> String {
        var text = ""
        
        text += "import Foundation\n"
        text += "import UIKit\n"
        text += "\n"
        
        text += "protocol StoryboardScene : RawRepresentable {\n"
        text += "\(t)static var storyboardName : String { get }\n"
        text += "\(t)static func storyboard() -> UIStoryboard\n"
        text += "\(t)static func initialViewController() -> UIViewController\n"
        text += "\(t)func viewController() -> UIViewController\n"
        text += "\(t)static func viewController(identifier: Self) -> UIViewController\n"
        
        text += "}\n"
        text += "\n"
        text += "extension StoryboardScene where Self.RawValue == String {\n"
        text += "\(t)static func storyboard() -> UIStoryboard {\n"
        text += "\(t)\(t)return UIStoryboard(name: self.storyboardName, bundle: nil)\n"
        text += "\(t)}\n"
        text += "\n"
        text += "\(t)static func initialViewController() -> UIViewController {\n"
        text += "\(t)\(t)return storyboard().instantiateInitialViewController()!\n"
        text += "\(t)}\n"
        text += "\n"
        text += "\(t)func viewController() -> UIViewController {\n"
        text += "\(t)\(t)return Self.storyboard().instantiateViewControllerWithIdentifier(self.rawValue)\n"
        text += "\(t)}\n"
        text += "\(t)static func viewController(identifier: Self) -> UIViewController {\n"
        text += "\(t)\(t)return identifier.viewController()\n"
        text += "\(t)}\n"
        text += "}\n\n"
        
        return text
    }
    
    private func lowercaseFirst(string: String) -> String {
        let ns = string as NSString
        let cs = NSCharacterSet.uppercaseLetterCharacterSet()
        
        var count = 0
        while cs.characterIsMember(ns.characterAtIndex(count)) {
            count++
        }
        
        let lettersToLower = count > 1 ? count-1 : count
        return ns.substringToIndex(lettersToLower).lowercaseString + ns.substringFromIndex(lettersToLower)
    }

}
