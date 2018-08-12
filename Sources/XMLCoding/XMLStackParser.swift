//
//  XMLStackParser.swift
//  CustomEncoder
//
//  Created by Shawn Moore on 11/14/17.
//  Copyright © 2017 Shawn Moore. All rights reserved.
//

import Foundation

//===----------------------------------------------------------------------===//
// Data Representation
//===----------------------------------------------------------------------===//

public struct XMLHeader {
    /// the XML standard that the produced document conforms to.
    var version: Double? = nil
    /// the encoding standard used to represent the characters in the produced document.
    var encoding: String? = nil
    /// indicates whetehr a document relies on information from an external source.
    var standalone: String? = nil
    
    init(version: Double? = nil) {
        self.version = version
    }
    
    init(version: Double?, encoding: String?, standalone: String? = nil) {
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
    var children: [String: [_XMLElement]] = [:]
    
    internal init(key: String, value: String? = nil, attributes: [String: String] = [:], children: [String: [_XMLElement]] = [:]) {
        self.key = key
        self.value = value
        self.attributes = attributes
        self.children = children
    }
    
    convenience init(key: String, value: Optional<CustomStringConvertible>, attributes: [String: CustomStringConvertible] = [:]) {
        self.init(key: key, value: value?.description, attributes: attributes.mapValues({ $0.description }), children: [:])
    }
    
    convenience init(key: String, children: [String: [_XMLElement]], attributes: [String: CustomStringConvertible] = [:]) {
        self.init(key: key, value: nil, attributes: attributes.mapValues({ $0.description }), children: children)
    }
    
    static func createRootElement(rootKey: String, header: XMLHeader?, options: XMLEncoder._Options, object: Container) throws -> Data {
        let element = _XMLElement(key: rootKey)
        
        switch object {
        case .dictionary(let dictionary):
            _XMLElement.modifyElement(element: element, parentElement: nil, key: nil, values: dictionary)
        case .array(let array):
            _XMLElement.createElement(parentElement: element, key: rootKey, object: array)
        default:
            throw EncodingError.invalidValue(object, EncodingError.Context(codingPath: [], debugDescription: "Top-level encoded as non-root XML fragment."))
        }
        
        return element.toXMLString(with: header, withCDATA: options.stringEncodingStrategy != .deferredToString).data(using: .utf8, allowLossyConversion: true)!
    }
    
    fileprivate static func createElement(parentElement: _XMLElement?, key: String, object: [String: Container]) {
        let element = _XMLElement(key: key)
        
        modifyElement(element: element, parentElement: parentElement, key: key, values: object)
    }
    
    private static func modifyContainerElement(container: Container, element: _XMLElement, key: String) {
        switch container {
        case .dictionary(let values):
            _XMLElement.createElement(parentElement: element, key: key, object: values)
        case .array(let values):
            _XMLElement.createElement(parentElement: element, key: key, object: values)
        case .boolean(let value):
            _XMLElement.createElement(parentElement: element, key: key, value: value)
        case .string(let value):
            _XMLElement.createElement(parentElement: element, key: key, value: value)
        case .int64(let value):
            _XMLElement.createElement(parentElement: element, key: key, value: value)
        case .uint64(let value):
            _XMLElement.createElement(parentElement: element, key: key, value: value)
        case .double(let value):
            _XMLElement.createElement(parentElement: element, key: key, value: value)
        case .null:
            _XMLElement.createNullElement(parentElement: element, key: key)
        }
    }
    
    private static func modifyElement(element: _XMLElement, parentElement: _XMLElement?, key: String?, values: [String: Container]) {
        if let attributesContainer = values[_XMLElement.attributesKey], case let .dictionary(attributes) = attributesContainer {
            element.attributes = attributes.mapValues({ String(describing: $0) })
        }
        
        let filteredValues: [(String, Container)] = values.compactMap({
            guard $0 != _XMLElement.attributesKey else { return nil }
            
            return ($0, $1)
        })
        
        for (key, value) in filteredValues {
            modifyContainerElement(container: value, element: element, key: key)
        }
        
        if let parentElement = parentElement, let key = key {
            parentElement.children[key] = (parentElement.children[key] ?? []) + [element]
        }
    }
    
    fileprivate static func createElement(parentElement: _XMLElement, key: String, object: [Container]) {
        object.forEach({
            modifyContainerElement(container: $0, element: parentElement, key: key)
        })
    }

    fileprivate static func createElement(parentElement: _XMLElement, key: String, value: CustomStringConvertible) {
        let element = _XMLElement(key: key, value: value.description)
        parentElement.children[key] = (parentElement.children[key] ?? []) + [element]
    }
    
    fileprivate static func createNullElement(parentElement: _XMLElement, key: String) {
        let element = _XMLElement(key: key)
        parentElement.children[key] = (parentElement.children[key] ?? []) + [element]
    }
    
    func flatten() -> [String: Any] {
        var node: [String: Any] = attributes
        
        for childElement in children {
            for child in childElement.value {
                if let content = child.value {
                    if let oldContent = node[childElement.key] as? Array<Any> {
                        node[childElement.key] = oldContent + [content]
                    } else if let oldContent = node[childElement.key] {
                        node[childElement.key] = [oldContent, content]
                    } else {
                        node[childElement.key] = content
                    }
                } else if !child.children.isEmpty || !child.attributes.isEmpty {
                    let newValue = child.flatten()
                    
                    if let existingValue = node[childElement.key] {
                        if var array = existingValue as? Array<Any> {
                            array.append(newValue)
                            node[childElement.key] = array
                        } else {
                            node[childElement.key] = [existingValue, newValue]
                        }
                    } else {
                        node[childElement.key] = newValue
                    }
                // if the node is empty and there is no existing value
                } else if node[childElement.key] == nil {
                    // an empty node can be treated as an empty dictionary
                    node[childElement.key] = [:]
                }
            }
        }
        
        return node
    }
    
    func toXMLString(with header: XMLHeader? = nil, withCDATA cdata: Bool, ignoreEscaping: Bool = false) -> String {
        if let header = header, let headerXML = header.toXML() {
            return headerXML + _toXMLString(withCDATA: cdata)
        } else {
            return _toXMLString(withCDATA: cdata)
        }
    }
    
    fileprivate func _toXMLString(indented level: Int = 0, withCDATA cdata: Bool, ignoreEscaping: Bool = false) -> String {
        var string = String(repeating: " ", count: level * 4)
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
        } else if !children.isEmpty {
            string += ">\n"
            
            for childElement in children {
                for child in childElement.value {
                    string += child._toXMLString(indented: level + 1, withCDATA: cdata)
                    string += "\n"
                }
            }
            
            string += String(repeating: " ", count: level * 4)
            string += "</\(key)>"
        } else {
            string += " />"
        }
        
        return string
    }
}

extension String {
    func escape(_ characterSet: [(character: String, escapedCharacter: String)]) -> String {
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
        
        if xmlParser.parse() {
            return root
        } else if let error = xmlParser.parserError {
            throw error
        } else {
            return nil
        }
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
            if currentNode.children[elementName] != nil {
                currentNode.children[elementName]?.append(node)
            } else {
                currentNode.children[elementName] = [node]
            }
        }
        currentNode = node
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if let poppedNode = stack.popLast(){
            if let content = poppedNode.value?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
                if content.isEmpty {
                    poppedNode.value = nil
                } else {
                    poppedNode.value = content
                }
            }
            
            if (stack.isEmpty) {
                root = poppedNode
                currentNode = nil
            } else {
                currentNode = stack.last
            }
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

