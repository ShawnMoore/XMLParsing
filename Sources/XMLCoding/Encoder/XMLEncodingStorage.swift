
//
//  XMLEncodingStorage.swift
//  XMLParsing
//
//  Created by Shawn Moore on 11/22/17.
//  Copyright © 2017 Shawn Moore. All rights reserved.
//

import Foundation

// MARK: - Mutable Containers

internal class MutableContainerDictionary {
    private var values: [String: MutableContainer] = [:]
    
    subscript(key: String) -> MutableContainer? {
        get {
            return values[key]
        }
        set(newValue) {
            values[key] = newValue
        }
    }
    
    internal func asContainer() -> Container {
        let transformedValues: [String: Container] = values.mapValues { value in
            return value.asContainer()
        }
        
        return .dictionary(transformedValues)
    }
}

internal class MutableContainerArray {
    private var values: [MutableContainer] = []
    
    subscript(index: Int) -> MutableContainer {
        get {
            return values[index]
        }
    }
    
    var count: Int {
        return values.count
    }
    
    func append(_ newElement: MutableContainer) {
        values.append(newElement)
    }
    
    func insert(_ newElement: MutableContainer, at index: Int) {
        values.insert(newElement, at: index)
    }
    
    internal func asContainer() -> Container {
        let transformedValues: [Container] = values.map { value in
            return value.asContainer()
        }
        
        return .array(transformedValues)
    }
}

internal enum MutableContainer {
    case dictionary(MutableContainerDictionary)
    case array(MutableContainerArray)
    case boolean(Bool)
    case string(String)
    case int64(Int64)
    case uint64(UInt64)
    case double(Double)
    case null
    
    internal func asContainer() -> Container {
        switch self {
        case .dictionary(let innerDictionary):
            return innerDictionary.asContainer()
        case .array(let innerArray):
            return innerArray.asContainer()
        case .boolean(let value):
            return .boolean(value)
        case .string(let value):
            return .string(value)
        case .int64(let value):
            return .int64(value)
        case .uint64(let value):
            return .uint64(value)
        case .double(let value):
            return .double(value)
        case .null:
            return .null
        }
    }
}

// MARK: - Container

internal enum Container {
    case dictionary([String: Container])
    case array([Container])
    case boolean(Bool)
    case string(String)
    case int64(Int64)
    case uint64(UInt64)
    case double(Double)
    case null
}

// MARK: - Encoding Storage and Containers

internal struct _XMLEncodingStorage {
    // MARK: Properties
    
    /// The container stack.
    private(set) internal var containers: [MutableContainer] = []
    
    // MARK: - Initialization
    
    /// Initializes `self` with no containers.
    internal init() {}
    
    // MARK: - Modifying the Stack
    
    internal var count: Int {
        return self.containers.count
    }
    
    internal mutating func pushKeyedContainer() -> MutableContainerDictionary {
        let dictionary = MutableContainerDictionary()
        self.containers.append(.dictionary(dictionary))
        return dictionary
    }
    
    internal mutating func pushUnkeyedContainer() -> MutableContainerArray {
        let array = MutableContainerArray()
        self.containers.append(.array(array))
        return array
    }
    
    internal mutating func push(container: MutableContainer) {
        self.containers.append(container)
    }
    
    internal mutating func pushNull() {
        self.containers.append(.null)
    }
    
    internal mutating func popContainer() -> MutableContainer {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.popLast()!
    }
}
