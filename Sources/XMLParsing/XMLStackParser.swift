//
//  XMLStackParser.swift
//  CustomEncoder
//
//  Created by Shawn Moore on 11/14/17.
//  Copyright © 2017 Shawn Moore. All rights reserved.
//

import Foundation
import XMLParsingPrivate

//===----------------------------------------------------------------------===//
// Data Representation
//===----------------------------------------------------------------------===//

public struct XMLHeader {
    /// the XML standard that the produced document conforms to.
    public let version: Double?
    /// the encoding standard used to represent the characters in the produced document.
    public let encoding: String?
    /// indicates whether a document relies on information from an external source.
    public let standalone: String?

    public init(version: Double? = nil, encoding: String? = nil, standalone: String? = nil) {
        self.version = version
        self.encoding = encoding
        self.standalone = standalone
    }
    
    internal func isEmpty() -> Bool {
        return version == nil && encoding == nil && standalone == nil
    }
    
    internal func toXML() -> String? {
        guard !self.isEmpty() else { return nil }
        
        var string = "<?xml "
        
        if let version = version {
            string += "version=\"\(version)\" "
        }
        
        if let encoding = encoding {
            string += "encoding=\"\(encoding)\" "
        }
        
        if let standalone = standalone {
            string += "standalone=\"\(standalone)\""
        }
        
        return string.trimmingCharacters(in: .whitespaces) + "?>\n"
    }
}

internal class _XMLElement {
    static let attributesKey = "___ATTRIBUTES"
    static let escapedCharacterSet = [("&", "&amp"), ("<", "&lt;"), (">", "&gt;"), ( "'", "&apos;"), ("\"", "&quot;")]
    
    var key: String
    var value: String? = nil
    var attributes: [String: String] = [:]
    var children = CHOrderedDictionary()
    
    internal init(key: String, value: String? = nil, attributes: [String: String] = [:], children: [String: [_XMLElement]] = [:]) {
        self.key = key
        self.value = value
        self.attributes = attributes
        self.children = CHOrderedDictionary(dictionary: children)
    }
    
    convenience init(key: String, value: Optional<CustomStringConvertible>, attributes: [String: CustomStringConvertible] = [:]) {
        self.init(key: key, value: value?.description, attributes: attributes.mapValues({ $0.description }), children: [:])
    }
    
    convenience init(key: String, children: [String: [_XMLElement]], attributes: [String: CustomStringConvertible] = [:]) {
        self.init(key: key, value: nil, attributes: attributes.mapValues({ $0.description }), children: children)
    }
    
    static func createRootElement(rootKey: String, object: NSObject) -> _XMLElement? {
        let element = _XMLElement(key: rootKey)
        
        if let object = object as? NSDictionary {
            _XMLElement.modifyElement(element: element, parentElement: nil, key: nil, object: object)
        } else if let object = object as? NSArray {
            _XMLElement.createElement(parentElement: element, key: rootKey, object: object)
        }
        
        return element
    }
    
    fileprivate static func createElement(parentElement: _XMLElement?, key: String, object: NSDictionary) {
        let element = _XMLElement(key: key)
        
        modifyElement(element: element, parentElement: parentElement, key: key, object: object)
    }
    
    fileprivate static func modifyElement(element: _XMLElement, parentElement: _XMLElement?, key: String?, object: NSDictionary) {
        element.attributes = (object[_XMLElement.attributesKey] as? [String: Any])?.mapValues({ String(describing: $0) }) ?? [:]
        
        let objects: [(String, NSObject)] = object.compactMap({
            guard let key = $0 as? String, let value = $1 as? NSObject, key != _XMLElement.attributesKey else { return nil }
            
            return (key, value)
        })
        
        for (key, value) in objects {
            if let dict = value as? NSDictionary {
                _XMLElement.createElement(parentElement: element, key: key, object: dict)
            } else if let array = value as? NSArray {
                _XMLElement.createElement(parentElement: element, key: key, object: array)
            } else if let string = value as? NSString {
                _XMLElement.createElement(parentElement: element, key: key, object: string)
            } else if let number = value as? NSNumber {
                _XMLElement.createElement(parentElement: element, key: key, object: number)
            } else {
                _XMLElement.createElement(parentElement: element, key: key, object: NSNull())
            }
        }
        
        if let parentElement = parentElement, let key = key {
            parentElement.children[key] = (parentElement.children[key] as! [_XMLElement]? ?? []) + [element]
        }
    }
    
