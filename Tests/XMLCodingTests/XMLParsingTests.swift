import XCTest
@testable import XMLCoding

let LIST_XML = """
    <Response>
        <Result />
        <MetadataList>
            <item>
                <Id>id1</Id>
            </item>
            <item>
                <Id>id2</Id>
            </item>
            <item>
                <Id>id3</Id>
            </item>
        </MetadataList>
    </Response>
    """

let SINGLETON_LIST_XML = """
    <Response>
        <Result />
        <MetadataList>
            <item>
                <Id>id1</Id>
            </item>
        </MetadataList>
    </Response>
    """

class XMLParsingTests: XCTestCase {
    struct Result: Codable, Equatable {
        let message: String?
        
        enum CodingKeys: String, CodingKey {
            case message = "Message"
        }
    }
    
    struct Metadata: Codable, Equatable {
        let id: String
        
        enum CodingKeys: String, CodingKey {
            case id = "Id"
        }
    }
    
    struct MetadataList: Codable, Equatable {
        let items: [Metadata]
        
        enum CodingKeys: String, CodingKey {
            case items = "item"
        }
    }
    
    struct Response: Codable {
        let result: Result
        let metadata: Metadata
        
        enum CodingKeys: String, CodingKey {
            case result = "Result"
            case metadata = "Metadata"
        }
    }
    
    struct ResponseWithList: Codable, Equatable {
        let result: Result
        let metadataList: MetadataList
        
        enum CodingKeys: String, CodingKey {
            case result = "Result"
            case metadataList = "MetadataList"
        }
    }
    
    struct ResponseWithCollapsedList: Codable, Equatable {
        let result: Result
        let metadataList: [Metadata]
        
        enum CodingKeys: String, CodingKey {
            case result = "Result"
            case metadataList = "MetadataList"
        }
    }
    
    func testEmptyElement() throws {
        let inputString = """
            <Response>
                <Result/>
                <Metadata>
                    <Id>id</Id>
                </Metadata>
            </Response>
            """
        
        guard let inputData = inputString.data(using: .utf8) else {
            return XCTFail()
        }
        
        let response = try XMLDecoder().decode(Response.self, from: inputData)
        
        XCTAssertNil(response.result.message)
    }

    func testEmptyElementNotEffectingPreviousElement() throws {
        let inputString = """
            <Response>
                <Result>
                    <Message>message</Message>
                </Result>
                <Result/>
                <Metadata>
                    <Id>id</Id>
                </Metadata>
            </Response>
            """
        
        guard let inputData = inputString.data(using: .utf8) else {
            return XCTFail()
        }
        
        let response = try XMLDecoder().decode(Response.self, from: inputData)
        
        XCTAssertEqual("message", response.result.message)
    }
    
    func testListDecodingWithDefaultStrategy() throws {
        guard let inputData = LIST_XML.data(using: .utf8) else {
            return XCTFail()
        }
        
        let response = try XMLDecoder().decode(ResponseWithList.self, from: inputData)
        
        XCTAssertEqual(3, response.metadataList.items.count)
        
        // encode the output to make sure we get what we started with
        let data = try XMLEncoder().encode(response, withRootKey: "Response")
        
        let response2 = try XMLDecoder().decode(ResponseWithList.self, from: data)
        XCTAssertEqual(response, response2)
    }
    
    func testSingletonListDecodingWithDefaultStrategy() throws {
        guard let inputData = SINGLETON_LIST_XML.data(using: .utf8) else {
            return XCTFail()
        }
        
        let response = try XMLDecoder().decode(ResponseWithList.self, from: inputData)
        
        XCTAssertEqual(1, response.metadataList.items.count)
        
        // encode the output to make sure we get what we started with
        let data = try XMLEncoder().encode(response, withRootKey: "Response")
        
        let response2 = try XMLDecoder().decode(ResponseWithList.self, from: data)
        XCTAssertEqual(response, response2)
    }
    
    func testListDecodingWithCollapseItemTagStrategy() throws {
        guard let inputData = LIST_XML.data(using: .utf8) else {
            return XCTFail()
        }
        
        let decoder = XMLDecoder()
        decoder.listDecodingStrategy = .collapseListUsingItemTag("item")
        let response = try decoder.decode(ResponseWithCollapsedList.self, from: inputData)
        
        XCTAssertEqual(3, response.metadataList.count)
        
        let encoder = XMLEncoder()
        encoder.listEncodingStrategy = .expandListWithItemTag("item")
        
        // encode the output to make sure we get what we started with
        let data = try encoder.encode(response, withRootKey: "Response")
        
        let response2 = try decoder.decode(ResponseWithCollapsedList.self, from: data)
        XCTAssertEqual(response, response2)
    }
    
    func testSingletonListDecodingWithCollapseItemTagStrategy() throws {
        guard let inputData = SINGLETON_LIST_XML.data(using: .utf8) else {
            return XCTFail()
        }
        
        let decoder = XMLDecoder()
        decoder.listDecodingStrategy = .collapseListUsingItemTag("item")
        let response = try decoder.decode(ResponseWithCollapsedList.self, from: inputData)
        
        XCTAssertEqual(1, response.metadataList.count)
        
        let encoder = XMLEncoder()
        encoder.listEncodingStrategy = .expandListWithItemTag("item")
        
        // encode the output to make sure we get what we started with
        let data = try encoder.encode(response, withRootKey: "Response")
        
        let response2 = try decoder.decode(ResponseWithCollapsedList.self, from: data)
        XCTAssertEqual(response, response2)
    }

    static var allTests = [
        ("testEmptyElement", testEmptyElement),
        ("testEmptyElementNotEffectingPreviousElement", testEmptyElementNotEffectingPreviousElement),
        ("testListDecodingWithDefaultStrategy", testListDecodingWithDefaultStrategy),
        ("testSingletonListDecodingWithDefaultStrategy", testSingletonListDecodingWithDefaultStrategy),
        ("testListDecodingWithCollapseItemTagStrategy", testListDecodingWithCollapseItemTagStrategy)
    ]
}