    fileprivate static func createElement(parentElement: _XMLElement, key: String, object: NSArray) {
        let objects = object.compactMap({ $0 as? NSObject })
        objects.forEach({
            if let dict = $0 as? NSDictionary {
                _XMLElement.createElement(parentElement: parentElement, key: key, object: dict)
            } else if let array = $0 as? NSArray {
                _XMLElement.createElement(parentElement: parentElement, key: key, object: array)
            } else if let string = $0 as? NSString {
                _XMLElement.createElement(parentElement: parentElement, key: key, object: string)
            } else if let number = $0 as? NSNumber {
                _XMLElement.createElement(parentElement: parentElement, key: key, object: number)
            } else {
                _XMLElement.createElement(parentElement: parentElement, key: key, object: NSNull())
            }
        })
    }
    
    fileprivate static func createElement(parentElement: _XMLElement, key: String, object: NSNumber) {
        let element = _XMLElement(key: key, value: object.description)
        parentElement.children[key] = (parentElement.children[key] as! [_XMLElement]? ?? []) + [element]
    }
    
    fileprivate static func createElement(parentElement: _XMLElement, key: String, object: NSString) {
        let element = _XMLElement(key: key, value: object.description)
        parentElement.children[key] = (parentElement.children[key] as! [_XMLElement]? ?? []) + [element]
    }
    
    fileprivate static func createElement(parentElement: _XMLElement, key: String, object: NSNull) {
        let element = _XMLElement(key: key)
        parentElement.children[key] = (parentElement.children[key] as! [_XMLElement]? ?? []) + [element]
    }
    
    fileprivate func flatten() -> [String: Any] {
        var node: [String: Any] = attributes
        
        for childElement in children {
            let value = childElement.value as! [_XMLElement]
            let key = childElement.key as! String
            for child in value {
                if child.children.count() > 0 || !child.attributes.isEmpty {
                    let newValue = child.flatten()
                    
                    if let existingValue = node[key] {
                        if var array = existingValue as? Array<Any> {
                            array.append(newValue)
                            node[key] = array
                        } else {
                            node[key] = [existingValue, newValue]
                        }
                    } else {
                        node[key] = newValue
                    }
                } else if let content = child.value {
                    if let oldContent = node[key] as? Array<Any> {
                        node[key] = oldContent + [content]
                        
                    } else if let oldContent = node[key] {
                        node[key] = [oldContent, content]
                        
                    } else {
                        node[key] = content
                    }
                }
            }
        }
        
        return node
    }

    func toXMLString(with header: XMLHeader? = nil, withCDATA cdata: Bool, formatting: XMLEncoder.OutputFormatting, ignoreEscaping: Bool = false) -> String {
        if let header = header, let headerXML = header.toXML() {
            return headerXML + _toXMLString(withCDATA: cdata, formatting: formatting)
        } else {
            return _toXMLString(withCDATA: cdata, formatting: formatting)
        }
    }
    
    fileprivate func _toXMLString(indented level: Int = 0, withCDATA cdata: Bool, formatting: XMLEncoder.OutputFormatting, ignoreEscaping: Bool = false) -> String {
        let prettyPrinted = formatting.contains(.prettyPrinted)
        let indentation = String(repeating: " ", count: (prettyPrinted ? level : 0) * 4)
        var string = indentation
        string += "<\(key)"
        
        for (key, value) in attributes {
            string += " \(key)=\"\(value.escape(_XMLElement.escapedCharacterSet))\""
        }
        
        if let value = value {
            string += ">"
            if !ignoreEscaping {
                string += (cdata == true ? "<![CDATA[\(value)]]>" : "\(value.escape(_XMLElement.escapedCharacterSet))" )
            } else {
                string += "\(value)"
            }
            string += "</\(key)>"
        } else if children.count() > 0 {
            string += prettyPrinted ? ">\n" : ">"
            
            for childElement in children {
                for child in childElement.value as! [_XMLElement] {
                    string += child._toXMLString(indented: level + 1, withCDATA: cdata, formatting: formatting)
                    string += prettyPrinted ? "\n" : ""
                }
            }
            
            string += indentation
            string += "</\(key)>"
        } else {
            string += " />"
        }
        
        return string
    }
}

enum XmlNamespace: String {
    case xsi = "http://www.w3.org/2001/XMLSchema-instance"
}

extension String {
    internal func escape(_ characterSet: [(character: String, escapedCharacter: String)]) -> String {
        var string = self
        
        for set in characterSet {
            string = string.replacingOccurrences(of: set.character, with: set.escapedCharacter, options: .literal)
        }
        
        return string
    }
}



internal class _XMLStackParser: NSObject, XMLParserDelegate {
    var root: _XMLElement?
    var stack = [_XMLElement]()
    var currentNode: _XMLElement?
    
    var currentElementName: String?
    var currentElementData = ""
    
    var nsPrefix = [String: String]()
    var prefixNs = [String: String]()
    

    
    static func parse(with data: Data) throws -> [String: Any] {
        let parser = _XMLStackParser()
        
        do {
            if let node = try parser.parse(with: data) {
                return node.flatten()
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given data could not be parsed into XML."))
            }
        } catch {
            throw error
        }
    }
    
    func parse(with data: Data) throws -> _XMLElement?  {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.shouldProcessNamespaces = true
        xmlParser.shouldReportNamespacePrefixes = true
        
        if xmlParser.parse() {
            return root
        } else if let error = xmlParser.parserError {
            throw error
        } else {
            return nil
        }
    }
    
    private func popValueOf(attr: String, ns: XmlNamespace, from dict: inout [String: String]) -> String? {
        guard let prefix = nsPrefix[ns.rawValue] else { return nil }
        return dict.removeValue(forKey: "\(prefix):\(attr)")
    }
    
    func parserDidStartDocument(_ parser: XMLParser) {
        root = nil
        stack = [_XMLElement]()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let node = _XMLElement(key: elementName)
        node.attributes = attributeDict
        stack.append(node)
        
        if let currentNode = currentNode {
            if var childArray = currentNode.children[elementName] as? [_XMLElement] {
                childArray.append(node)
                currentNode.children[elementName] = childArray
            } else {
                currentNode.children[elementName] = [node]
            }
        }
        currentNode = node
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if let poppedNode = stack.popLast(){
            if let nilAttr = popValueOf(attr: "nil", ns: .xsi, from: &poppedNode.attributes), nilAttr == "true" {
                poppedNode.value = nil
            } else if let content = poppedNode.value?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
                poppedNode.value = content
            } else {
                // an element which is present must be at least empty
                poppedNode.value = ""
            }
            
            if (stack.isEmpty) {
                root = poppedNode
                currentNode = nil
            } else {
                currentNode = stack.last
            }
        }
    }
    
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
        prefixNs[prefix] = namespaceURI
        nsPrefix[namespaceURI] = prefix
    }
    
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) {
        if let uri = prefixNs.removeValue(forKey: prefix) {
            nsPrefix.removeValue(forKey: uri)
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentNode?.value = (currentNode?.value ?? "") + string
    }
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            currentNode?.value = (currentNode?.value ?? "") + string
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print(parseError)
    }
}

